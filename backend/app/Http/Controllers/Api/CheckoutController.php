<?php
// app/Http/Controllers/Api/CheckoutController.php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\CheckoutRequest;
use App\Models\Cart;
use App\Models\Order;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Services\Checkout\CheckoutService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\URL;

class CheckoutController extends Controller
{
    use AuthorizesRequests;

    protected CheckoutService $checkoutService;

    public function __construct(CheckoutService $checkoutService)
    {
        $this->checkoutService = $checkoutService;
    }

    /**
     * Get order summary with fees
     */
    public function summary(Request $request): JsonResponse
    {
        try {
            $user = $request->user();

            $cart = Cart::where('user_id', $user->id)
                ->where('status', 'active')
                ->with(['items.product'])
                ->first();

            if (!$cart || $cart->items->isEmpty()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Your cart is empty',
                ], 400);
            }

            $summary = $this->checkoutService->calculateSummary($cart);
            $validation = $this->checkoutService->validateCart($cart);

            return response()->json([
                'status' => 'success',
                'data' => [
                    'summary' => $summary,
                    'validation' => $validation,
                    'cart_id' => $cart->id,
                ],
            ]);
        } catch (\Exception $e) {
            Log::error('Checkout summary error', [
                'user_id' => $request->user()->id ?? null,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to get checkout summary. Please try again.',
            ], 500);
        }
    }

    /**
     * Validate cart before checkout
     */
    public function validateCart(Request $request): JsonResponse
    {
        try {
            $user = $request->user();

            $cart = Cart::where('user_id', $user->id)
                ->where('status', 'active')
                ->with(['items.product'])
                ->first();

            if (!$cart || $cart->items->isEmpty()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Your cart is empty',
                ], 400);
            }

            $validation = $this->checkoutService->validateCart($cart);

            return response()->json([
                'status' => 'success',
                'data' => $validation,
            ]);
        } catch (\Exception $e) {
            Log::error('Cart validation error', [
                'user_id' => $request->user()->id ?? null,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to validate cart. Please try again.',
            ], 500);
        }
    }

    /**
     * Place order from cart
     */
    public function placeOrder(CheckoutRequest $request): JsonResponse
    {
        try {
            $user = $request->user();

            $cart = Cart::where('user_id', $user->id)
                ->where('status', 'active')
                ->with(['items.product'])
                ->first();

            if (!$cart || $cart->items->isEmpty()) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Your cart is empty',
                ], 400);
            }

            // Validate payment method
            $paymentMethod = $request->payment_method;
            if (!$this->checkoutService->isPaymentMethodAvailable($paymentMethod)) {
                return response()->json([
                    'status' => 'error',
                    'message' => "Payment method '{$paymentMethod}' is not available",
                ], 400);
            }

            // Validate payment method specific fields
            $validation = $this->checkoutService->validatePaymentMethodFields(
                $paymentMethod,
                $request->validated()
            );

            if (!$validation['valid']) {
                return response()->json([
                    'status' => 'error',
                    'message' => implode(', ', $validation['errors']),
                ], 400);
            }

            // Place order
            $order = $this->checkoutService->placeOrder($cart, $request->validated());

            // Load relationships for response
            $order->load(['orderItems.product', 'seller', 'buyer']);

            ActivityLogger::log(
                ActivityActions::ORDER_PLACED,
                "Order #{$order->id} placed (total {$order->total_amount})",
                $order,
                [
                    'order_id' => $order->id,
                    'total' => $order->total_amount,
                    'payment_method' => $request->payment_method,
                    'item_count' => $order->orderItems->count(),
                ],
                module: 'orders',
                userId: $user->id,
            );

            // Get payment details with URL
            $paymentData = $this->getPaymentData($order, $user);

            return response()->json([
                'status' => 'success',
                'message' => 'Order placed successfully',
                'data' => [
                    'order' => $order->api_response,
                    'order_summary' => [
                        'subtotal' => $order->subtotal,
                        'delivery_fee' => $order->delivery_fee,
                        'service_fee' => $order->service_fee,
                        'total' => $order->total_amount,
                    ],
                    'payment' => $paymentData,
                    'next_steps' => $this->getNextSteps($order, $paymentData),
                ],
            ], 201);
        } catch (\Exception $e) {
            Log::error('Order placement error', [
                'user_id' => $request->user()->id ?? null,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to place order. Please try again.',
            ], 422);
        }
    }

    /**
     * Get available payment methods
     */
    public function paymentMethods(): JsonResponse
    {
        try {
            $methods = $this->checkoutService->getPaymentMethods();

            return response()->json([
                'status' => 'success',
                'data' => $methods,
            ]);
        } catch (\Exception $e) {
            Log::error('Payment methods error', [
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'status' => 'error',
                'message' => 'Failed to get payment methods. Please try again.',
            ], 500);
        }
    }

    /**
     * Get payment data for response with proper URLs based on payment method
     */
    private function getPaymentData(Order $order, $user): ?array
    {
        $paymentData = null;

        // Wallet payment - immediate success
        if ($order->payment_method === 'wallet' && $order->payment_status === Order::PAYMENT_STATUS_PAID) {
            $paymentData = [
                'status' => 'paid',
                'amount' => $order->total_amount,
                'method' => 'wallet',
                'message' => 'Payment successful via wallet',
                'type' => 'wallet',
            ];
        }
        // Cash on Delivery - no payment needed
        elseif ($order->payment_method === 'cash_on_delivery') {
            $paymentData = [
                'status' => 'pending',
                'amount' => $order->total_amount,
                'method' => 'cash_on_delivery',
                'message' => 'Pay when you receive your order',
                'type' => 'cash_on_delivery',
            ];
        }
        // Mobile Money, Card, Bank Transfer - need to initiate payment
        elseif (in_array($order->payment_method, ['mobile_money', 'card', 'bank_transfer'])) {
            // Generate the payment initiation URL
            // URL: /api/v1/payments/initiate
            $paymentUrl = URL::to('/api/v1/payments/initiate');

            $paymentData = [
                'status' => 'pending',
                'amount' => $order->total_amount,
                'method' => $order->payment_method,
                'reference' => $order->order_number,
                'message' => 'Complete payment to confirm your order',
                'type' => 'external',
                'payment_url' => $paymentUrl,
                'order_id' => $order->id,
                'payment_method' => $order->payment_method,
            ];
        }

        return $paymentData;
    }

    /**
     * Get next steps for the user after placing order
     */
    private function getNextSteps(Order $order, ?array $paymentData): array
    {
        $steps = [];

        // Wallet payment - already paid
        if ($order->payment_method === 'wallet' && $order->payment_status === Order::PAYMENT_STATUS_PAID) {
            $steps = [
                '✅ Your order has been confirmed and is being processed.',
                '📱 You will receive a notification when your order is ready for delivery.',
                '📍 You can track your order status in the app.',
                '📋 Order #' . $order->order_number . ' has been placed successfully.',
            ];
        }
        // Cash on Delivery
        elseif ($order->payment_method === 'cash_on_delivery') {
            $steps = [
                '✅ Your order has been placed. You will pay when you receive the delivery.',
                '📞 The seller will contact you to confirm delivery details.',
                '📍 You can track your order status in the app.',
                '📋 Order #' . $order->order_number . ' has been placed successfully.',
            ];
        }
        // Mobile Money, Card, Bank Transfer - need payment
        elseif (in_array($order->payment_method, ['mobile_money', 'card', 'bank_transfer'])) {
            $steps = [
                '💳 Complete the payment to confirm your order.',
                '📱 Tap the payment link to proceed with payment.',
                '📍 Once payment is confirmed, your order will be processed.',
                '📋 Order #' . $order->order_number . ' has been placed successfully.',
            ];
        }
        // Default
        else {
            $steps = [
                '✅ Your order has been placed.',
                '📱 You will receive a notification when your order is confirmed.',
                '📍 You can track your order status in the app.',
                '📋 Order #' . $order->order_number . ' has been placed successfully.',
            ];
        }

        return $steps;
    }
}
