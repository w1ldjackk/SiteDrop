<?php
// database/seeders/OrderAndPaymentSeeder.php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use App\Models\Product;
use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Delivery;
use App\Models\Payment;
use App\Models\PaymentMethod;
use App\Models\Review;
use App\Models\Wallet;
use App\Models\WalletTransaction;
use App\Models\Notification;
use App\Models\Truck;
use Illuminate\Support\Str;

class OrderAndPaymentSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🛒 Seeding orders, payments, deliveries, and related data...');

        // Get users
        $buyer = User::where('email', 'buyer@sitedrop.gh')->first();
        $seller = User::where('email', 'seller@sitedrop.gh')->first();
        $driver = User::where('email', 'driver@sitedrop.gh')->first();
        $admin = User::where('email', 'admin@sitedrop.gh')->first();

        if (!$buyer || !$seller) {
            $this->command->error('❌ Buyer or Seller not found. Please run PermissionSeederService first.');
            return;
        }

        // Get products for the seller
        $products = Product::where('seller_id', $seller->id)->get();
        if ($products->isEmpty()) {
            $this->command->error('❌ No products found. Please run ProductSeeder first.');
            return;
        }

        // Get trucks
        $truck = Truck::where('driver_id', $driver ? $driver->id : null)->first();
        if (!$truck) {
            $truck = Truck::first();
        }

        // Ensure wallets exist for users
        $this->ensureWallets($buyer, $seller, $driver, $admin);

        // ====================== 1. CREATE CARTS ======================
        $this->command->info('   - Creating carts...');
        $carts = $this->createCarts($buyer, $products);
        $this->command->info('   - Carts created: ' . count($carts));

        // ====================== 2. CREATE ORDERS ======================
        $this->command->info('   - Creating orders...');
        $orders = $this->createOrders($buyer, $seller, $products);
        $this->command->info('   - Orders created: ' . count($orders));

        // ====================== 3. CREATE ORDER TIMELINES ======================
        $this->command->info('   - Creating order timelines...');
        $this->createOrderTimelines($orders, $admin);
        $this->command->info('   - Order timelines created');

        // ====================== 4. CREATE PAYMENTS ======================
        $this->command->info('   - Creating payments...');
        $payments = $this->createPayments($orders, $buyer);
        $this->command->info('   - Payments created: ' . count($payments));

        // ====================== 5. CREATE PAYMENT METHODS ======================
        $this->command->info('   - Creating payment methods...');
        $this->createPaymentMethods($buyer);
        $this->command->info('   - Payment methods created');

        // ====================== 6. CREATE DELIVERIES ======================
        $this->command->info('   - Creating deliveries...');
        $deliveries = $this->createDeliveries($orders, $driver, $truck);
        $this->command->info('   - Deliveries created: ' . count($deliveries));

        // ====================== 7. CREATE REVIEWS ======================
        $this->command->info('   - Creating reviews...');
        $reviews = $this->createReviews($orders, $buyer, $seller);
        $this->command->info('   - Reviews created: ' . count($reviews));

        // ====================== 8. CREATE NOTIFICATIONS ======================
        $this->command->info('   - Creating notifications...');
        $this->createNotifications($buyer, $seller, $driver, $orders);
        $this->command->info('   - Notifications created');

        // ====================== 9. CREATE WALLET TRANSACTIONS ======================
        $this->command->info('   - Creating wallet transactions...');
        $this->createWalletTransactions($buyer, $seller, $driver);
        $this->command->info('   - Wallet transactions created');

        $this->command->info('✅ All order-related data seeded successfully!');
    }

    /**
     * Ensure wallets exist for all users
     */
    private function ensureWallets(...$users): void
    {
        foreach ($users as $user) {
            if ($user && !$user->wallet) {
                $user->wallet()->create([
                    'balance' => 0,
                    'currency' => 'GHS',
                ]);
            }
        }
    }

    /**
     * Create carts
     */
    private function createCarts($buyer, $products): array
    {
        $carts = [];

        // Cart 1: Active cart with items
        $cart1 = Cart::create([
            'user_id' => $buyer->id,
            'status' => 'active',
            'expires_at' => now()->addDays(7),
        ]);

        // Add items to cart
        $product1 = $products->first();
        if ($product1) {
            CartItem::create([
                'cart_id' => $cart1->id,
                'product_id' => $product1->id,
                'quantity' => 2,
                'price' => $product1->price_per_unit,
                'variations' => null,
            ]);
        }

        if ($products->count() > 1) {
            $product2 = $products->skip(1)->first();
            CartItem::create([
                'cart_id' => $cart1->id,
                'product_id' => $product2->id,
                'quantity' => 1,
                'price' => $product2->price_per_unit,
                'variations' => null,
            ]);
        }

        $carts[] = $cart1;

        // Cart 2: Converted cart (already ordered)
        $cart2 = Cart::create([
            'user_id' => $buyer->id,
            'status' => 'converted',
            'expires_at' => now()->subDays(10),
        ]);

        $product3 = $products->skip(2)->first() ?? $products->first();
        CartItem::create([
            'cart_id' => $cart2->id,
            'product_id' => $product3->id,
            'quantity' => 3,
            'price' => $product3->price_per_unit,
            'variations' => null,
        ]);

        $carts[] = $cart2;

        return $carts;
    }

    /**
     * Create orders
     */
    private function createOrders($buyer, $seller, $products): array
    {
        $orders = [];
        $statuses = [
            Order::STATUS_PENDING,
            Order::STATUS_CONFIRMED,
            Order::STATUS_PROCESSING,
            Order::STATUS_READY_FOR_DELIVERY,
            Order::STATUS_IN_TRANSIT,
            Order::STATUS_DELIVERED,
            Order::STATUS_COMPLETED,
            Order::STATUS_CANCELLED,
        ];

        $product = $products->first();
        if (!$product) return $orders;

        // Create 8 orders with different statuses
        for ($i = 0; $i < 8; $i++) {
            $quantity = rand(1, 5);
            $unitPrice = $product->price_per_unit;
            $subtotal = $quantity * $unitPrice;
            $deliveryFee = 50.00 + rand(0, 50);
            $serviceFee = $subtotal * 0.10;
            $total = $subtotal + $deliveryFee + $serviceFee;

            $status = $statuses[$i % count($statuses)];
            $paymentStatus = in_array($status, [
                Order::STATUS_PENDING,
                Order::STATUS_CANCELLED,
            ]) ? Order::PAYMENT_STATUS_PENDING : Order::PAYMENT_STATUS_PAID;

            // Generate delivery coordinates
            $lat = 5.6000 + (rand(0, 100) / 1000);
            $lng = -0.1900 + (rand(0, 100) / 1000);

            $order = Order::create([
                'buyer_id' => $buyer->id,
                'seller_id' => $seller->id,
                'product_id' => $product->id,
                'order_number' => $this->generateOrderNumber(),
                'quantity' => $quantity,
                'unit_price' => $unitPrice,
                'subtotal' => $subtotal,
                'delivery_fee' => $deliveryFee,
                'service_fee' => $serviceFee,
                'total_amount' => $total,
                'status' => $status,
                'payment_status' => $paymentStatus,
                'payment_method' => ['mobile_money', 'wallet', 'card', 'bank_transfer'][rand(0, 3)],
                'delivery_address' => "123 Construction Site, Accra, Ghana",
                'delivery_coordinates' => ['lat' => $lat, 'lng' => $lng],
                'special_instructions' => rand(0, 1) ? 'Please call before delivery.' : null,
                'delivery_scheduled_at' => $status !== Order::STATUS_PENDING ? now()->addDays(rand(1, 5)) : null,
                'delivered_at' => in_array($status, [Order::STATUS_DELIVERED, Order::STATUS_COMPLETED]) ? now()->subDays(rand(1, 3)) : null,
                'cancellation_reason' => $status === Order::STATUS_CANCELLED ? 'Changed my mind' : null,
                'discount_amount' => rand(0, 1) ? 20.00 : 0,
                'tax_amount' => 0,
                'currency' => 'GHS',
            ]);

            $orders[] = $order;
        }

        return $orders;
    }

    /**
     * Create order timelines
     */
    private function createOrderTimelines($orders, $admin): void
    {
        $timelineMessages = [
            'Order created successfully',
            'Order confirmed by seller',
            'Payment confirmed',
            'Order is being processed',
            'Order ready for delivery',
            'Driver assigned',
            'Order picked up',
            'Order in transit',
            'Order delivered',
            'Order completed',
        ];

        foreach ($orders as $index => $order) {
            // Create initial timeline
            OrderTimeline::log(
                $order,
                $order->status,
                $timelineMessages[0],
                ['total_amount' => $order->total_amount]
            );

            // Add more timeline entries based on status
            if ($order->status !== Order::STATUS_PENDING) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_CONFIRMED,
                    $timelineMessages[1],
                    ['confirmed_by' => $admin ? $admin->id : 1]
                );
            }

            if (in_array($order->status, [
                Order::STATUS_PROCESSING,
                Order::STATUS_READY_FOR_DELIVERY,
                Order::STATUS_IN_TRANSIT,
                Order::STATUS_DELIVERED,
                Order::STATUS_COMPLETED,
            ])) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_PROCESSING,
                    $timelineMessages[3],
                    []
                );
            }

            if (in_array($order->status, [
                Order::STATUS_READY_FOR_DELIVERY,
                Order::STATUS_IN_TRANSIT,
                Order::STATUS_DELIVERED,
                Order::STATUS_COMPLETED,
            ])) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_READY_FOR_DELIVERY,
                    $timelineMessages[4],
                    []
                );
            }

            if (in_array($order->status, [
                Order::STATUS_IN_TRANSIT,
                Order::STATUS_DELIVERED,
                Order::STATUS_COMPLETED,
            ])) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_IN_TRANSIT,
                    $timelineMessages[7],
                    ['driver_id' => 3]
                );
            }

            if (in_array($order->status, [
                Order::STATUS_DELIVERED,
                Order::STATUS_COMPLETED,
            ])) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_DELIVERED,
                    $timelineMessages[8],
                    ['delivered_at' => now()->toIso8601String()]
                );
            }

            if ($order->status === Order::STATUS_COMPLETED) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_COMPLETED,
                    $timelineMessages[9],
                    ['completed_at' => now()->toIso8601String()]
                );
            }

            if ($order->status === Order::STATUS_CANCELLED) {
                OrderTimeline::log(
                    $order,
                    Order::STATUS_CANCELLED,
                    'Order cancelled: ' . ($order->cancellation_reason ?? 'No reason provided'),
                    ['cancelled_by' => $order->buyer_id]
                );
            }
        }
    }

    /**
     * Create payments
     */
    private function createPayments($orders, $buyer): array
    {
        $payments = [];
        $paymentStatuses = [
            Payment::STATUS_SUCCESS,
            Payment::STATUS_PENDING,
            Payment::STATUS_SUCCESS,
            Payment::STATUS_SUCCESS,
            Payment::STATUS_FAILED,
            Payment::STATUS_SUCCESS,
            Payment::STATUS_REFUNDED,
            Payment::STATUS_SUCCESS,
        ];

        foreach ($orders as $index => $order) {
            // Only create payment for orders that are not pending
            if ($order->status === Order::STATUS_PENDING && rand(0, 1) === 0) {
                continue;
            }

            $payment = Payment::create([
                'order_id' => $order->id,
                'user_id' => $buyer->id,
                'payment_reference' => 'PAY-' . date('Y') . '-' . strtoupper(Str::random(10)),
                'transaction_id' => 'TXN-' . date('Y') . '-' . strtoupper(Str::random(10)),
                'amount' => $order->total_amount,
                'currency' => 'GHS',
                'payment_method' => $order->payment_method ?? 'mobile_money',
                'payment_channel' => ['MTN', 'Vodafone', 'AirtelTigo', 'GCB'][rand(0, 3)],
                'status' => $paymentStatuses[$index % count($paymentStatuses)],
                'metadata' => ['ip_address' => '127.0.0.1', 'user_agent' => 'Seeder'],
                'paid_at' => in_array($paymentStatuses[$index % count($paymentStatuses)], [
                    Payment::STATUS_SUCCESS,
                    Payment::STATUS_REFUNDED,
                ]) ? now()->subHours(rand(1, 48)) : null,
                'refunded_at' => $paymentStatuses[$index % count($paymentStatuses)] === Payment::STATUS_REFUNDED ? now()->subHours(rand(1, 24)) : null,
                'refund_amount' => $paymentStatuses[$index % count($paymentStatuses)] === Payment::STATUS_REFUNDED ? $order->total_amount : 0,
                'refund_reason' => $paymentStatuses[$index % count($paymentStatuses)] === Payment::STATUS_REFUNDED ? 'Customer requested refund' : null,
                'gateway_response' => ['status' => 'success', 'message' => 'Payment processed successfully'],
                'ip_address' => '127.0.0.1',
                'user_agent' => 'Seeder',
            ]);

            $payments[] = $payment;

            // Update order payment status
            if ($payment->status === Payment::STATUS_SUCCESS) {
                $order->update(['payment_status' => Order::PAYMENT_STATUS_PAID]);
            } elseif ($payment->status === Payment::STATUS_REFUNDED) {
                $order->update(['payment_status' => Order::PAYMENT_STATUS_REFUNDED]);
            } elseif ($payment->status === Payment::STATUS_FAILED) {
                $order->update(['payment_status' => Order::PAYMENT_STATUS_FAILED]);
            }
        }

        return $payments;
    }

    /**
     * Create payment methods
     */
    private function createPaymentMethods($buyer): void
    {
        $paymentMethods = [
            [
                'user_id' => $buyer->id,
                'type' => 'mobile_money',
                'provider' => 'MTN',
                'account_name' => $buyer->name,
                'phone_number' => '233501234571',
                'is_default' => true,
                'is_verified' => true,
                'verification_data' => ['verified_at' => now()->toIso8601String()],
            ],
            [
                'user_id' => $buyer->id,
                'type' => 'card',
                'provider' => 'Visa',
                'account_name' => $buyer->name,
                'card_last_four' => '4242',
                'card_expiry' => '2026-12-01',
                'is_default' => false,
                'is_verified' => true,
                'verification_data' => ['verified_at' => now()->toIso8601String()],
            ],
            [
                'user_id' => $buyer->id,
                'type' => 'bank',
                'provider' => 'GCB Bank',
                'account_name' => $buyer->name,
                'account_number' => '1234567890',
                'bank_name' => 'GCB Bank',
                'is_default' => false,
                'is_verified' => false,
            ],
        ];

        foreach ($paymentMethods as $method) {
            PaymentMethod::create($method);
        }
    }

    /**
     * Create deliveries
     */
    private function createDeliveries($orders, $driver, $truck): array
    {
        $deliveries = [];
        $statuses = [
            Delivery::STATUS_COMPLETED,
            Delivery::STATUS_COMPLETED,
            Delivery::STATUS_IN_TRANSIT,
            Delivery::STATUS_PENDING,
            Delivery::STATUS_ASSIGNED,
            Delivery::STATUS_ACCEPTED,
            Delivery::STATUS_PICKED_UP,
            Delivery::STATUS_COMPLETED,
        ];

        foreach ($orders as $index => $order) {
            // Skip orders that are cancelled
            if ($order->status === Order::STATUS_CANCELLED) {
                continue;
            }

            $status = $statuses[$index % count($statuses)];

            // Only create delivery if order is not pending
            if ($order->status === Order::STATUS_PENDING && rand(0, 1) === 0) {
                continue;
            }

            $delivery = Delivery::create([
                'order_id' => $order->id,
                'driver_id' => $driver ? $driver->id : null,
                'tracking_number' => 'TRK-' . date('Y') . '-' . strtoupper(Str::random(8)),
                'status' => $status,
                'current_location' => ['lat' => 5.6037 + (rand(0, 100) / 1000), 'lng' => -0.1870 + (rand(0, 100) / 1000)],
                'picked_up_at' => in_array($status, [
                    Delivery::STATUS_PICKED_UP,
                    Delivery::STATUS_IN_TRANSIT,
                    Delivery::STATUS_ARRIVED,
                    Delivery::STATUS_COMPLETED,
                ]) ? now()->subHours(rand(1, 5)) : null,
                'estimated_arrival' => now()->addHours(rand(1, 3)),
                'actual_arrival' => $status === Delivery::STATUS_COMPLETED ? now()->subMinutes(rand(1, 60)) : null,
                'delivery_notes' => rand(0, 1) ? 'Please call on arrival.' : null,
                'proof_images' => $status === Delivery::STATUS_COMPLETED ? ['delivery_proof.jpg'] : null,
                'distance_km' => rand(10, 50) + rand(0, 99) / 100,
                'estimated_duration' => rand(30, 120),
                'delivery_fee' => $order->delivery_fee,
                'assigned_at' => in_array($status, [
                    Delivery::STATUS_ASSIGNED,
                    Delivery::STATUS_ACCEPTED,
                    Delivery::STATUS_PICKED_UP,
                    Delivery::STATUS_IN_TRANSIT,
                    Delivery::STATUS_ARRIVED,
                    Delivery::STATUS_COMPLETED,
                ]) ? now()->subHours(rand(1, 6)) : null,
                'accepted_at' => in_array($status, [
                    Delivery::STATUS_ACCEPTED,
                    Delivery::STATUS_PICKED_UP,
                    Delivery::STATUS_IN_TRANSIT,
                    Delivery::STATUS_ARRIVED,
                    Delivery::STATUS_COMPLETED,
                ]) ? now()->subHours(rand(1, 5)) : null,
                'started_at' => in_array($status, [
                    Delivery::STATUS_IN_TRANSIT,
                    Delivery::STATUS_ARRIVED,
                    Delivery::STATUS_COMPLETED,
                ]) ? now()->subHours(rand(1, 4)) : null,
                'completed_at' => $status === Delivery::STATUS_COMPLETED ? now()->subMinutes(rand(1, 60)) : null,
                'customer_signature' => $status === Delivery::STATUS_COMPLETED ? base64_encode('signature_data') : null,
                'delivery_rating' => $status === Delivery::STATUS_COMPLETED ? rand(4, 5) : null,
                'delivery_comment' => $status === Delivery::STATUS_COMPLETED ? 'Great delivery service!' : null,
                'vehicle_id' => $truck ? $truck->id : null, // Use vehicle_id, not truck_id
                'dispatch_notes' => rand(0, 1) ? 'Handle with care.' : null,
                'delivery_window_start' => now()->addHours(rand(1, 2)),
                'delivery_window_end' => now()->addHours(rand(3, 5)),
            ]);

            $deliveries[] = $delivery;

            // Update order status if delivery is completed
            if ($status === Delivery::STATUS_COMPLETED) {
                $order->update(['status' => Order::STATUS_DELIVERED]);
            }
        }

        return $deliveries;
    }

    /**
     * Create reviews
     */
    private function createReviews($orders, $buyer, $seller): array
    {
        $reviews = [];

        // Only create reviews for completed deliveries
        $completedOrders = Order::whereIn('status', [
            Order::STATUS_DELIVERED,
            Order::STATUS_COMPLETED,
        ])->take(3)->get();

        $reviewTypes = [
            Review::TYPE_BUYER_TO_SELLER,
            Review::TYPE_BUYER_TO_PRODUCT,
            Review::TYPE_SELLER_TO_BUYER,
        ];

        foreach ($completedOrders as $order) {
            $type = $reviewTypes[rand(0, 2)];

            // Determine reviewer and reviewee based on type
            $reviewerId = $buyer->id;
            $revieweeId = $seller->id;

            if ($type === Review::TYPE_SELLER_TO_BUYER) {
                $reviewerId = $seller->id;
                $revieweeId = $buyer->id;
            }

            $review = Review::create([
                'order_id' => $order->id,
                'reviewer_id' => $reviewerId,
                'reviewee_id' => $revieweeId,
                'product_id' => $order->product_id,
                'rating' => rand(3, 5),
                'comment' => $this->getRandomReviewComment($type),
                'images' => rand(0, 1) ? ['review_image.jpg'] : null,
                'type' => $type,
                'is_verified_purchase' => true,
                'status' => Review::STATUS_PUBLISHED,
                'helpful_count' => rand(0, 5),
                'reported_count' => 0,
            ]);

            $reviews[] = $review;

            // Update product average rating
            $product = $order->product;
            if ($product) {
                $avgRating = Review::where('product_id', $product->id)->avg('rating') ?? 0;
                $product->update(['avg_rating' => round($avgRating, 2)]);
            }
        }

        return $reviews;
    }

    /**
     * Create notifications
     */
    private function createNotifications($buyer, $seller, $driver, $orders): void
    {
        $notificationTypes = [
            Notification::TYPE_ORDER,
            Notification::TYPE_PAYMENT,
            Notification::TYPE_DELIVERY,
            Notification::TYPE_SYSTEM,
        ];

        $users = array_filter([$buyer, $seller, $driver]);

        foreach ($users as $user) {
            if (!$user) continue;

            // Create 3-5 notifications per user
            $count = rand(3, 5);
            for ($i = 0; $i < $count; $i++) {
                $type = $notificationTypes[rand(0, 3)];
                $order = $orders[$i % count($orders)] ?? null;

                $title = $this->getNotificationTitle($type);
                $body = $this->getNotificationBody($type, $order);

                Notification::create([
                    'user_id' => $user->id,
                    'type' => $type,
                    'title' => $title,
                    'body' => $body,
                    'data' => $order ? ['order_id' => $order->id] : null,
                    'action_url' => $order ? '/orders/' . $order->id : null,
                    'image_url' => null,
                    'read_at' => rand(0, 1) ? now()->subHours(rand(1, 24)) : null,
                    'sent_at' => now()->subHours(rand(1, 48)),
                    'delivery_status' => ['pending', 'sent', 'delivered', 'failed'][rand(0, 3)],
                    'channel' => ['in_app', 'push', 'email', 'sms'][rand(0, 3)],
                    'priority' => ['high', 'normal', 'low'][rand(0, 2)],
                    'expires_at' => now()->addDays(7),
                ]);
            }
        }
    }

    /**
     * Create wallet transactions
     */
    private function createWalletTransactions($buyer, $seller, $driver): void
    {
        $transactionTypes = ['credit', 'debit', 'credit', 'debit', 'credit'];
        $users = array_filter([$buyer, $seller, $driver]);

        foreach ($users as $user) {
            if (!$user) continue;

            $wallet = $user->wallet;
            if (!$wallet) continue;

            $balance = 0;

            // Create 3-5 transactions per user
            $count = rand(3, 5);
            for ($i = 0; $i < $count; $i++) {
                $type = $transactionTypes[$i % count($transactionTypes)];
                $amount = rand(50, 500) + rand(0, 99) / 100;

                if ($type === 'debit' && $balance < $amount) {
                    $type = 'credit';
                }

                $balance = $type === 'credit' ? $balance + $amount : $balance - $amount;

                WalletTransaction::create([
                    'wallet_id' => $wallet->id,
                    'user_id' => $user->id,
                    'type' => $type,
                    'amount' => $amount,
                    'description' => $this->getTransactionDescription($type, $user->role),
                    'reference' => 'TXN-' . date('Y') . '-' . strtoupper(Str::random(8)),
                    'balance_after' => $balance,
                    'metadata' => ['ip_address' => '127.0.0.1'],
                    'status' => 'completed',
                ]);
            }

            // Update wallet balance
            $wallet->update(['balance' => $balance]);
        }
    }

    // ====================== Helper Methods ======================

    private function generateOrderNumber(): string
    {
        // Canonical SD-YEAR-RANDOM6ALPHANUM (see Order::generateNumber).
        return \App\Models\Order::generateNumber();
    }

    private function getRandomReviewComment(string $type): string
    {
        $comments = [
            Review::TYPE_BUYER_TO_SELLER => [
                'Excellent service! Highly recommend.',
                'Great quality materials. Will order again.',
                'Professional and reliable seller.',
                'Good communication and fast delivery.',
                'The materials arrived on time and in perfect condition.',
            ],
            Review::TYPE_BUYER_TO_PRODUCT => [
                'High quality product. Exactly what I needed.',
                'Great value for money.',
                'Very durable and well-made.',
                'The specifications were accurate.',
                'Better than expected!',
            ],
            Review::TYPE_SELLER_TO_BUYER => [
                'Great customer. Prompt payment.',
                'Pleasant to work with. Highly recommended.',
                'Clear communication and easy transaction.',
                'Professional buyer. Would work with again.',
                'Excellent experience overall.',
            ],
        ];

        $reviewComments = $comments[$type] ?? $comments[Review::TYPE_BUYER_TO_SELLER];
        return $reviewComments[array_rand($reviewComments)];
    }

    private function getNotificationTitle(string $type): string
    {
        $titles = [
            Notification::TYPE_ORDER => ['New Order', 'Order Update', 'Order Confirmed', 'Order Shipped'],
            Notification::TYPE_PAYMENT => ['Payment Received', 'Payment Confirmed', 'Payment Refunded'],
            Notification::TYPE_DELIVERY => ['Delivery Update', 'Driver Assigned', 'Order Delivered'],
            Notification::TYPE_SYSTEM => ['System Update', 'Welcome to SiteDrop', 'Account Update'],
        ];

        $options = $titles[$type] ?? $titles[Notification::TYPE_SYSTEM];
        return $options[array_rand($options)];
    }

    private function getNotificationBody(string $type, $order = null): string
    {
        $bodies = [
            Notification::TYPE_ORDER => [
                'Your order has been placed successfully.',
                'Your order status has been updated.',
                'Your order has been confirmed by the seller.',
                'Your order is out for delivery.',
            ],
            Notification::TYPE_PAYMENT => [
                'Your payment of GHS ' . ($order ? number_format($order->total_amount, 2) : '0.00') . ' has been received.',
                'Your payment has been confirmed.',
                'A refund of GHS ' . ($order ? number_format($order->total_amount, 2) : '0.00') . ' has been processed.',
            ],
            Notification::TYPE_DELIVERY => [
                'Your order is being delivered.',
                'A driver has been assigned to your delivery.',
                'Your order has been delivered successfully.',
            ],
            Notification::TYPE_SYSTEM => [
                'Welcome to SiteDrop! Start exploring our marketplace.',
                'Your account has been updated.',
                'New features are now available.',
            ],
        ];

        $options = $bodies[$type] ?? $bodies[Notification::TYPE_SYSTEM];
        return $options[array_rand($options)];
    }

    private function getTransactionDescription(string $type, string $role): string
    {
        $descriptions = [
            'credit' => [
                'buyer' => 'Refund from order',
                'seller' => 'Payment from sale',
                'driver' => 'Delivery earnings',
                'admin' => 'Commission payment',
            ],
            'debit' => [
                'buyer' => 'Order payment',
                'seller' => 'Platform fee',
                'driver' => 'Withdrawal',
                'admin' => 'Payout processing',
            ],
        ];

        $roleDescriptions = $descriptions[$type] ?? $descriptions['credit'];
        return $roleDescriptions[$role] ?? $roleDescriptions['buyer'];
    }
}
