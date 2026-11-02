<?php

use App\Services\Order\OrderFeeCalculator;

test('it charges delivery and a 10% service fee below the free-delivery threshold', function () {
    $fees = OrderFeeCalculator::calculate(100.00);

    expect($fees['subtotal'])->toBe(100.0)
        ->and($fees['delivery_fee'])->toBe(20.0)
        ->and($fees['service_fee'])->toBe(10.0)
        ->and($fees['total_amount'])->toBe(130.0)
        ->and($fees['commission_amount'])->toBe(10.0)
        ->and($fees['seller_earnings'])->toBe(90.0)
        ->and($fees['platform_fee'])->toBe(20.0);
});

test('it waives delivery at the free-delivery threshold', function () {
    $fees = OrderFeeCalculator::calculate(OrderFeeCalculator::FREE_DELIVERY_THRESHOLD);

    expect($fees['delivery_fee'])->toBe(0.0)
        ->and($fees['service_fee'])->toBe(50.0)
        ->and($fees['total_amount'])->toBe(550.0);
});

test('it applies discounts, tax and custom commission rates', function () {
    $fees = OrderFeeCalculator::calculate(
        subtotalOrItems: 200.00,
        deliveryFee: 0.0,
        serviceFee: 0.0,
        discount: 25.00,
        tax: 5.00,
        commissionRatePercent: 15.0,
    );

    expect($fees['total_amount'])->toBe(180.0)
        ->and($fees['commission_amount'])->toBe(30.0)
        ->and($fees['seller_earnings'])->toBe(170.0)
        ->and($fees['platform_fee'])->toBe(30.0);
});

test('it sums line items before calculating fees', function () {
    $fees = OrderFeeCalculator::calculate([
        ['quantity' => 2, 'price' => 75.50],
        ['quantity' => 1, 'price' => 49.00],
    ]);

    expect($fees['subtotal'])->toBe(200.0)
        ->and($fees['quantity'])->toBe(3.0)
        ->and($fees['delivery_fee'])->toBe(20.0)
        ->and($fees['total_amount'])->toBe(240.0);
});
