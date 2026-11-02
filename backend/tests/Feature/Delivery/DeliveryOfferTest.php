<?php

use App\Models\Delivery;
use App\Models\DeliveryOffer;
use App\Models\Order;
use App\Models\Product;
use App\Models\User;
use App\Services\Delivery\DeliveryService;

function makeDeliveryForOfferTests(string $orderStatus = Order::STATUS_READY_FOR_DELIVERY): Delivery
{
    $buyer = User::factory()->create(['role' => 'buyer']);
    $seller = User::factory()->create(['role' => 'seller']);

    $product = Product::create([
        'seller_id' => $seller->id,
        'name' => 'Washed sand',
        'category' => 'Sand',
        'price_per_unit' => 100,
        'unit' => 'ton',
        'stock_quantity' => 10,
        'is_available' => true,
    ]);

    $order = Order::create([
        'buyer_id' => $buyer->id,
        'seller_id' => $seller->id,
        'product_id' => $product->id,
        'order_number' => Order::generateNumber(),
        'quantity' => 1,
        'unit_price' => 100,
        'subtotal' => 100,
        'delivery_fee' => 20,
        'service_fee' => 10,
        'total_amount' => 130,
        'status' => $orderStatus,
        'payment_status' => Order::PAYMENT_STATUS_PENDING,
        'delivery_address' => '12 Test Street, Accra',
    ]);

    return Delivery::create([
        'order_id' => $order->id,
        'tracking_number' => 'TRK-'.strtoupper(uniqid()),
        'status' => Delivery::STATUS_PENDING,
        'delivery_fee' => 20,
    ]);
}

test('the first driver to accept wins and other offers expire', function () {
    $delivery = makeDeliveryForOfferTests();
    $first = User::factory()->create(['role' => 'driver']);
    $second = User::factory()->create(['role' => 'driver']);

    $firstOffer = DeliveryOffer::create([
        'delivery_id' => $delivery->id,
        'driver_id' => $first->id,
        'status' => DeliveryOffer::STATUS_OFFERED,
        'expires_at' => now()->addMinute(),
    ]);
    $secondOffer = DeliveryOffer::create([
        'delivery_id' => $delivery->id,
        'driver_id' => $second->id,
        'status' => DeliveryOffer::STATUS_OFFERED,
        'expires_at' => now()->addMinute(),
    ]);

    $service = app(DeliveryService::class);

    $result = $service->acceptOffer($firstOffer, $first);

    expect($result['accepted'])->toBeTrue()
        ->and($delivery->fresh()->driver_id)->toBe($first->id)
        ->and($delivery->fresh()->status)->toBe(Delivery::STATUS_ACCEPTED)
        ->and($firstOffer->fresh()->status)->toBe(DeliveryOffer::STATUS_ACCEPTED)
        ->and($secondOffer->fresh()->status)->toBe(DeliveryOffer::STATUS_EXPIRED);

    $late = $service->acceptOffer($secondOffer->fresh(), $second);

    expect($late['accepted'])->toBeFalse()
        ->and($delivery->fresh()->driver_id)->toBe($first->id);
});

test('a driver cannot accept an offer addressed to another driver', function () {
    $delivery = makeDeliveryForOfferTests();
    $offered = User::factory()->create(['role' => 'driver']);
    $other = User::factory()->create(['role' => 'driver']);

    $offer = DeliveryOffer::create([
        'delivery_id' => $delivery->id,
        'driver_id' => $offered->id,
        'status' => DeliveryOffer::STATUS_OFFERED,
        'expires_at' => now()->addMinute(),
    ]);

    $result = app(DeliveryService::class)->acceptOffer($offer, $other);

    expect($result['accepted'])->toBeFalse()
        ->and($delivery->fresh()->driver_id)->toBeNull();
});
