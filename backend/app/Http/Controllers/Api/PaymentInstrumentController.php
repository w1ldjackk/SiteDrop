<?php
// app/Http/Controllers/Api/PaymentInstrumentController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\PaymentInstrument;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class PaymentInstrumentController extends Controller
{
    /**
     * My saved instruments (masked).
     * GET /payments/instruments
     */
    public function index(): JsonResponse
    {
        $items = PaymentInstrument::where('user_id', Auth::id())
            ->orderByDesc('is_default')
            ->latest()
            ->get()
            ->map(fn (PaymentInstrument $i) => $i->safeArray())
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => ['instruments' => $items],
        ]);
    }

    /**
     * Add an instrument. Type-specific details, encrypted at rest.
     * POST /payments/instruments
     */
    public function store(Request $request): JsonResponse
    {
        $user = Auth::user();
        $type = $request->input('type');

        if (!in_array($type, PaymentInstrument::TYPES, true)) {
            return response()->json([
                'status' => 'error',
                'message' => 'Unknown instrument type',
            ], 422);
        }

        $data = $this->validateForType($request, $type);
        $built = $this->buildAttributes($type, $data);

        $instrument = DB::transaction(function () use ($user, $type, $built, $data) {
            $isFirst = !PaymentInstrument::where('user_id', $user->id)->exists();
            $instrument = PaymentInstrument::create([
                'user_id' => $user->id,
                'type' => $type,
                'label' => $data['label'] ?? null,
                'is_default' => $isFirst,
                ...$built,
            ]);
            return $instrument;
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Payment method saved',
            'data' => ['instrument' => $instrument->safeArray()],
        ], 201);
    }

    /**
     * Edit label / holder / number (re-derives last4).
     * PUT /payments/instruments/{id}
     */
    public function update(Request $request, $id): JsonResponse
    {
        $instrument = PaymentInstrument::where('user_id', Auth::id())
            ->findOrFail($id);

        $data = $this->validateForType($request, $instrument->type, partial: true);
        $built = $this->buildAttributes($instrument->type, $data, $instrument);

        $instrument->update(array_merge(
            ['label' => $data['label'] ?? $instrument->label],
            array_filter($built, fn ($v) => $v !== null)
        ));

        return response()->json([
            'status' => 'success',
            'message' => 'Payment method updated',
            'data' => ['instrument' => $instrument->fresh()->safeArray()],
        ]);
    }

    /**
     * DELETE /payments/instruments/{id}
     */
    public function destroy($id): JsonResponse
    {
        $instrument = PaymentInstrument::where('user_id', Auth::id())
            ->findOrFail($id);

        DB::transaction(function () use ($instrument) {
            $wasDefault = $instrument->is_default;
            $userId = $instrument->user_id;
            $instrument->delete();
            if ($wasDefault) {
                $next = PaymentInstrument::where('user_id', $userId)
                    ->oldest()
                    ->first();
                if ($next) {
                    $next->update(['is_default' => true]);
                }
            }
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Payment method removed',
        ]);
    }

    /**
     * POST /payments/instruments/{id}/default
     */
    public function setDefault($id): JsonResponse
    {
        $userId = Auth::id();
        $instrument = PaymentInstrument::where('user_id', $userId)
            ->findOrFail($id);

        DB::transaction(function () use ($userId, $instrument) {
            PaymentInstrument::where('user_id', $userId)
                ->update(['is_default' => false]);
            $instrument->update(['is_default' => true]);
        });

        return response()->json([
            'status' => 'success',
            'message' => 'Default payment method updated',
            'data' => ['instrument' => $instrument->fresh()->safeArray()],
        ]);
    }

    // ============================================================
    // PER-TYPE VALIDATION + NORMALIZATION
    // ============================================================

    /**
     * @return array<string, mixed> validated data
     */
    private function validateForType(Request $request, string $type, bool $partial = false): array
    {
        $sometimes = $partial ? 'sometimes' : 'required';
        $request->validate(['label' => ['nullable', 'string', 'max:60']]);

        return match ($type) {
            PaymentInstrument::TYPE_MOMO => $request->validate([
                'network' => [$sometimes, 'string', 'in:' . implode(',', PaymentInstrument::MOMO_NETWORKS)],
                'phone' => [$sometimes, 'string', 'regex:/^(\+?233\d{9}|0\d{9})$/'],
            ]) + ['label' => $request->input('label')],
            PaymentInstrument::TYPE_CARD => $request->validate([
                'number' => [$sometimes, 'string', 'regex:/^\d{13,19}$/'],
                'exp' => [$sometimes, 'string', 'regex:/^(0[1-9]|1[0-2])\/\d{2}$/'],
                'holder' => [$sometimes, 'string', 'max:120'],
            ]) + ['label' => $request->input('label')],
            default => $request->validate([
                'bank_name' => [$sometimes, 'string', 'max:120'],
                'account_number' => [$sometimes, 'string', 'regex:/^\d{8,20}$/'],
                'holder' => [$sometimes, 'string', 'max:120'],
            ]) + ['label' => $request->input('label')],
        };
    }

    /**
     * Normalize + derive display fields. Throws 422 on bad card data.
     *
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function buildAttributes(string $type, array $data, ?PaymentInstrument $existing = null): array
    {
        if ($type === PaymentInstrument::TYPE_MOMO) {
            if (!isset($data['phone']) && !$existing) {
                abort(422, 'Phone number is required');
            }
            $phone = isset($data['phone'])
                ? preg_replace('/\s+/', '', (string) $data['phone'])
                : ($existing?->fullNumber() ?? '');
            return [
                'network' => $data['network'] ?? $existing?->network,
                'last4' => substr(preg_replace('/\D/', '', $phone), -4) ?: null,
                'holder' => null,
                'exp' => null,
                'details' => ['phone' => $phone],
            ];
        }

        if ($type === PaymentInstrument::TYPE_CARD) {
            $number = isset($data['number'])
                ? preg_replace('/\s+/', '', (string) $data['number'])
                : ($existing?->fullNumber() ?? '');
            if ($number === '' && !$existing) {
                abort(422, 'Card number is required');
            }
            if ($number !== '' && !$this->luhnValid($number)) {
                abort(422, 'Card number looks invalid');
            }
            if (isset($data['exp']) && !$this->expValid($data['exp'])) {
                abort(422, 'Card expiry must be in the future (MM/YY)');
            }
            return [
                'network' => $number !== '' ? $this->cardBrand($number) : $existing?->network,
                'last4' => $number !== '' ? substr($number, -4) : $existing?->last4,
                'exp' => $data['exp'] ?? $existing?->exp,
                'holder' => $data['holder'] ?? $existing?->holder,
                'details' => $number !== ''
                    ? ['number' => $number]
                    : ($existing?->details ?? []),
            ];
        }

        // Bank.
        $account = isset($data['account_number'])
            ? preg_replace('/\s+/', '', (string) $data['account_number'])
            : ($existing?->fullNumber() ?? '');
        return [
            'network' => $data['bank_name'] ?? $existing?->network,
            'last4' => $account !== '' ? substr($account, -4) : $existing?->last4,
            'exp' => null,
            'holder' => $data['holder'] ?? $existing?->holder,
            'details' => $account !== ''
                ? ['account' => $account]
                : ($existing?->details ?? []),
        ];
    }

    private function luhnValid(string $number): bool
    {
        $sum = 0;
        $alt = false;
        for ($i = strlen($number) - 1; $i >= 0; $i--) {
            $digit = (int) $number[$i];
            if ($alt) {
                $digit *= 2;
                if ($digit > 9) {
                    $digit -= 9;
                }
            }
            $sum += $digit;
            $alt = !$alt;
        }
        return $sum % 10 === 0;
    }

    private function expValid(string $exp): bool
    {
        [$m, $y] = array_map('intval', explode('/', $exp));
        $year = 2000 + $y;
        $end = mktime(23, 59, 59, $m + 1, 0, $year);
        return $end > time();
    }

    private function cardBrand(string $number): string
    {
        if (str_starts_with($number, '4')) {
            return 'Visa';
        }
        if (preg_match('/^(5[1-5]|2[2-7])/', $number)) {
            return 'Mastercard';
        }
        if (preg_match('/^3[47]/', $number)) {
            return 'Amex';
        }
        return 'Card';
    }
}
