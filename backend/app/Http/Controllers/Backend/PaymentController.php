<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Concerns\ScopesByRoleArea;
use App\Http\Controllers\Controller;
use App\Models\Payment;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class PaymentController extends Controller
{
    use ScopesByRoleArea;

    public function index(Request $request): Response
    {
        $user = $request->user();
        $query = Payment::query()
            ->with([
                'user:id,name,email,phone',
                'order:id,order_number,total_amount,buyer_id,seller_id',
            ])
            ->latest();

        $this->scopePaymentsQuery($query, $user);

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('payment_reference', 'like', "%{$search}%")
                    ->orWhere('transaction_id', 'like', "%{$search}%")
                    ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%"));
            });
        }

        if ($status = $request->input('status')) {
            $query->where('status', $status);
        }

        if ($method = $request->input('payment_method')) {
            $query->where('payment_method', $method);
        }

        $payments = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (Payment $p) => [
                'id' => $p->id,
                'payment_reference' => $p->payment_reference,
                'transaction_id' => $p->transaction_id,
                'amount' => (float) $p->amount,
                'currency' => $p->currency ?? 'GHS',
                'payment_method' => $p->payment_method,
                'payment_channel' => $p->payment_channel,
                'status' => $p->status,
                'user' => $p->user,
                'order' => $p->order,
                'paid_at' => optional($p->paid_at)?->toDateTimeString(),
                'created_at' => optional($p->created_at)?->toDateTimeString(),
            ]);

        $summaryBase = Payment::query();
        $this->scopePaymentsQuery($summaryBase, $user);

        return Inertia::render('backend/Payments/index', [
            'payments' => $payments,
            'filters' => $request->only(['search', 'status', 'payment_method']),
            'area' => $this->roleAreaPrefix($request),
            'statuses' => [
                Payment::STATUS_PENDING,
                Payment::STATUS_SUCCESS,
                Payment::STATUS_FAILED,
                Payment::STATUS_REFUNDED,
                Payment::STATUS_CANCELLED,
            ],
            'summary' => [
                'total' => (float) (clone $summaryBase)->where('status', Payment::STATUS_SUCCESS)->sum('amount'),
                'pending' => (clone $summaryBase)->where('status', Payment::STATUS_PENDING)->count(),
                'success' => (clone $summaryBase)->where('status', Payment::STATUS_SUCCESS)->count(),
                'failed' => (clone $summaryBase)->where('status', Payment::STATUS_FAILED)->count(),
            ],
        ]);
    }

    public function show(Request $request, int $id): Response
    {
        $user = $request->user();
        $payment = Payment::with(['user:id,name,email,phone', 'order'])->findOrFail($id);

        if ($user && ! $this->isAdminPanelUser($user)) {
            $allowed = false;
            if ($user->isBuyer() && (int) $payment->user_id === (int) $user->id) {
                $allowed = true;
            }
            if ($user->isSeller() && $payment->order && (int) $payment->order->seller_id === (int) $user->id) {
                $allowed = true;
            }
            abort_unless($allowed, 403);
        }

        return Inertia::render('backend/Payments/show', [
            'payment' => $payment,
            'area' => $this->roleAreaPrefix($request),
        ]);
    }
}
