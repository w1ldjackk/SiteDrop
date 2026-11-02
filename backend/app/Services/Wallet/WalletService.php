<?php

namespace App\Services\Wallet;

use App\Enums\WalletTransactionCategory;
use App\Enums\WalletTransactionStatus;
use App\Enums\WalletTransactionType;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Services\Notification\NotificationService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class WalletService
{
    public function __construct(
        protected NotificationService $notifications
    ) {}

    public function getOrCreateWallet(User|int $user): Wallet
    {
        return Wallet::forUser($user);
    }

    /**
     * @return array{wallet: Wallet, transactions: \Illuminate\Contracts\Pagination\LengthAwarePaginator}
     */
    public function summary(User $user, int $perPage = 20): array
    {
        $wallet = $this->getOrCreateWallet($user);
        $transactions = WalletTransaction::query()
            ->where('wallet_id', $wallet->id)
            ->with('reviewer:id,name')
            ->latest()
            ->paginate($perPage);

        return compact('wallet', 'transactions');
    }

    /**
     * Immediate credit (admin adjustment, refund, earning, etc.).
     */
    public function credit(
        User $user,
        float $amount,
        string $description,
        WalletTransactionCategory|string $category = WalletTransactionCategory::Adjustment,
        ?string $reference = null,
        ?array $metadata = null,
        ?User $actor = null,
        bool $notify = true
    ): WalletTransaction {
        $this->assertPositive($amount);

        return DB::transaction(function () use ($user, $amount, $description, $category, $reference, $metadata, $actor, $notify) {
            $wallet = Wallet::forUser($user);
            $this->assertActive($wallet);
            $wallet = Wallet::query()->whereKey($wallet->id)->lockForUpdate()->firstOrFail();

            $before = (float) $wallet->balance;
            $wallet->balance = $before + $amount;
            $wallet->total_earned = (float) $wallet->total_earned + $amount;
            $wallet->last_transaction_at = now();
            $wallet->save();

            $tx = $this->createTx(
                wallet: $wallet,
                type: WalletTransactionType::Credit,
                category: $category,
                amount: $amount,
                balanceBefore: $before,
                balanceAfter: (float) $wallet->balance,
                description: $description,
                reference: $reference,
                metadata: $metadata,
                status: WalletTransactionStatus::Completed,
                reviewer: $actor,
            );

            if ($notify) {
                $this->notifyUser($user, 'wallet_credited', [
                    'amount' => number_format($amount, 2),
                    'currency' => $wallet->currency,
                    'balance' => number_format((float) $wallet->balance, 2),
                    'description' => $description,
                    'reference' => $tx->reference,
                ]);
            }

            return $tx;
        });
    }

    /**
     * Immediate debit (payment, admin deduction).
     */
    public function debit(
        User $user,
        float $amount,
        string $description,
        WalletTransactionCategory|string $category = WalletTransactionCategory::Payment,
        ?string $reference = null,
        ?array $metadata = null,
        ?User $actor = null,
        bool $notify = true
    ): WalletTransaction {
        $this->assertPositive($amount);

        return DB::transaction(function () use ($user, $amount, $description, $category, $reference, $metadata, $actor, $notify) {
            $wallet = Wallet::forUser($user);
            $this->assertActive($wallet);
            $wallet = Wallet::query()->whereKey($wallet->id)->lockForUpdate()->firstOrFail();

            if ($wallet->available_balance < $amount) {
                throw ValidationException::withMessages([
                    'amount' => 'Insufficient wallet balance. Available: GHS '.number_format($wallet->available_balance, 2),
                ]);
            }

            $before = (float) $wallet->balance;
            $wallet->balance = $before - $amount;
            $wallet->total_spent = (float) $wallet->total_spent + $amount;
            $wallet->last_transaction_at = now();
            $wallet->save();

            $tx = $this->createTx(
                wallet: $wallet,
                type: WalletTransactionType::Debit,
                category: $category,
                amount: $amount,
                balanceBefore: $before,
                balanceAfter: (float) $wallet->balance,
                description: $description,
                reference: $reference,
                metadata: $metadata,
                status: WalletTransactionStatus::Completed,
                reviewer: $actor,
            );

            if ($notify) {
                $this->notifyUser($user, 'wallet_debited', [
                    'amount' => number_format($amount, 2),
                    'currency' => $wallet->currency,
                    'balance' => number_format((float) $wallet->balance, 2),
                    'description' => $description,
                    'reference' => $tx->reference,
                ]);
            }

            return $tx;
        });
    }

    /**
     * User deposit request (pending admin approval).
     */
    public function requestDeposit(User $user, float $amount, ?string $note = null, ?array $metadata = null): WalletTransaction
    {
        $this->assertPositive($amount);
        $wallet = $this->getOrCreateWallet($user);
        $this->assertActive($wallet);

        $tx = $this->createTx(
            wallet: $wallet,
            type: WalletTransactionType::Credit,
            category: WalletTransactionCategory::Deposit,
            amount: $amount,
            balanceBefore: (float) $wallet->balance,
            balanceAfter: (float) $wallet->balance,
            description: $note ?: 'Deposit request',
            reference: $this->makeReference('DEP'),
            metadata: array_merge($metadata ?? [], ['requested_by' => $user->id]),
            status: WalletTransactionStatus::Pending,
        );

        $this->notifyUser($user, 'wallet_deposit_requested', [
            'amount' => number_format($amount, 2),
            'currency' => $wallet->currency,
            'reference' => $tx->reference,
        ]);
        $this->notifyAdmins('wallet_admin_pending', [
            'user_name' => $user->name,
            'amount' => number_format($amount, 2),
            'type' => 'deposit',
            'reference' => $tx->reference,
        ]);

        return $tx;
    }

    /**
     * User withdrawal request (holds funds as blocked + pending).
     */
    public function requestWithdrawal(User $user, float $amount, ?string $note = null, ?array $metadata = null): WalletTransaction
    {
        $this->assertPositive($amount);

        return DB::transaction(function () use ($user, $amount, $note, $metadata) {
            $wallet = Wallet::forUser($user);
            $this->assertActive($wallet);
            $wallet = Wallet::query()->whereKey($wallet->id)->lockForUpdate()->firstOrFail();

            if ($wallet->available_balance < $amount) {
                throw ValidationException::withMessages([
                    'amount' => 'Insufficient available balance for withdrawal.',
                ]);
            }

            $before = (float) $wallet->balance;
            $wallet->blocked_balance = (float) $wallet->blocked_balance + $amount;
            $wallet->last_transaction_at = now();
            $wallet->save();

            $tx = $this->createTx(
                wallet: $wallet,
                type: WalletTransactionType::Debit,
                category: WalletTransactionCategory::Withdrawal,
                amount: $amount,
                balanceBefore: $before,
                balanceAfter: $before,
                description: $note ?: 'Withdrawal request',
                reference: $this->makeReference('WDR'),
                metadata: array_merge($metadata ?? [], [
                    'requested_by' => $user->id,
                    'held' => true,
                ]),
                status: WalletTransactionStatus::Pending,
            );

            $this->notifyUser($user, 'wallet_withdrawal_requested', [
                'amount' => number_format($amount, 2),
                'currency' => $wallet->currency,
                'reference' => $tx->reference,
            ]);
            $this->notifyAdmins('wallet_admin_pending', [
                'user_name' => $user->name,
                'amount' => number_format($amount, 2),
                'type' => 'withdrawal',
                'reference' => $tx->reference,
            ]);

            return $tx;
        });
    }

    /**
     * Internal transfer between SiteDrop users (instant, no approval).
     * Atomic: sender debit + recipient credit share one reference.
     *
     * @return array{debit: WalletTransaction, credit: WalletTransaction}
     */
    public function transfer(User $sender, User $recipient, float $amount, ?string $note = null): array
    {
        $this->assertPositive($amount);
        if ($sender->id === $recipient->id) {
            throw ValidationException::withMessages([
                'recipient' => 'You cannot transfer to yourself.',
            ]);
        }

        $reference = $this->makeReference('XFER');

        $debit = $this->debit(
            $sender,
            $amount,
            "Transfer to {$recipient->name}" . ($note ? " — {$note}" : ''),
            WalletTransactionCategory::Transfer,
            $reference,
            ['recipient_id' => $recipient->id, 'note' => $note],
            notify: false,
        );
        $credit = $this->credit(
            $recipient,
            $amount,
            "Transfer from {$sender->name}" . ($note ? " — {$note}" : ''),
            WalletTransactionCategory::Transfer,
            $reference,
            ['sender_id' => $sender->id, 'note' => $note],
            notify: false,
        );

        $this->notifyUser($sender, 'wallet_transfer_sent', [
            'amount' => number_format($amount, 2),
            'recipient' => $recipient->name,
            'reference' => $reference,
        ]);
        $this->notifyUser($recipient, 'wallet_transfer_received', [
            'amount' => number_format($amount, 2),
            'sender' => $sender->name,
            'reference' => $reference,
        ]);

        return ['debit' => $debit, 'credit' => $credit];
    }

    public function approve(WalletTransaction $tx, User $admin, ?string $adminNotes = null): WalletTransaction
    {        if (! $tx->is_pending) {
            throw ValidationException::withMessages([
                'transaction' => 'Only pending transactions can be approved.',
            ]);
        }

        return DB::transaction(function () use ($tx, $admin, $adminNotes) {
            $tx = WalletTransaction::query()->whereKey($tx->id)->lockForUpdate()->firstOrFail();
            $wallet = Wallet::query()->whereKey($tx->wallet_id)->lockForUpdate()->firstOrFail();
            $user = User::query()->findOrFail($tx->user_id);

            $category = $tx->category instanceof WalletTransactionCategory
                ? $tx->category
                : WalletTransactionCategory::tryFrom((string) $tx->category) ?? WalletTransactionCategory::Adjustment;

            $amount = (float) $tx->amount;
            $before = (float) $wallet->balance;

            if ($category === WalletTransactionCategory::Deposit) {
                $wallet->balance = $before + $amount;
                $wallet->total_earned = (float) $wallet->total_earned + $amount;
            } elseif ($category === WalletTransactionCategory::Withdrawal) {
                // Funds were blocked at request time — release hold and debit.
                $wallet->blocked_balance = max(0, (float) $wallet->blocked_balance - $amount);
                $wallet->balance = $before - $amount;
                $wallet->total_spent = (float) $wallet->total_spent + $amount;
            } else {
                // Generic pending credit/debit
                $type = $tx->type instanceof WalletTransactionType ? $tx->type : WalletTransactionType::Credit;
                if ($type === WalletTransactionType::Credit) {
                    $wallet->balance = $before + $amount;
                    $wallet->total_earned = (float) $wallet->total_earned + $amount;
                } else {
                    if ($wallet->available_balance < $amount) {
                        throw ValidationException::withMessages([
                            'amount' => 'Insufficient balance to complete this transaction.',
                        ]);
                    }
                    $wallet->balance = $before - $amount;
                    $wallet->total_spent = (float) $wallet->total_spent + $amount;
                }
            }

            $wallet->last_transaction_at = now();
            $wallet->save();

            $tx->update([
                'status' => WalletTransactionStatus::Completed,
                'balance_before' => $before,
                'balance_after' => (float) $wallet->balance,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
                'admin_notes' => $adminNotes,
            ]);

            $this->notifyUser($user, 'wallet_transaction_approved', [
                'amount' => number_format($amount, 2),
                'currency' => $wallet->currency,
                'reference' => $tx->reference,
                'type' => $category->value,
                'balance' => number_format((float) $wallet->balance, 2),
            ]);

            return $tx->fresh(['user', 'reviewer', 'wallet']);
        });
    }

    public function reject(WalletTransaction $tx, User $admin, ?string $adminNotes = null): WalletTransaction
    {
        if (! $tx->is_pending) {
            throw ValidationException::withMessages([
                'transaction' => 'Only pending transactions can be rejected.',
            ]);
        }

        return DB::transaction(function () use ($tx, $admin, $adminNotes) {
            $tx = WalletTransaction::query()->whereKey($tx->id)->lockForUpdate()->firstOrFail();
            $wallet = Wallet::query()->whereKey($tx->wallet_id)->lockForUpdate()->firstOrFail();
            $user = User::query()->findOrFail($tx->user_id);
            $amount = (float) $tx->amount;

            $category = $tx->category instanceof WalletTransactionCategory
                ? $tx->category
                : WalletTransactionCategory::tryFrom((string) $tx->category);

            // Release hold for withdrawals
            if ($category === WalletTransactionCategory::Withdrawal) {
                $wallet->blocked_balance = max(0, (float) $wallet->blocked_balance - $amount);
                $wallet->save();
            }

            $tx->update([
                'status' => WalletTransactionStatus::Rejected,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now(),
                'admin_notes' => $adminNotes,
                'balance_after' => (float) $wallet->balance,
            ]);

            $this->notifyUser($user, 'wallet_transaction_rejected', [
                'amount' => number_format($amount, 2),
                'currency' => $wallet->currency,
                'reference' => $tx->reference,
                'reason' => $adminNotes ?: 'Rejected by admin',
            ]);

            return $tx->fresh(['user', 'reviewer', 'wallet']);
        });
    }

    /**
     * Admin force set / adjust balance by delta (positive = credit).
     */
    public function adminAdjust(
        User $target,
        float $delta,
        string $description,
        User $admin,
        ?string $adminNotes = null
    ): WalletTransaction {
        if ($delta == 0.0) {
            throw ValidationException::withMessages(['amount' => 'Amount cannot be zero.']);
        }

        if ($delta > 0) {
            $tx = $this->credit(
                $target,
                abs($delta),
                $description,
                WalletTransactionCategory::Adjustment,
                $this->makeReference('ADJ'),
                ['admin_id' => $admin->id],
                $admin,
                notify: true
            );
        } else {
            $tx = $this->debit(
                $target,
                abs($delta),
                $description,
                WalletTransactionCategory::Adjustment,
                $this->makeReference('ADJ'),
                ['admin_id' => $admin->id],
                $admin,
                notify: true
            );
        }

        if ($adminNotes) {
            $tx->update(['admin_notes' => $adminNotes, 'reviewed_by' => $admin->id, 'reviewed_at' => now()]);
        }

        return $tx->fresh();
    }

    public function setActive(Wallet $wallet, bool $active, User $admin): Wallet
    {
        $wallet->update(['is_active' => $active]);

        if ($wallet->user) {
            $this->notifyUser($wallet->user, $active ? 'wallet_activated' : 'wallet_suspended', [
                'currency' => $wallet->currency,
            ]);
        }

        return $wallet->fresh();
    }

    protected function createTx(
        Wallet $wallet,
        WalletTransactionType $type,
        WalletTransactionCategory|string $category,
        float $amount,
        float $balanceBefore,
        float $balanceAfter,
        string $description,
        ?string $reference,
        ?array $metadata,
        WalletTransactionStatus $status,
        ?User $reviewer = null,
    ): WalletTransaction {
        $categoryEnum = $category instanceof WalletTransactionCategory
            ? $category
            : (WalletTransactionCategory::tryFrom((string) $category) ?? WalletTransactionCategory::Adjustment);

        return WalletTransaction::query()->create([
            'wallet_id' => $wallet->id,
            'user_id' => $wallet->user_id,
            'type' => $type,
            'category' => $categoryEnum,
            'amount' => $amount,
            'balance_before' => $balanceBefore,
            'balance_after' => $balanceAfter,
            'description' => $description,
            'reference' => $reference ?: $this->makeReference('TXN'),
            'metadata' => $metadata,
            'status' => $status,
            'reviewed_by' => $reviewer?->id,
            'reviewed_at' => $reviewer ? now() : null,
        ]);
    }

    protected function makeReference(string $prefix): string
    {
        return strtoupper($prefix).'-'.now()->format('YmdHis').'-'.Str::upper(Str::random(6));
    }

    protected function assertPositive(float $amount): void
    {
        if ($amount <= 0) {
            throw ValidationException::withMessages([
                'amount' => 'Amount must be greater than zero.',
            ]);
        }
    }

    protected function assertActive(Wallet $wallet): void
    {
        if (! $wallet->is_active) {
            throw ValidationException::withMessages([
                'wallet' => 'This wallet is suspended. Contact support.',
            ]);
        }
    }

    protected function notifyUser(User $user, string $type, array $data): void
    {
        try {
            $this->notifications->send($user, $type, $data);
        } catch (\Throwable $e) {
            report($e);
        }
    }

    protected function notifyAdmins(string $type, array $data): void
    {
        try {
            $admins = User::query()
                ->whereIn('role', ['admin', 'super_admin', 'ops_manager'])
                ->orWhereHas('roles', fn ($q) => $q->whereIn('name', ['admin', 'super_admin', 'ops_manager']))
                ->limit(50)
                ->get();

            foreach ($admins as $admin) {
                $this->notifications->send($admin, $type, $data);
            }
        } catch (\Throwable $e) {
            report($e);
        }
    }
}
