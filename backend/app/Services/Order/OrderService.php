<?php
// app/Services/Order/OrderService.php

namespace App\Services\Order;

use App\Models\Cart;
use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrderService
{
    // Fees via OrderFeeCalculator (shared with checkout + admin)

    /**
     * Create order from cart
     */
    public function createOrderFromCart(Cart $cart, array $data): Order
    {
        return DB::transaction(function () use ($cart, $data) {
            $user = $cart->user;
            $items = $cart->items;

            // Group items by seller
            $sellerGroups = $items->groupBy(function ($item) {
                return $item->product->seller_id;
            });

            // Wallet pre-check: cover the FULL multi-seller total before
            // creating any order so we never partially debit.
            $isWallet = ($data['payment_method'] ?? null) === Order::PAYMENT_METHOD_WALLET
                || ($data['payment_method'] ?? null) === 'wallet';
            if ($isWallet) {
                $grandTotal = 0.0;
                foreach ($sellerGroups as $sellerItems) {
                    $preLines = $sellerItems->map(fn ($item) => [
                        'quantity' => $item->quantity,
                        'price' => $item->price,
                    ]);
                    $preSellerId = $sellerItems->first()?->product?->seller_id;
                    $preFees = OrderFeeCalculator::calculate($preLines, $preSellerId ? (int) $preSellerId : null);
                    $grandTotal += (float) $preFees['total_amount'];
                }

                $wallet = app(\App\Services\Wallet\WalletService::class)->getOrCreateWallet($user);
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

            // Create order for each seller group
            $orders = [];
            foreach ($sellerGroups as $sellerId => $sellerItems) {
                $seller = User::find($sellerId, ['*']);
                $order = $this->createSingleOrder($user, $seller, $sellerItems, $data);
                $orders[] = $order;
            }

            // If multiple orders, return the first one for now
            // In a real implementation, you might want to handle multiple orders differently
            return $orders[0];
        });
    }

    /**
     * Create a single order
     */
    private function createSingleOrder($buyer, $seller, $items, $data): Order
    {
        $lines = $items->map(fn ($item) => [
            'quantity' => $item->quantity,
            'price' => $item->price,
        ]);
        $fees = OrderFeeCalculator::calculate($lines, $seller?->id);

        $order = Order::create([
            'buyer_id' => $buyer->id,
            'seller_id' => $seller->id,
            'product_id' => $items->first()->product_id, // Primary product
            'order_number' => $this->generateOrderNumber(),
            'quantity' => $items->sum('quantity'),
            'unit_price' => $items->first()->price,
            'subtotal' => $fees['subtotal'],
            'delivery_fee' => $fees['delivery_fee'],
            'service_fee' => $fees['service_fee'],
            'total_amount' => $fees['total_amount'],
            'commission_amount' => $fees['commission_amount'],
            'seller_earnings' => $fees['seller_earnings'],
            'platform_fee' => $fees['platform_fee'],
            'status' => Order::STATUS_PENDING,
            'payment_status' => Order::PAYMENT_STATUS_PENDING,
            'payment_method' => $data['payment_method'] ?? null,
            'delivery_address' => $data['delivery_address'],
            'delivery_coordinates' => $data['delivery_coordinates'] ?? null,
            'special_instructions' => $data['special_instructions'] ?? null,
            'delivery_scheduled_at' => $data['delivery_scheduled_at'] ?? null,
        ]);

        // Log order creation
        OrderTimeline::log(
            $order,
            Order::STATUS_PENDING,
            'Order created successfully',
            [
                'subtotal' => $fees['subtotal'],
                'total' => $fees['total_amount'],
                'delivery_fee' => $fees['delivery_fee'],
                'service_fee' => $fees['service_fee'],
            ]
        );

        // Reduce product stock
        foreach ($items as $item) {
            $product = $item->product;
            $product->decrement('stock_quantity', $item->quantity);
            $product->increment('orders_count');
        }

        // Wallet purchase: the wallet IS deducted here, so auto mark the
        // order paid + confirmed. Failure aborts the whole transaction
        // (rollback) — never a deducted wallet with a pending order.
        if (($order->payment_method ?? null) === Order::PAYMENT_METHOD_WALLET
            || ($order->payment_method ?? null) === 'wallet') {
            $paymentResult = app(\App\Services\Payment\PaymentService::class)->processPayment(
                $order,
                'wallet',
                ['user_id' => $buyer->id]
            );

            if (!($paymentResult['success'] ?? false)) {
                throw new \Exception('Wallet payment failed: ' . ($paymentResult['message'] ?? 'Unknown error'));
            }

            // PaymentService already set paid+confirmed on a fresh write;
            // re-assert on a refreshed instance for callers holding $order.
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
        }

        // Notify seller (realtime) + buyer/seller confirmation (in-app/push/email)
        event(new \App\Events\OrderCreated($order));
        dispatch(new \App\Jobs\Order\SendOrderConfirmation($order));

        return $order;
    }

    /**
     * Canonical SD-YEAR-RANDOM6ALPHANUM (see Order::generateNumber).
     */
    private function generateOrderNumber(): string
    {
        return Order::generateNumber();
    }

    /**
     * Validate cart items
     */
    public function validateCartItems(Cart $cart): array
    {
        $errors = [];

        foreach ($cart->items as $item) {
            $product = $item->product;

            if (!$product->is_available) {
                $errors[] = "{$product->name} is no longer available";
            }

            if ($product->stock_quantity < $item->quantity) {
                $errors[] = "Not enough stock for {$product->name}. Available: {$product->stock_quantity}";
            }
        }

        return $errors;
    }
}
