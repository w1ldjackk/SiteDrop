<?php
// app/Services/Checkout/CheckoutService.php

namespace App\Services\Checkout;

use App\Models\Cart;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderTimeline;
use App\Models\User;
use App\Models\Product;
use App\Services\Order\OrderFeeCalculator;
use App\Services\Payment\PaymentService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

class CheckoutService
{
    protected PaymentService $paymentService;

    public function __construct(PaymentService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    /**
     * Validate cart before checkout
     */
    public function validateCart(Cart $cart): array
    {
        $errors = [];
        $items = $cart->items()->with('product')->get();

        if ($items->isEmpty()) {
            return ['valid' => false, 'errors' => ['Cart is empty']];
        }

        foreach ($items as $item) {
            $product = $item->product;

            if (!$product) {
                $errors[] = "Product not found";
                continue;
            }

            if (!$product->is_available) {
                $errors[] = "{$product->name} is currently not available";
            }

            if ($product->stock_quantity < $item->quantity) {
                $errors[] = "Not enough stock for {$product->name}. Available: {$product->stock_quantity}";
            }

            if ((float) $product->price_per_unit !== (float) $item->price) {
                $errors[] = "Price for {$product->name} has changed. Please review your cart.";
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
        ];
    }

    /**
     * Calculate order summary
     */
    public function calculateSummary(Cart $cart): array
    {
        $items = $cart->items()->with('product')->get();

        $subtotal = 0;
        $cartItems = [];

        foreach ($items as $item) {
            $lineTotal = $item->quantity * $item->price;
            $subtotal += $lineTotal;

            $cartItems[] = [
                'id' => $item->id,
                'product_id' => $item->product_id,
                'name' => $item->product->name,
                'quantity' => $item->quantity,
                'price' => $item->price,
                'line_total' => $lineTotal,
                'unit' => $item->product->unit,
                'product_image' => $this->getProductImage($item->product),
            ];
        }

        $fees = OrderFeeCalculator::calculate($subtotal);

        return [
            'items' => $cartItems,
            'subtotal' => $fees['subtotal'],
            'delivery_fee' => $fees['delivery_fee'],
            'service_fee' => $fees['service_fee'],
            'total' => $fees['total_amount'],
            'item_count' => $items->sum('quantity'),
            'currency' => 'GHS',
            // Helpful for UI transparency
            'free_delivery_threshold' => OrderFeeCalculator::FREE_DELIVERY_THRESHOLD,
            'commission_rate' => $fees['commission_rate'],
        ];
    }

    /**
     * Place order from cart
     */
    public function placeOrder(Cart $cart, array $data): Order
    {
        return DB::transaction(function () use ($cart, $data) {
            $user = $cart->user;
            $items = $cart->items()->with('product')->get();

            // Validate cart again
            $validation = $this->validateCart($cart);
            if (!$validation['valid']) {
                throw new \Exception(implode(', ', $validation['errors']));
            }

            // Group items by seller
            $sellerGroups = $items->groupBy(function ($item) {
                return $item->product->seller_id;
            });

            // Wallet pre-check: ensure the buyer can cover the FULL cart total
            // before creating any order / decrementing stock. Without this a
            // multi-seller cart could leave the first order paid+confirmed and
            // the second pending after a partial debit.
            if (($data['payment_method'] ?? null) === 'wallet') {
                $grandTotal = 0.0;
                foreach ($sellerGroups as $sellerId => $sellerItems) {
                    $seller = User::query()->whereKey($sellerId)->first();
                    if (!$seller) {
                        throw new \Exception("Seller not found for ID: {$sellerId}");
                    }
                    $preLines = $sellerItems->map(fn ($item) => [
                        'quantity' => $item->quantity,
                        'price' => $item->price,
                    ]);
                    $preFees = OrderFeeCalculator::calculate($preLines, (int) $seller->id);
                    $grandTotal += (float) $preFees['total_amount'];
                }

                $wallet = app(\App\Services\Wallet\WalletService::class)
                    ->getOrCreateWallet($user);

                if (!$wallet->is_active) {
                    throw new \Exception('This wallet is suspended. Contact support.');
                }

                if ((float) $wallet->available_balance < $grandTotal) {
                    throw new \Exception(
                        'Insufficient wallet balance. Available: GHS ' .
                        number_format((float) $wallet->available_balance, 2) .
                        ', required: GHS ' . number_format($grandTotal, 2)
                    );
                }
            }

            // Create a separate order for each seller
            $orders = [];

            foreach ($sellerGroups as $sellerId => $sellerItems) {
                $seller = User::query()->whereKey($sellerId)->first();

                if (!$seller) {
                    throw new \Exception("Seller not found for ID: {$sellerId}");
                }

                // Totals + fees for this seller group (one order per seller)
                $lines = $sellerItems->map(fn ($item) => [
                    'quantity' => $item->quantity,
                    'price' => $item->price,
                ]);
                $fees = OrderFeeCalculator::calculate($lines, (int) $seller->id);

                // Generate order number
                $orderNumber = $this->generateOrderNumber();

                // Create order
                $order = Order::create([
                    'buyer_id' => $user->id,
                    'seller_id' => $seller->id,
                    'product_id' => $sellerItems->first()->product_id, // For backward compatibility
                    'quantity' => $sellerItems->sum('quantity'), // For backward compatibility
                    'unit_price' => $sellerItems->first()->price, // For backward compatibility
                    'order_number' => $orderNumber,
                    'subtotal' => $fees['subtotal'],
                    'delivery_fee' => $fees['delivery_fee'],
                    'service_fee' => $fees['service_fee'],
                    'total_amount' => $fees['total_amount'],
                    'commission_amount' => $fees['commission_amount'],
                    'seller_earnings' => $fees['seller_earnings'],
                    'platform_fee' => $fees['platform_fee'],
                    'status' => Order::STATUS_PENDING,
                    'payment_status' => Order::PAYMENT_STATUS_PENDING,
                    'payment_method' => $data['payment_method'],
                    'delivery_address' => $data['delivery_address'],
                    'delivery_phone' => $data['delivery_phone'] ?? $user->phone ?? null,
                    'delivery_coordinates' => [
                        'lat' => $data['latitude'] ?? null,
                        'lng' => $data['longitude'] ?? null,
                    ],
                    'special_instructions' => $data['notes'] ?? null,
                    'delivery_scheduled_at' => $data['delivery_scheduled_at'] ?? null,
                    'currency' => 'GHS',
                ]);

                // Create order items
                foreach ($sellerItems as $cartItem) {
                    $product = $cartItem->product;

                    OrderItem::create([
                        'order_id' => $order->id,
                        'product_id' => $cartItem->product_id,
                        'quantity' => $cartItem->quantity,
                        'price' => $cartItem->price,
                        'subtotal' => $cartItem->quantity * $cartItem->price,
                        'variations' => $cartItem->variations ?? null,
                        'unit' => $product->unit ?? null,
                    ]);

                    // Reduce product stock
                    $product->decrement('stock_quantity', $cartItem->quantity);
                    $product->increment('orders_count');
                }

                // Create order timeline
                OrderTimeline::log(
                    $order,
                    Order::STATUS_PENDING,
                    'Order placed successfully',
                    [
                        'total_amount' => $fees['total_amount'],
                        'subtotal' => $fees['subtotal'],
                        'delivery_fee' => $fees['delivery_fee'],
                        'service_fee' => $fees['service_fee'],
                        'commission_amount' => $fees['commission_amount'],
                        'seller_earnings' => $fees['seller_earnings'],
                    ]
                );

                // Create delivery row now (pending) so Bolt-style dispatch
                // can fire the moment the seller marks the order ready.
                // Never breaks checkout — delivery creation is best-effort.
                try {
                    app(\App\Services\Delivery\DeliveryService::class)
                        ->createDelivery($order->fresh());
                } catch (\Throwable $e) {
                    Log::warning('Auto-create delivery failed', [
                        'order_id' => $order->id,
                        'error' => $e->getMessage(),
                    ]);
                }

                // Handle payment based on method
                $this->handlePayment($order, $data);

                // Dispatch events
                event(new \App\Events\OrderCreated($order));

                // Send notifications (dispatch jobs)
                $this->sendOrderNotifications($order);

                $orders[] = $order;
            }

            // Mark cart as converted
            $cart->update(['status' => 'converted']);

            // Return the first order (or all orders for multi-vendor)
            // For MVP, return the first order
            return $orders[0];
        });
    }

    /**
     * Handle payment processing
     */
    private function handlePayment(Order $order, array $data): void
    {
        $paymentMethod = $data['payment_method'];

        if ($paymentMethod === 'wallet') {
            // Process wallet payment immediately. The wallet IS deducted here,
            // so the order must end up auto-paid + confirmed. Any failure must
            // abort checkout (rollback) — never leave a deducted wallet with a
            // pending order, or a pending order masquerading as success.
            try {
                $paymentResult = $this->paymentService->processPayment(
                    $order,
                    'wallet',
                    ['user_id' => $order->buyer_id]
                );

                if (!($paymentResult['success'] ?? false)) {
                    throw new \Exception($paymentResult['message'] ?? 'Wallet payment failed. No amount was deducted.');
                }

                // PaymentService already debited the wallet and marked the
                // order paid+confirmed. Re-assert the final state on a fresh
                // instance (the $order model may be stale) so callers that
                // inspect the returned model see paid/confirmed.
                $order->refresh();
                if (
                    $order->payment_status !== Order::PAYMENT_STATUS_PAID ||
                    $order->status !== Order::STATUS_CONFIRMED
                ) {
                    $order->update([
                        'payment_status' => Order::PAYMENT_STATUS_PAID,
                        'status' => Order::STATUS_CONFIRMED,
                        'processed_at' => $order->processed_at ?? now(),
                    ]);
                    $order->refresh();
                }

                if (!$order->timeline()->where('status', Order::STATUS_CONFIRMED)->exists()) {
                    OrderTimeline::log(
                        $order,
                        Order::STATUS_CONFIRMED,
                        'Payment confirmed via wallet',
                        ['amount' => $order->total_amount]
                    );
                }
            } catch (\Exception $e) {
                Log::error('Wallet payment failed for order', [
                    'order_id' => $order->id,
                    'error' => $e->getMessage()
                ]);
                // Re-throw so the outer DB::transaction() rolls back the
                // order, stock decrement, delivery row and cart conversion.
                throw new \Exception('Wallet payment failed: ' . $e->getMessage());
            }
        } elseif (in_array($paymentMethod, ['cash_on_delivery', 'cash'])) {
            // Cash on delivery - no immediate payment
            $order->update([
                'payment_status' => Order::PAYMENT_STATUS_PENDING,
            ]);

            OrderTimeline::log(
                $order,
                Order::STATUS_PENDING,
                'Cash on delivery selected'
            );
        } else {
            // Mobile Money, Card, Bank Transfer - pending payment
            $order->update([
                'payment_status' => Order::PAYMENT_STATUS_PENDING,
            ]);

            OrderTimeline::log(
                $order,
                Order::STATUS_PENDING,
                "Payment initiated via {$paymentMethod}. Waiting for payment confirmation."
            );
        }
    }

    /**
     * Send order notifications
     */
    private function sendOrderNotifications(Order $order): void
    {
        try {
            // Send confirmation to buyer
            dispatch(new \App\Jobs\Order\SendOrderConfirmation($order));

            // Notify seller about new order
            dispatch(new \App\Jobs\Notification\SendSellerNewOrderNotification($order));

            // Send push notification to buyer if FCM token exists
            if ($order->buyer && $order->buyer->fcm_token) {
                dispatch(new \App\Jobs\Notification\SendPushNotification(
                    $order->buyer->fcm_token,
                    'Order Confirmed',
                    "Your order #{$order->order_number} has been placed successfully!",
                    ['type' => 'order', 'order_id' => $order->id]
                ));
            }
        } catch (\Exception $e) {
            Log::error('Failed to send order notifications', [
                'order_id' => $order->id,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * Get product image
     */
    private function getProductImage($product): ?string
    {
        if (!$product) {
            return null;
        }

        $images = $product->images;

        if (is_array($images) && count($images) > 0) {
            return $images[0];
        } elseif (is_string($images)) {
            $decoded = json_decode($images, true);
            if (is_array($decoded) && count($decoded) > 0) {
                return $decoded[0];
            }
            return $images;
        }

        return null;
    }

    /**
     * @deprecated use OrderFeeCalculator::deliveryFeeForSubtotal
     */
    private function calculateDeliveryFee(float $subtotal): float
    {
        return OrderFeeCalculator::deliveryFeeForSubtotal($subtotal);
    }

    /**
     * @deprecated use OrderFeeCalculator::serviceFeeForSubtotal
     */
    private function calculateServiceFee(float $subtotal): float
    {
        return OrderFeeCalculator::serviceFeeForSubtotal($subtotal);
    }

    /**
     * Canonical SD-YEAR-RANDOM6ALPHANUM (see Order::generateNumber).
     */
    private function generateOrderNumber(): string
    {
        return Order::generateNumber();
    }

    /**
     * Get available payment methods
     */
    public function getPaymentMethods(): array
    {
        return [
            [
                'id' => 'mobile_money',
                'name' => 'Mobile Money',
                'icon' => 'phone_android',
                'subtitle' => 'MTN, Vodafone, AirtelTigo',
                'is_active' => true,
                'is_instant' => true,
                'fields' => ['phone_number', 'network'],
            ],
            [
                'id' => 'card',
                'name' => 'Card Payment',
                'icon' => 'payment',
                'subtitle' => 'Visa, Mastercard, Amex',
                'is_active' => true,
                'is_instant' => true,
                'fields' => ['card_number', 'expiry', 'cvv'],
            ],
            [
                'id' => 'bank_transfer',
                'name' => 'Bank Transfer',
                'icon' => 'account_balance',
                'subtitle' => 'Direct bank transfer',
                'is_active' => true,
                'is_instant' => false,
                'fields' => ['bank_name', 'account_number'],
            ],
            [
                'id' => 'wallet',
                'name' => 'Wallet Balance',
                'icon' => 'wallet',
                'subtitle' => 'Pay using your wallet',
                'is_active' => true,
                'is_instant' => true,
                'fields' => [],
            ],
            [
                'id' => 'cash_on_delivery',
                'name' => 'Cash on Delivery',
                'icon' => 'money',
                'subtitle' => 'Pay when you receive',
                'is_active' => true,
                'is_instant' => false,
                'fields' => [],
            ],
        ];
    }

    /**
     * Check if a payment method is available
     */
    public function isPaymentMethodAvailable(string $method): bool
    {
        $methods = $this->getPaymentMethods();
        foreach ($methods as $availableMethod) {
            if ($availableMethod['id'] === $method) {
                return $availableMethod['is_active'];
            }
        }
        return false;
    }

    /**
     * Validate payment method fields
     */
    public function validatePaymentMethodFields(string $method, array $data): array
    {
        $errors = [];
        $methods = $this->getPaymentMethods();

        foreach ($methods as $availableMethod) {
            if ($availableMethod['id'] === $method) {
                $fields = $availableMethod['fields'] ?? [];
                foreach ($fields as $field) {
                    if (empty($data[$field])) {
                        $errors[] = "{$field} is required for {$method}";
                    }
                }
                break;
            }
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
        ];
    }
}
