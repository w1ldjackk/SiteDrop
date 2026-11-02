<?php

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Laravel\Sanctum\Sanctum;

beforeEach(function () {
    Queue::fake();
    Event::fake();
});

function makeOrderForStatusTests(string $status = Order::STATUS_PENDING): array
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
        'status' => $status,
        'payment_status' => Order::PAYMENT_STATUS_PENDING,
        'payment_method' => Order::PAYMENT_METHOD_CASH,
        'delivery_address' => '12 Test Street, Accra',
    ]);

    OrderItem::create([
        'order_id' => $order->id,
        'product_id' => $product->id,
        'quantity' => 1,
        'price' => 100,
        'subtotal' => 100,
        'unit' => 'ton',
    ]);

    return [$order, $buyer, $seller, $product];
}

test('a seller can advance an order through valid statuses', function () {
    [$order, , $seller] = makeOrderForStatusTests();
    Sanctum::actingAs($seller);

    $this->putJson("/api/v1/orders/{$order->id}/status", [
        'status' => Order::STATUS_CONFIRMED,
    ])->assertOk()->assertJsonPath('data.order.status', Order::STATUS_CONFIRMED);

    $this->putJson("/api/v1/orders/{$order->id}/status", [
        'status' => Order::STATUS_PROCESSING,
    ])->assertOk()->assertJsonPath('data.order.status', Order::STATUS_PROCESSING);

    expect($order->fresh()->status)->toBe(Order::STATUS_PROCESSING);
});

test('an invalid status transition is rejected', function () {
    [$order, , $seller] = makeOrderForStatusTests();
    Sanctum::actingAs($seller);

    $this->putJson("/api/v1/orders/{$order->id}/status", [
        'status' => Order::STATUS_DELIVERED,
    ])->assertStatus(400);

    expect($order->fresh()->status)->toBe(Order::STATUS_PENDING);
});

test('a buyer cannot update an order status', function () {
    [$order, $buyer] = makeOrderForStatusTests();
    Sanctum::actingAs($buyer);

    $this->putJson("/api/v1/orders/{$order->id}/status", [
        'status' => Order::STATUS_CONFIRMED,
    ])->assertStatus(403);
});

test('a buyer can cancel a pending order and stock is restored', function () {
    [$order, $buyer, , $product] = makeOrderForStatusTests();
    $product->update(['stock_quantity' => 9]);
    Sanctum::actingAs($buyer);

    $this->postJson("/api/v1/orders/{$order->id}/cancel", [
        'reason' => 'Changed my mind',
    ])->assertOk()->assertJsonPath('data.order.status', Order::STATUS_CANCELLED);

    expect($order->fresh()->status)->toBe(Order::STATUS_CANCELLED)
        ->and($product->fresh()->stock_quantity)->toBe(10);
});

test('an order that has shipped can no longer be cancelled', function () {
    [$order, $buyer] = makeOrderForStatusTests(Order::STATUS_IN_TRANSIT);
    Sanctum::actingAs($buyer);

    $this->postJson("/api/v1/orders/{$order->id}/cancel", [
        'reason' => 'Too late',
    ])->assertStatus(400);

    expect($order->fresh()->status)->toBe(Order::STATUS_IN_TRANSIT);
});
