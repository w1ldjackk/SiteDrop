<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\WalletTransaction;
use App\Services\Wallet\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    public function __construct(
        protected WalletService $wallets
    ) {}

    public function show(Request $request): JsonResponse
    {
        $wallet = $this->wallets->getOrCreateWallet($request->user());

        return $this->success([
            'wallet' => $this->transformWallet($wallet),
        ]);
    }

    public function transactions(Request $request): JsonResponse
    {
        $summary = $this->wallets->summary($request->user(), (int) $request->integer('per_page', 20));

        return $this->success([
            'wallet' => $this->transformWallet($summary['wallet']),
            'transactions' => $summary['transactions']->getCollection()->map(
                fn (WalletTransaction $t) => $this->transformTx($t)
            )->values(),
            'meta' => $this->paginationMeta($summary['transactions']),
        ]);
    }

    public function deposit(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'note' => ['nullable', 'string', 'max:500'],
            'payment_reference' => ['nullable', 'string', 'max:120'],
            // Saved payment method used for this deposit (Account → Payment).
            'payment_method' => ['nullable', 'string', 'max:60'],
            'instrument_id' => ['nullable', 'integer', 'exists:payment_instruments,id'],
        ]);

        if (!empty($data['instrument_id'])) {
            $owns = \App\Models\PaymentInstrument::where('id', $data['instrument_id'])
                ->where('user_id', $request->user()->id)
                ->exists();
            if (!$owns) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Unknown payment account',
                ], 422);
            }
        }

        $tx = $this->wallets->requestDeposit(
            $request->user(),
            (float) $data['amount'],
            $data['note'] ?? null,
            array_filter([
                'payment_reference' => $data['payment_reference'] ?? null,
                'payment_method' => $data['payment_method'] ?? null,
                'instrument_id' => $data['instrument_id'] ?? null,
            ])
        );

        return $this->success(
            data: ['transaction' => $this->transformTx($tx)],
            message: 'Deposit request submitted for admin approval',
            status: 201,
        );
    }

    public function withdraw(Request $request): JsonResponse
    {
        $data = $request->validate([
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'note' => ['nullable', 'string', 'max:500'],
            'destination' => ['nullable', 'string', 'max:255'],
        ]);

        $tx = $this->wallets->requestWithdrawal(
            $request->user(),
            (float) $data['amount'],
            $data['note'] ?? null,
            array_filter([
                'destination' => $data['destination'] ?? null,
            ])
        );

        return $this->success(
            data: ['transaction' => $this->transformTx($tx)],
            message: 'Withdrawal request submitted for admin approval',
            status: 201,
        );
    }

    /**
     * Look up a transfer recipient by phone or email (masked for privacy).
     * GET /wallet/lookup?recipient=+233… or email
     */
    public function lookup(Request $request): JsonResponse
    {
        $request->validate(['recipient' => ['required', 'string', 'max:120']]);
        $user = $this->findRecipient($request->input('recipient'));
        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'No SiteDrop user found for that phone or email',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => [
                'recipient' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'phone' => $this->maskPhone($user->phone),
                    'is_self' => (int) $user->id === (int) $request->user()->id,
                ],
            ],
        ]);
    }

    /**
     * Internal transfer between SiteDrop users (instant).
     * POST /wallet/transfer  { recipient, amount, note? }
     */
    public function transfer(Request $request): JsonResponse
    {
        $data = $request->validate([
            'recipient' => ['required', 'string', 'max:120'],
            'amount' => ['required', 'numeric', 'min:1', 'max:1000000'],
            'note' => ['nullable', 'string', 'max:500'],
        ]);

        $sender = $request->user();
        $recipient = $this->findRecipient($data['recipient']);
        if (!$recipient) {
            return response()->json([
                'status' => 'error',
                'message' => 'No SiteDrop user found for that phone or email',
            ], 404);
        }
        if ((int) $recipient->id === (int) $sender->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'You cannot transfer to yourself',
            ], 422);
        }

        try {
            $result = $this->wallets->transfer(
                $sender,
                $recipient,
                (float) $data['amount'],
                $data['note'] ?? null
            );
        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json([
                'status' => 'error',
                'message' => collect($e->errors())->flatten()->first() ?? 'Transfer failed',
            ], 422);
        }

        return response()->json([
            'status' => 'success',
            'message' => 'Transfer sent to ' . $recipient->name,
            'data' => [
                'transaction' => $this->transformTx($result['debit']),
                'recipient' => [
                    'id' => $recipient->id,
                    'name' => $recipient->name,
                ],
            ],
        ], 201);
    }

    /**
     * Match phone (last-9-digits, handles +233/0 prefixes) or exact email.
     */
    protected function findRecipient(string $input): ?\App\Models\User
    {
        $input = trim($input);
        if (filter_var($input, FILTER_VALIDATE_EMAIL)) {
            return \App\Models\User::where('email', $input)->first();
        }

        $digits = preg_replace('/\D/', '', $input);
        if (strlen($digits) < 9) {
            return null;
        }

        // Match the local 9-digit tail without relying on MySQL-only
        // functions (REGEXP_REPLACE / RIGHT), so this works on SQLite too.
        $tail = substr($digits, -9);
        $variants = array_unique([
            $tail,
            '0' . $tail,
            '233' . $tail,
            '+233' . $tail,
            '00233' . $tail,
        ]);

        $user = \App\Models\User::whereIn('phone', $variants)->first();
        if ($user) {
            return $user;
        }

        // Fallback for numbers stored with spaces / dashes / other prefixes.
        return \App\Models\User::where('phone', 'like', '%' . $tail)->first();
    }

    protected function maskPhone(?string $phone): ?string
    {
        if (!$phone) {
            return null;
        }
        $digits = preg_replace('/\D/', '', $phone);
        if (strlen($digits) < 7) {
            return '••••' . substr($digits, -2);
        }
        return substr($digits, 0, 3) . '••••' . substr($digits, -3);
    }

    /**
     * @return array<string, mixed>
     */
    protected function transformWallet($wallet): array
    {
        return [
            'id' => $wallet->id,
            'user_id' => $wallet->user_id,
            'balance' => (float) $wallet->balance,
            'blocked_balance' => (float) $wallet->blocked_balance,
            'available_balance' => (float) $wallet->available_balance,
            'total_earned' => (float) $wallet->total_earned,
            'total_spent' => (float) $wallet->total_spent,
            'currency' => $wallet->currency,
            'is_active' => (bool) $wallet->is_active,
            'last_transaction_at' => optional($wallet->last_transaction_at)?->toIso8601String(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function transformTx(WalletTransaction $t): array
    {        $type = $t->type;
        $status = $t->status;
        $category = $t->category;

        return [
            'id' => $t->id,
            'type' => $type instanceof \BackedEnum ? $type->value : (string) $type,
            'category' => $category instanceof \BackedEnum ? $category->value : (string) $category,
            'amount' => (float) $t->amount,
            'balance_before' => $t->balance_before !== null ? (float) $t->balance_before : null,
            'balance_after' => $t->balance_after !== null ? (float) $t->balance_after : null,
            'description' => $t->description,
            'reference' => $t->reference,
            'status' => $status instanceof \BackedEnum ? $status->value : (string) $status,
            'admin_notes' => $t->admin_notes,
            'metadata' => $t->metadata,
            'created_at' => optional($t->created_at)?->toIso8601String(),
            'reviewed_at' => optional($t->reviewed_at)?->toIso8601String(),
            'formatted_amount' => $t->formatted_amount,
        ];
    }
}
