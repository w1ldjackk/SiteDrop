<?php

namespace App\Services\Order;

use App\Models\SellerProfile;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * Single source of truth for order money math.
 *
 * Buyer pays:
 *   total = subtotal + delivery_fee + service_fee - discount + tax
 *
 * Seller receives:
 *   seller_earnings = subtotal - commission_amount
 *   (delivery/service fees are not paid out to the seller here)
 *
 * Platform receives:
 *   platform_fee = commission_amount + service_fee
 *
 * Rules (SiteDrop):
 *   - delivery_fee: GHS 20 if subtotal < 500, else free (0)
 *   - service_fee: 10% of subtotal (charged to buyer)
 *   - commission: seller's commission_rate % of subtotal (default 10%)
 */
class OrderFeeCalculator
{
    public const FREE_DELIVERY_THRESHOLD = 500.0;

    public const DEFAULT_DELIVERY_FEE = 20.0;

    public const DEFAULT_SERVICE_FEE_RATE = 0.10; // 10% of subtotal

    public const DEFAULT_COMMISSION_RATE = 10.0; // percent

    /**
     * @param  float|Collection|array  $subtotalOrItems  Subtotal amount, or cart/order line items
     * @return array{
     *   subtotal: float,
     *   delivery_fee: float,
     *   service_fee: float,
     *   discount_amount: float,
     *   tax_amount: float,
     *   total_amount: float,
     *   commission_rate: float,
     *   commission_amount: float,
     *   seller_earnings: float,
     *   platform_fee: float,
     *   quantity: float
     * }
     */
    public static function calculate(
        float|Collection|array $subtotalOrItems,
        ?int $sellerId = null,
        ?float $deliveryFee = null,
        ?float $serviceFee = null,
        float $discount = 0.0,
        float $tax = 0.0,
        ?float $commissionRatePercent = null,
    ): array {
        $quantity = 0.0;

        if ($subtotalOrItems instanceof Collection || is_array($subtotalOrItems)) {
            $items = collect($subtotalOrItems);
            $subtotal = 0.0;
            foreach ($items as $item) {
                $qty = (float) (data_get($item, 'quantity') ?? 0);
                $price = (float) (data_get($item, 'price')
                    ?? data_get($item, 'unit_price')
                    ?? data_get($item, 'price_per_unit')
                    ?? 0);
                $subtotal += round($qty * $price, 2);
                $quantity += $qty;
            }
            $subtotal = round($subtotal, 2);
        } else {
            $subtotal = round((float) $subtotalOrItems, 2);
        }

        $delivery = $deliveryFee !== null
            ? round(max(0, $deliveryFee), 2)
            : self::deliveryFeeForSubtotal($subtotal);

        $service = $serviceFee !== null
            ? round(max(0, $serviceFee), 2)
            : self::serviceFeeForSubtotal($subtotal);

        $discount = round(max(0, $discount), 2);
        $tax = round(max(0, $tax), 2);

        $total = max(0, round($subtotal + $delivery + $service + $tax - $discount, 2));

        $rate = $commissionRatePercent;
        if ($rate === null && $sellerId) {
            $rate = self::commissionRateForSeller($sellerId);
        }
        if ($rate === null) {
            $rate = self::DEFAULT_COMMISSION_RATE;
        }
        $rate = max(0, min(100, (float) $rate));

        $commission = round($subtotal * ($rate / 100), 2);
        $sellerEarnings = max(0, round($subtotal - $commission, 2));
        $platformFee = round($commission + $service, 2);

        return [
            'subtotal' => $subtotal,
            'delivery_fee' => $delivery,
            'service_fee' => $service,
            'discount_amount' => $discount,
            'tax_amount' => $tax,
            'total_amount' => $total,
            'commission_rate' => $rate,
            'commission_amount' => $commission,
            'seller_earnings' => $sellerEarnings,
            'platform_fee' => $platformFee,
            'quantity' => $quantity,
        ];
    }

    public static function deliveryFeeForSubtotal(float $subtotal): float
    {
        // Free delivery for orders at/above threshold
        if ($subtotal >= self::FREE_DELIVERY_THRESHOLD) {
            return 0.0;
        }

        return self::DEFAULT_DELIVERY_FEE;
    }

    public static function serviceFeeForSubtotal(float $subtotal): float
    {
        return round($subtotal * self::DEFAULT_SERVICE_FEE_RATE, 2);
    }

    public static function commissionRateForSeller(?int $sellerUserId): float
    {
        if (! $sellerUserId) {
            return self::DEFAULT_COMMISSION_RATE;
        }

        $profile = SellerProfile::query()
            ->where('user_id', $sellerUserId)
            ->value('commission_rate');

        if ($profile === null) {
            return self::DEFAULT_COMMISSION_RATE;
        }

        return (float) $profile;
    }
}
