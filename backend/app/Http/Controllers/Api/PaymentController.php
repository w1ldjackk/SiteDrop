<?php
// app/Http/Controllers/Api/PaymentController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\PaymentRequest;
use App\Models\Order;
use App\Models\Payment;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Services\Payment\PaymentService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;

class PaymentController extends Controller
{
    use AuthorizesRequests;

    protected PaymentService $paymentService;

    public function __construct(PaymentService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    /**
     * Get available payment methods
     */
    public function methods(): JsonResponse
    {
        return response()->json([
            'status' => 'success',
            'data' => $this->paymentService->getPaymentMethods(),
        ]);
    }

    /**
     * Initiate payment for an order
     */
    public function initiate(PaymentRequest $request): JsonResponse
    {
        $user = $request->user();

        $order = Order::where('id', $request->order_id)
            ->where('buyer_id', $user->id)
            ->firstOrFail();

        // Check if order is already paid
        if ($order->payment_status === Order::PAYMENT_STATUS_PAID) {
            return response()->json([
                'status' => 'error',
                'message' => 'This order has already been paid',
            ], 400);
        }

        // Process payment
        $result = $this->paymentService->processPayment(
            $order,
            $request->payment_method,
            $request->validated()
        );

        if ($result['success']) {
            ActivityLogger::log(
                ActivityActions::PAYMENT_INITIATED,
                "Payment initiated for order #{$order->id}",
                $order,
                [
                    'order_id' => $order->id,
                    'payment_method' => $request->payment_method,
                    'amount' => $order->total_amount ?? null,
                ],
                module: 'payments',
                userId: $user->id,
            );

            return response()->json([
                'status' => 'success',
                'message' => $result['message'],
                'data' => $result,
            ]);
        }

        ActivityLogger::log(
            ActivityActions::PAYMENT_FAILED,
            "Payment initiation failed for order #{$order->id}",
            $order,
            [
                'order_id' => $order->id,
                'message' => $result['message'] ?? null,
            ],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'payments',
            userId: $user->id,
        );

        return response()->json([
            'status' => 'error',
            'message' => $result['message'],
        ], 400);
    }

    /**
     * Verify payment status
     */
    public function verify(Request $request): JsonResponse
    {
        $request->validate([
            'payment_reference' => 'required|string',
        ]);

        $payment = Payment::where('payment_reference', $request->payment_reference)->firstOrFail();

        // Check if user owns this payment
        if ($payment->user_id !== Auth::id()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to verify this payment',
            ], 403);
        }

        $result = $this->paymentService->verifyPayment($payment);

        ActivityLogger::log(
            $result['success']
                ? ActivityActions::PAYMENT_VERIFIED
                : ActivityActions::PAYMENT_FAILED,
            $result['success']
                ? "Payment verified ({$payment->payment_reference})"
                : "Payment verification failed ({$payment->payment_reference})",
            $payment,
            [
                'payment_reference' => $payment->payment_reference,
                'order_id' => $payment->order_id,
                'success' => $result['success'] ?? false,
            ],
            level: $result['success']
                ? \App\Models\ActivityLog::LEVEL_INFO
                : \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'payments',
            userId: Auth::id(),
        );

        return response()->json([
            'status' => $result['success'] ? 'success' : 'error',
            'message' => $result['message'],
            'data' => $result,
        ]);
    }

    /**
     * Get the payment attached to an order (buyer's own order only).
     */
    public function byOrder(Request $request, $orderId): JsonResponse
    {
        $order = Order::findOrFail($orderId);

        if ($order->buyer_id !== Auth::id() && ! Auth::user()->isAdmin()) {
            return response()->json([
                'status' => 'error',
                'message' => 'You do not have permission to view this payment',
            ], 403);
        }

        $payment = Payment::where('order_id', $order->id)
            ->latest()
            ->first();

        if (! $payment) {
            return response()->json([
                'status' => 'error',
                'message' => 'Payment not found',
            ], 404);
        }

        return response()->json([
            'status' => 'success',
            'data' => ['payment' => $payment],
        ]);
    }

    /**
     * Get payment history
     */
    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $payments = Payment::where('user_id', $user->id)
            ->with(['order'])
            ->orderBy('created_at', 'desc')
            ->paginate($request->get('per_page', 20));

        return response()->json([
            'status' => 'success',
            'data' => [
                'payments' => $payments->items(),
                'pagination' => [
                    'current_page' => $payments->currentPage(),
                    'last_page' => $payments->lastPage(),
                    'per_page' => $payments->perPage(),
                    'total' => $payments->total(),
                ],
            ],
        ]);
    }

    /**
     * Hubtel callback webhook
     */
    public function hubtelCallback(Request $request): JsonResponse
    {
        // Verify Hubtel signature
        $this->verifyHubtelSignature($request);

        Log::info('Hubtel callback received', ['payload' => $request->all()]);

        try {
            $reference = $request->input('transaction_id') ?? $request->input('reference');

            if (!$reference) {
                return response()->json(['status' => 'error', 'message' => 'Reference not found'], 400);
            }

            $payment = Payment::where('transaction_id', $reference)
                ->orWhere('payment_reference', $reference)
                ->first();

            if (!$payment) {
                return response()->json(['status' => 'error', 'message' => 'Payment not found'], 404);
            }

            $result = $this->paymentService->verifyPayment($payment);

            if ($result['success']) {
                return response()->json(['status' => 'success']);
            }

            return response()->json(['status' => 'error', 'message' => 'Payment verification failed'], 400);
        } catch (\Exception $e) {
            Log::error('Hubtel callback error', [
                'error' => $e->getMessage(),
                'payload' => $request->all(),
            ]);

            return response()->json(['status' => 'error', 'message' => 'Payment callback failed'], 500);
        }
    }

    /**
     * Paystack callback webhook
     */
    public function paystackCallback(Request $request): JsonResponse
    {
        // Verify Paystack signature
        $this->verifyPaystackSignature($request);

        Log::info('Paystack callback received', ['payload' => $request->all()]);

        try {
            $reference = $request->input('reference');

            if (!$reference) {
                return response()->json(['status' => 'error', 'message' => 'Reference not found'], 400);
            }

            $payment = Payment::where('transaction_id', $reference)
                ->orWhere('payment_reference', $reference)
                ->first();

            if (!$payment) {
                return response()->json(['status' => 'error', 'message' => 'Payment not found'], 404);
            }

            $result = $this->paymentService->verifyPayment($payment);

            if ($result['success']) {
                return response()->json(['status' => 'success']);
            }

            return response()->json(['status' => 'error', 'message' => 'Payment verification failed'], 400);
        } catch (\Exception $e) {
            Log::error('Paystack callback error', [
                'error' => $e->getMessage(),
                'payload' => $request->all(),
            ]);

            return response()->json(['status' => 'error', 'message' => 'Payment callback failed'], 500);
        }
    }

    /**
     * Verify Hubtel webhook signature (HMAC-SHA256)
     */
    protected function verifyHubtelSignature(Request $request): void
    {
        $signature = $request->header('X-Hubtel-Signature');
        if (!$signature) {
            throw new \Illuminate\Validation\ValidationException(
                response()->json(['status' => 'error', 'message' => 'Missing Hubtel signature'], 401)
            );
        }

        $secret = config('services.hubtel.secret_key');
        if (!$secret) {
            Log::warning('Hubtel secret key not configured, skipping signature verification');
            return;
        }

        $payload = $request->getContent();
        $expected = hash_hmac('sha256', $payload, $secret);

        if (!hash_equals($expected, $signature)) {
            throw new \Illuminate\Validation\ValidationException(
                response()->json(['status' => 'error', 'message' => 'Invalid Hubtel signature'], 401)
            );
        }
    }

    /**
     * Verify Paystack webhook signature (HMAC-SHA512)
     */
    protected function verifyPaystackSignature(Request $request): void
    {
        $signature = $request->header('X-Paystack-Signature');
        if (!$signature) {
            throw new \Illuminate\Validation\ValidationException(
                response()->json(['status' => 'error', 'message' => 'Missing Paystack signature'], 401)
            );
        }

        $secret = config('services.paystack.secret_key');
        if (!$secret) {
            Log::warning('Paystack secret key not configured, skipping signature verification');
            return;
        }

        $payload = $request->getContent();
        $expected = hash_hmac('sha512', $payload, $secret);

        if (!hash_equals($expected, $signature)) {
            throw new \Illuminate\Validation\ValidationException(
                response()->json(['status' => 'error', 'message' => 'Invalid Paystack signature'], 401)
            );
        }
    }
}
