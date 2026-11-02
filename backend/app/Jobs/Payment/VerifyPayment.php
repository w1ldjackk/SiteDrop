<?php
// app/Jobs/Payment/VerifyPayment.php

namespace App\Jobs\Payment;

use App\Models\Order;
use App\Models\Payment;
use App\Services\Payment\PaymentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class VerifyPayment implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public Payment $payment;
    public int $tries = 5;
    public int $backoff = 60;

    public function __construct(Payment $payment)
    {
        $this->payment = $payment;
    }

    public function handle(PaymentService $paymentService): void
    {
        try {
            // Verify payment status
            $verification = $paymentService->verifyPayment($this->payment);

            if ($verification['success']) {
                // Payment is confirmed
                if ($verification['status'] === 'success') {
                    $this->payment->markAsSuccess($verification['reference'] ?? null);

                    // Update order
                    $order = $this->payment->order;
                    $order->update([
                        'payment_status' => Order::PAYMENT_STATUS_PAID,
                        'status' => Order::STATUS_CONFIRMED,
                        'processed_at' => $order->processed_at ?? now(),
                    ]);

                    // Log timeline
                    \App\Models\OrderTimeline::logStatusChange(
                        $order,
                        Order::STATUS_PENDING,
                        Order::STATUS_CONFIRMED,
                        'Payment verified successfully'
                    );

                    // Send confirmation
                    dispatch(new \App\Jobs\Order\SendOrderConfirmation($order));

                    Log::info('Payment verified successfully', [
                        'payment_id' => $this->payment->id,
                        'order_id' => $this->payment->order_id,
                    ]);
                } else {
                    // Payment status is pending or failed
                    Log::info('Payment verification status', [
                        'payment_id' => $this->payment->id,
                        'status' => $verification['status'],
                    ]);

                    // Retry later if still pending
                    if ($verification['status'] === 'pending' && $this->attempts() < 5) {
                        $this->release(now()->addMinutes(30));
                    } else {
                        $this->payment->markAsFailed('Payment verification failed');
                    }
                }
            } else {
                Log::error('Payment verification failed', [
                    'payment_id' => $this->payment->id,
                    'error' => $verification['message'] ?? 'Unknown error',
                ]);

                if ($this->attempts() < 5) {
                    $this->release(now()->addMinutes(30));
                } else {
                    $this->payment->markAsFailed('Payment verification failed after multiple attempts');
                    dispatch(new \App\Jobs\Notification\SendAdminAlert([
                        'type' => 'payment_verification_failed',
                        'payment_id' => $this->payment->id,
                        'message' => $verification['message'] ?? 'Payment verification failed',
                    ]));
                }
            }
        } catch (\Exception $e) {
            Log::error('Payment verification error', [
                'payment_id' => $this->payment->id,
                'error' => $e->getMessage(),
            ]);

            if ($this->attempts() < 5) {
                $this->release(now()->addMinutes(15));
            } else {
                throw $e;
            }
        }
    }

    public function failed(\Throwable $exception): void
    {
        Log::error('Payment verification job failed permanently', [
            'payment_id' => $this->payment->id,
            'order_id' => $this->payment->order_id,
            'error' => $exception->getMessage(),
        ]);

        dispatch(new \App\Jobs\Notification\SendAdminAlert([
            'type' => 'payment_verification_job_failed',
            'payment_id' => $this->payment->id,
            'message' => $exception->getMessage(),
        ]));
    }
}
