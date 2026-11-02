<?php
// app/Jobs/Order/ProcessRefund.php

namespace App\Jobs\Order;

use App\Models\Order;
use App\Models\OrderTimeline;
use App\Models\Transaction;
use App\Services\Payment\PaymentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessRefund implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public int $tries = 3;
    public int $backoff = 300; // 5 minutes

    public function __construct(Order $order)
    {
        $this->order = $order;
    }

    public function handle(PaymentService $paymentService): void
    {
        try {
            // Check if order is already refunded
            if ($this->order->payment_status === Order::PAYMENT_STATUS_REFUNDED) {
                Log::info('Order already refunded', ['order_id' => $this->order->id]);
                return;
            }

            // Process refund through payment gateway
            $refundResult = $paymentService->processRefund($this->order);

            if ($refundResult['success']) {
                // Update order payment status
                $this->order->update([
                    'payment_status' => Order::PAYMENT_STATUS_REFUNDED,
                ]);

                // Create refund transaction
                Transaction::create([
                    'user_id' => $this->order->buyer_id,
                    'order_id' => $this->order->id,
                    'payment_id' => $this->order->payment->id ?? null,
                    'type' => 'refund',
                    'amount' => $this->order->total_amount,
                    'currency' => 'GHS',
                    'status' => 'completed',
                    'reference' => $refundResult['reference'] ?? null,
                    'description' => "Refund for order #{$this->order->order_number}",
                    'completed_at' => now(),
                ]);

                // Refund buyer's wallet via the canonical WalletService.
                app(\App\Services\Wallet\WalletService::class)->credit(
                    $this->order->buyer,
                    (float) $this->order->total_amount,
                    "Refund for cancelled order #{$this->order->order_number}",
                    \App\Enums\WalletTransactionCategory::Refund,
                    $refundResult['reference'] ?? "REF-{$this->order->order_number}",
                    ['order_id' => $this->order->id],
                );

                // Log timeline
                OrderTimeline::log(
                    $this->order,
                    $this->order->status,
                    'Refund processed successfully',
                    ['refund_amount' => $this->order->total_amount]
                );

                Log::info('Refund processed successfully', [
                    'order_id' => $this->order->id,
                    'order_number' => $this->order->order_number,
                    'amount' => $this->order->total_amount,
                ]);
            } else {
                // Handle refund failure
                Log::error('Refund failed', [
                    'order_id' => $this->order->id,
                    'order_number' => $this->order->order_number,
                    'error' => $refundResult['message'] ?? 'Unknown error',
                ]);

                // Retry if attempts remaining
                if ($this->attempts() < 3) {
                    $this->release(now()->addMinutes(15));
                } else {
                    // Notify admin about refund failure
                    dispatch(new \App\Jobs\Notification\SendAdminAlert([
                        'type' => 'refund_failed',
                        'order_id' => $this->order->id,
                        'message' => $refundResult['message'] ?? 'Refund failed after multiple attempts',
                    ]));
                }
            }
        } catch (\Exception $e) {
            Log::error('Refund processing error', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            if ($this->attempts() < 3) {
                $this->release(now()->addMinutes(10));
            } else {
                throw $e;
            }
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('Refund job failed permanently', [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'error' => $exception->getMessage(),
        ]);

        // Notify admin
        dispatch(new \App\Jobs\Notification\SendAdminAlert([
            'type' => 'refund_failed_permanently',
            'order_id' => $this->order->id,
            'message' => $exception->getMessage(),
        ]));
    }
}
