<?php
// app/Jobs/Order/ReleasePaymentToSeller.php

namespace App\Jobs\Order;

use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\Transaction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ReleasePaymentToSeller implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public int $tries = 3;

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle(): void
    {
        try {
            $seller = $this->order->seller;
            $commission = $this->order->total_amount * 0.10; // 10% platform fee
            $sellerAmount = $this->order->total_amount - $commission;

            // Credit seller's wallet via the canonical WalletService
            // (Wallet has no credit() method; the service also ensures
            // the wallet row exists and records the transaction).
            app(\App\Services\Wallet\WalletService::class)->credit(
                $seller,
                (float) $sellerAmount,
                "Payment for order #{$this->order->order_number}",
                \App\Enums\WalletTransactionCategory::Earning,
                "PAY-{$this->order->order_number}",
                ['order_id' => $this->order->id, 'commission' => $commission],
            );

            // Create transaction record for seller
            Transaction::create([
                'user_id' => $seller->id,
                'order_id' => $this->order->id,
                'type' => 'payment',
                'amount' => $sellerAmount,
                'currency' => 'GHS',
                'status' => 'completed',
                'reference' => "PAY-{$this->order->order_number}",
                'description' => "Payment for completed order #{$this->order->order_number}",
                'metadata' => [
                    'commission' => $commission,
                    'commission_rate' => '10.00',
                    'order_total' => $this->order->total_amount,
                ],
                'completed_at' => now(),
            ]);

            // Log transaction
            OrderTimeline::log(
                $this->order,
                $this->order->status,
                'Payment released to seller',
                [
                    'seller_amount' => $sellerAmount,
                    'commission' => $commission,
                    'total' => $this->order->total_amount,
                ]
            );

            Log::info('Payment released to seller', [
                'order_id' => $this->order->id,
                'order_number' => $this->order->order_number,
                'seller_id' => $seller->id,
                'amount' => $sellerAmount,
                'commission' => $commission,
            ]);
        } catch (\Exception $e) {
            Log::error('Payment release error', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
            ]);

            if ($this->attempts() < 3) {
                $this->release(now()->addMinutes(10));
            } else {
                // Notify admin
                dispatch(new \App\Jobs\Notification\SendAdminAlert([
                    'type' => 'payment_release_failed',
                    'order_id' => $this->order->id,
                    'message' => $e->getMessage(),
                ]));
            }
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('Payment release job failed permanently', [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'error' => $exception->getMessage(),
        ]);
    }
}
