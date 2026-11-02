<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Services\Wallet\WalletService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class WalletController extends Controller
{
    public function __construct(
        protected WalletService $wallets
    ) {}

    /**
     * Role wallet page (buyer / seller / driver / admin own wallet).
     */
    public function myWallet(Request $request): Response
    {
        $user = $request->user();
        $summary = $this->wallets->summary($user, 15);
        $area = $this->areaFromRequest($request);

        return Inertia::render('backend/Wallets/MyWallet', [
            'wallet' => $summary['wallet'],
            'transactions' => $summary['transactions'],
            'area' => $area,
            'canRequest' => true,
        ]);
    }

    public function requestDeposit(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $this->wallets->requestDeposit(
            $request->user(),
            (float) $data['amount'],
            $data['note'] ?? null
        );

        return back()->with('success', 'Deposit request submitted for approval.');
    }

    public function requestWithdrawal(Request $request): RedirectResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'note' => ['nullable', 'string', 'max:500'],
            'destination' => ['nullable', 'string', 'max:255'],
        ]);

        $this->wallets->requestWithdrawal(
            $request->user(),
            (float) $data['amount'],
            $data['note'] ?? null,
            array_filter(['destination' => $data['destination'] ?? null])
        );

        return back()->with('success', 'Withdrawal request submitted for approval.');
    }

    // ─── Admin ─────────────────────────────────────────────

    public function adminIndex(Request $request): Response
    {
        $search = (string) $request->query('search', '');
        $status = (string) $request->query('status', '');

        $wallets = Wallet::query()
            ->with(['user:id,name,email,phone,role'])
            ->when($search !== '', function ($q) use ($search) {
                $q->whereHas('user', function ($u) use ($search) {
                    $u->where('name', 'like', "%{$search}%")
                        ->orWhere('email', 'like', "%{$search}%")
                        ->orWhere('phone', 'like', "%{$search}%");
                });
            })
            ->orderByDesc('updated_at')
            ->paginate(20)
            ->withQueryString();

        $pending = WalletTransaction::query()
            ->pending()
            ->with(['user:id,name,email,phone', 'wallet'])
            ->latest()
            ->limit(30)
            ->get();

        $summary = [
            'wallets' => Wallet::query()->count(),
            'total_balance' => (float) Wallet::query()->sum('balance'),
            'total_blocked' => (float) Wallet::query()->sum('blocked_balance'),
            'pending_count' => WalletTransaction::query()->pending()->count(),
        ];

        return Inertia::render('backend/Wallets/AdminIndex', [
            'wallets' => $wallets,
            'pending' => $pending,
            'filters' => ['search' => $search, 'status' => $status],
            'summary' => $summary,
            'area' => 'admin',
        ]);
    }

    public function adminShow(Request $request, int $id): Response
    {
        $wallet = Wallet::query()->with('user')->findOrFail($id);
        $transactions = WalletTransaction::query()
            ->where('wallet_id', $wallet->id)
            ->with('reviewer:id,name')
            ->latest()
            ->paginate(25)
            ->withQueryString();

        return Inertia::render('backend/Wallets/AdminShow', [
            'wallet' => $wallet,
            'transactions' => $transactions,
            'area' => 'admin',
        ]);
    }

    public function adminApprove(Request $request, int $id): RedirectResponse
    {
        $data = $request->validate([
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $tx = WalletTransaction::query()->findOrFail($id);
        $this->wallets->approve($tx, $request->user(), $data['admin_notes'] ?? null);

        return back()->with('success', 'Transaction approved.');
    }

    public function adminReject(Request $request, int $id): RedirectResponse
    {
        $data = $request->validate([
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $tx = WalletTransaction::query()->findOrFail($id);
        $this->wallets->reject($tx, $request->user(), $data['admin_notes'] ?? null);

        return back()->with('success', 'Transaction rejected.');
    }

    public function adminAdjust(Request $request, int $walletId): RedirectResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'not_in:0', 'max:1000000'],
            'description' => ['required', 'string', 'max:500'],
            'admin_notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $wallet = Wallet::query()->findOrFail($walletId);
        $user = User::query()->findOrFail($wallet->user_id);

        $this->wallets->adminAdjust(
            $user,
            (float) $data['amount'],
            $data['description'],
            $request->user(),
            $data['admin_notes'] ?? null
        );

        return back()->with('success', 'Wallet adjusted.');
    }

    public function adminToggle(Request $request, int $walletId): RedirectResponse
    {
        $wallet = Wallet::query()->findOrFail($walletId);
        $this->wallets->setActive($wallet, ! $wallet->is_active, $request->user());

        return back()->with(
            'success',
            $wallet->fresh()->is_active ? 'Wallet activated.' : 'Wallet suspended.'
        );
    }

    public function adminCredit(Request $request, int $walletId): RedirectResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:0.01', 'max:1000000'],
            'description' => ['required', 'string', 'max:500'],
        ]);

        $wallet = Wallet::query()->findOrFail($walletId);
        $user = User::query()->findOrFail($wallet->user_id);

        $this->wallets->credit(
            $user,
            (float) $data['amount'],
            $data['description'],
            \App\Enums\WalletTransactionCategory::Adjustment,
            null,
            ['admin_id' => $request->user()->id],
            $request->user()
        );

        return back()->with('success', 'Funds added to wallet.');
    }

    protected function areaFromRequest(Request $request): string
    {
        $segment = explode('/', trim($request->path(), '/'))[0] ?? 'buyer';

        return in_array($segment, ['admin', 'buyer', 'seller', 'driver'], true)
            ? $segment
            : 'buyer';
    }
}
