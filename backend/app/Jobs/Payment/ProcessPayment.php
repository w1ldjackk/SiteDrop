<?php
// app/Jobs/Payment/ProcessPayment.php

namespace App\Jobs\Payment;

use App\Models\Order;
use App\Models\OrderTimeline;
use App\Services\Payment\PaymentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class ProcessPayment implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Order $order;
    public string $paymentMethod;
    public array $paymentData;
    public int $tries = 3;
    public int $backoff = 300;

    public function __construct(Order $order, string $paymentMethod, array $paymentData)
    {
        $this->order = $order;
        $this->paymentMethod = $paymentMethod;
        $this->paymentData = $paymentData;
    }

    public function handle(PaymentService $paymentService): void
    {
        try {
            // Process payment
            $result = $paymentService->processPayment(
                $this->order,
                $this->paymentMethod,
                $this->paymentData
            );

            if ($result['success']) {
                // Update order — wallet (and verified gateway) payments auto
                // confirm the order.
                $this->order->update([
                    'payment_status' => Order::PAYMENT_STATUS_PAID,
                    'status' => Order::STATUS_CONFIRMED,
                    'processed_at' => $this->order->processed_at ?? now(),
                ]);

                // Log timeline
                OrderTimeline::logStatusChange(
                    $this->order,
                    Order::STATUS_PENDING,
                    Order::STATUS_CONFIRMED,
                    'Payment confirmed'
                );

                // Send confirmation
                dispatch(new \App\Jobs\Order\SendOrderConfirmation($this->order));

                Log::info('Payment processed successfully', [
                    'order_id' => $this->order->id,
                    'order_number' => $this->order->order_number,
                    'amount' => $this->order->total_amount,
                    'payment_method' => $this->paymentMethod,
                ]);
            } else {
                // Payment failed
                $this->order->update([
                    'payment_status' => Order::PAYMENT_STATUS_FAILED,
                ]);

                Log::error('Payment failed', [
                    'order_id' => $this->order->id,
                    'error' => $result['message'] ?? 'Unknown error',
                ]);

                if ($this->attempts() < 3) {
                    $this->release(now()->addMinutes(15));
                } else {
                    // Notify admin and user
                    dispatch(new \App\Jobs\Notification\SendAdminAlert([
                        'type' => 'payment_failed',
                        'order_id' => $this->order->id,
                        'message' => $result['message'] ?? 'Payment failed after multiple attempts',
                    ]));
                }
            }
        } catch (\Exception $e) {
            Log::error('Payment processing error', [
                'order_id' => $this->order->id,
                'error' => $e->getMessage(),
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
        Log::error('Payment job failed permanently', [
            'order_id' => $this->order->id,
            'order_number' => $this->order->order_number,
            'error' => $exception->getMessage(),
        ]);

        dispatch(new \App\Jobs\Notification\SendAdminAlert([
            'type' => 'payment_job_failed',
            'order_id' => $this->order->id,
            'message' => $exception->getMessage(),
        ]));
    }
}
