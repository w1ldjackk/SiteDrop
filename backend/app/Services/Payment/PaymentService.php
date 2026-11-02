<?php
// app/Services/Payment/PaymentService.php

namespace App\Services\Payment;

use App\Events\OrderStatusChanged;
use App\Jobs\Notification\SendOrderStatusNotification;
use App\Models\Order;
use App\Models\Payment;
use App\Models\Transaction;
use App\Models\User;
use App\Enums\WalletTransactionCategory;
use App\Models\Wallet;
use App\Services\Wallet\WalletService;
use App\Jobs\Notification\SendAdminAlert;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class PaymentService
{
    protected string $hubtelApiKey;
    protected string $hubtelSecretKey;
    protected string $paystackPublicKey;
    protected string $paystackSecretKey;
    protected string $environment;

    public function __construct()
    {
        $this->hubtelApiKey = config('services.hubtel.api_key');
        $this->hubtelSecretKey = config('services.hubtel.secret_key');
        $this->paystackPublicKey = config('services.paystack.public_key');
        $this->paystackSecretKey = config('services.paystack.secret_key');
        $this->environment = config('app.env');
    }

    /**
     * Process payment for an order
     */
    public function processPayment(Order $order, string $paymentMethod, array $data): array
    {
        try {
            // Check if order is already paid
            if ($order->payment_status === Order::PAYMENT_STATUS_PAID) {
                return [
                    'success' => false,
                    'message' => 'Order already paid',
                ];
            }

            // Create payment record
            $payment = $this->createPaymentRecord($order, $paymentMethod, $data);

            // Process based on payment method
            switch ($paymentMethod) {
                case 'mobile_money':
                    return $this->processMobileMoney($order, $payment, $data);

                case 'card':
                    return $this->processCardPayment($order, $payment, $data);

                case 'wallet':
                    return $this->processWalletPayment($order, $payment, $data);

                case 'bank_transfer':
                    return $this->processBankTransfer($order, $payment, $data);

                case 'cash_on_delivery':
                case 'cash':
                    // Cash on delivery / cash - no online processing needed
                    // Payment will be collected by driver at delivery
                    $payment->update([
                        'status' => Payment::STATUS_PENDING,
                        'gateway_response' => [
                            'message' => 'Pay on delivery',
                            'type' => 'cash_on_delivery',
                        ],
                    ]);

                    return [
                        'success' => true,
                        'payment_id' => $payment->id,
                        'reference' => $payment->payment_reference,
                        'status' => 'pending',
                        'message' => 'Order placed. You will pay when you receive your order.',
                        'type' => 'cash_on_delivery',
                    ];

                default:
                    throw new \Exception("Unsupported payment method: {$paymentMethod}");
            }
        } catch (\Exception $e) {
            Log::error('Payment processing error', [
                'order_id' => $order->id,
                'payment_method' => $paymentMethod,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Create payment record
     */
    protected function createPaymentRecord(Order $order, string $method, array $data): Payment
    {
        return Payment::create([
            'order_id' => $order->id,
            'user_id' => $order->buyer_id,
            'payment_reference' => $this->generatePaymentReference(),
            'amount' => $order->total_amount,
            'currency' => 'GHS',
            'payment_method' => $method,
            'payment_channel' => $data['network'] ?? $data['provider'] ?? null,
            'status' => Payment::STATUS_PENDING,
            'metadata' => [
                'ip_address' => request()->ip(),
                'user_agent' => request()->userAgent(),
            ],
        ]);
    }

    /**
     * Process Mobile Money via Hubtel
     */
    protected function processMobileMoney(Order $order, Payment $payment, array $data): array
    {
        try {
            // Validate mobile money data
            if (empty($data['phone_number']) || empty($data['network'])) {
                throw new \Exception('Phone number and network are required for mobile money');
            }

            // Format phone number (ensure it's 233...)
            $phone = $this->formatPhoneNumber($data['phone_number']);

            // Initialize payment with Hubtel
            $response = $this->initiateHubtelPayment($order, $payment, $phone, $data);

            if ($response['success']) {
                $payment->update([
                    'transaction_id' => $response['transaction_id'],
                    'gateway_response' => $response['response'],
                ]);

                return [
                    'success' => true,
                    'payment_id' => $payment->id,
                    'reference' => $payment->payment_reference,
                    'transaction_id' => $response['transaction_id'],
                    'status' => 'pending',
                    'message' => 'Payment initiated. Please check your phone for OTP.',
                    'requires_verification' => true,
                    'verification_code' => $response['verification_code'] ?? null,
                ];
            }

            return [
                'success' => false,
                'message' => $response['message'] ?? 'Mobile money payment initiation failed',
            ];
        } catch (\Exception $e) {
            Log::error('Mobile money payment error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process Card Payment via Paystack
     */
    protected function processCardPayment(Order $order, Payment $payment, array $data): array
    {
        try {
            // Initialize payment with Paystack
            $response = $this->initiatePaystackPayment($order, $payment, $data);

            if ($response['success']) {
                $payment->update([
                    'transaction_id' => $response['transaction_id'],
                    'gateway_response' => $response['response'],
                ]);

                return [
                    'success' => true,
                    'payment_id' => $payment->id,
                    'reference' => $payment->payment_reference,
                    'transaction_id' => $response['transaction_id'],
                    'authorization_url' => $response['authorization_url'] ?? null,
                    'status' => 'pending',
                    'message' => 'Payment initiated. Please complete payment on the payment page.',
                ];
            }

            return [
                'success' => false,
                'message' => $response['message'] ?? 'Card payment initiation failed',
            ];
        } catch (\Exception $e) {
            Log::error('Card payment error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process Wallet Payment
     */
    protected function processWalletPayment(Order $order, Payment $payment, array $data): array
    {
        try {
            $user = $order->buyer;
            if (! $user) {
                throw new \Exception('Buyer not found for order');
            }

            /** @var WalletService $walletService */
            $walletService = app(WalletService::class);
            $wallet = $walletService->getOrCreateWallet($user);

            $walletService->debit(
                $user,
                (float) $order->total_amount,
                "Payment for order #{$order->order_number}",
                WalletTransactionCategory::Payment,
                $order->order_number,
                ['order_id' => $order->id, 'payment_id' => $payment->id],
                null,
                true
            );

            $wallet->refresh();

            // Mark payment as successful
            $payment->update([
                'status' => Payment::STATUS_SUCCESS,
                'paid_at' => now(),
                'gateway_response' => ['source' => 'wallet', 'balance_after' => $wallet->balance],
            ]);

            // Create transaction record
            Transaction::create([
                'user_id' => $user->id,
                'order_id' => $order->id,
                'payment_id' => $payment->id,
                'type' => 'payment',
                'amount' => $order->total_amount,
                'currency' => 'GHS',
                'status' => 'completed',
                'reference' => $payment->payment_reference,
                'description' => "Wallet payment for order #{$order->order_number}",
                'completed_at' => now(),
            ]);

            // Update order — wallet was deducted, so auto mark paid + confirmed.
            $oldStatus = $order->status;
            $order->update([
                'payment_status' => Order::PAYMENT_STATUS_PAID,
                'status' => Order::STATUS_CONFIRMED,
                'processed_at' => $order->processed_at ?? now(),
            ]);
            $order->refresh();

            if (!$order->timeline()->where('status', Order::STATUS_CONFIRMED)->exists()) {
                \App\Models\OrderTimeline::log(
                    $order,
                    Order::STATUS_CONFIRMED,
                    'Payment confirmed via wallet',
                    ['amount' => $order->total_amount]
                );
            }

            // Realtime broadcast — only if status actually changed
            if ($oldStatus !== Order::STATUS_CONFIRMED) {
                $fresh = $order->fresh() ?? $order;
                event(new OrderStatusChanged($fresh, $oldStatus, Order::STATUS_CONFIRMED));
                dispatch(new SendOrderStatusNotification($fresh, $oldStatus, Order::STATUS_CONFIRMED));
            }

            return [
                'success' => true,
                'payment_id' => $payment->id,
                'reference' => $payment->payment_reference,
                'status' => 'success',
                'message' => 'Payment successful using wallet',
                'balance_after' => $wallet->balance,
            ];
        } catch (\Exception $e) {
            Log::error('Wallet payment error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            // Don't leave a dangling pending Payment row when the debit failed —
            // mark it failed so history / retries stay truthful.
            try {
                if (isset($payment) && $payment->exists) {
                    $payment->update([
                        'status' => Payment::STATUS_FAILED,
                        'metadata' => array_merge($payment->metadata ?? [], [
                            'failure_reason' => $e->getMessage(),
                        ]),
                    ]);
                }
            } catch (\Throwable $ignored) {
            }

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process Bank Transfer
     */
    protected function processBankTransfer(Order $order, Payment $payment, array $data): array
    {
        try {
            // Generate bank transfer details
            $bankDetails = $this->generateBankTransferDetails($order, $payment);

            $payment->update([
                'status' => Payment::STATUS_PENDING,
                'metadata' => array_merge($payment->metadata ?? [], [
                    'bank_details' => $bankDetails,
                ]),
            ]);

            return [
                'success' => true,
                'payment_id' => $payment->id,
                'reference' => $payment->payment_reference,
                'status' => 'pending',
                'message' => 'Bank transfer details generated. Please transfer the amount to the provided account.',
                'bank_details' => $bankDetails,
            ];
        } catch (\Exception $e) {
            Log::error('Bank transfer error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verify payment status
     */
    public function verifyPayment(Payment $payment): array
    {
        try {
            if (empty($payment->payment_method)) {
                throw new \Exception('Payment method not found');
            }

            switch ($payment->payment_method) {
                case 'mobile_money':
                    return $this->verifyHubtelPayment($payment);

                case 'card':
                    return $this->verifyPaystackPayment($payment);

                case 'wallet':
                    return $this->verifyWalletPayment($payment);

                case 'bank_transfer':
                    return $this->verifyBankTransferPayment($payment);

                default:
                    throw new \Exception("Unsupported payment method for verification");
            }
        } catch (\Exception $e) {
            Log::error('Payment verification error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Initiate Hubtel payment
     */
    protected function initiateHubtelPayment(Order $order, Payment $payment, string $phone, array $data): array
    {
        try {
            $payload = [
                'amount' => $order->total_amount,
                'currency' => 'GHS',
                'callback_url' => route('api.v1.payments.hubtel-callback'),
                'description' => "Order #{$order->order_number}",
                'transaction_id' => $payment->payment_reference,
                'customer' => [
                    'name' => $order->buyer->name,
                    'phone' => $phone,
                    'email' => $order->buyer->email,
                ],
                'network' => $data['network'],
            ];

            $response = Http::withBasicAuth($this->hubtelApiKey, $this->hubtelSecretKey)
                ->post('https://api.hubtel.com/v1/merchantaccount/merchant/payments/mobilemoney', $payload);

            if ($response->successful()) {
                $result = $response->json();
                return [
                    'success' => true,
                    'transaction_id' => $result['transaction_id'] ?? null,
                    'verification_code' => $result['verification_code'] ?? null,
                    'response' => $result,
                ];
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Hubtel payment initiation failed',
                'response' => $response->json(),
            ];
        } catch (\Exception $e) {
            Log::error('Hubtel API error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verify Hubtel payment
     */
    protected function verifyHubtelPayment(Payment $payment): array
    {
        try {
            $transactionId = $payment->transaction_id;

            if (!$transactionId) {
                throw new \Exception('Transaction ID not found');
            }

            $response = Http::withBasicAuth($this->hubtelApiKey, $this->hubtelSecretKey)
                ->get("https://api.hubtel.com/v1/merchantaccount/merchant/transactions/{$transactionId}");

            if ($response->successful()) {
                $result = $response->json();
                $status = $result['status'] ?? 'pending';

                if ($status === 'success') {
                    $payment->markAsSuccess($result['transaction_id'] ?? null);
                    $this->finalizePayment($payment);
                    return [
                        'success' => true,
                        'status' => 'success',
                        'message' => 'Payment verified successfully',
                        'data' => $result,
                    ];
                } elseif ($status === 'pending') {
                    return [
                        'success' => false,
                        'status' => 'pending',
                        'message' => 'Payment is still pending',
                        'data' => $result,
                    ];
                } else {
                    $payment->markAsFailed($result['message'] ?? 'Payment failed');
                    return [
                        'success' => false,
                        'status' => 'failed',
                        'message' => $result['message'] ?? 'Payment failed',
                        'data' => $result,
                    ];
                }
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Payment verification failed',
            ];
        } catch (\Exception $e) {
            Log::error('Hubtel verification error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Initiate Paystack payment
     */
    protected function initiatePaystackPayment(Order $order, Payment $payment, array $data): array
    {
        try {
            $payload = [
                'email' => $order->buyer->email,
                'amount' => $order->total_amount * 100, // Convert to pesewas
                'currency' => 'GHS',
                'reference' => $payment->payment_reference,
                'callback_url' => route('api.v1.payments.paystack-callback'),
                'metadata' => [
                    'order_id' => $order->id,
                    'order_number' => $order->order_number,
                ],
            ];

            if (!empty($data['card_token'])) {
                $payload['card'] = ['token' => $data['card_token']];
            }

            if (!empty($data['authorization_code'])) {
                $payload['authorization_code'] = $data['authorization_code'];
            }

            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $this->paystackSecretKey,
                'Content-Type' => 'application/json',
            ])->post('https://api.paystack.co/transaction/initialize', $payload);

            if ($response->successful()) {
                $result = $response->json();
                return [
                    'success' => true,
                    'transaction_id' => $result['data']['reference'] ?? null,
                    'authorization_url' => $result['data']['authorization_url'] ?? null,
                    'response' => $result,
                ];
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Paystack payment initiation failed',
                'response' => $response->json(),
            ];
        } catch (\Exception $e) {
            Log::error('Paystack API error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verify Paystack payment
     */
    protected function verifyPaystackPayment(Payment $payment): array
    {
        try {
            $reference = $payment->transaction_id ?? $payment->payment_reference;

            if (!$reference) {
                throw new \Exception('Payment reference not found');
            }

            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $this->paystackSecretKey,
            ])->get("https://api.paystack.co/transaction/verify/{$reference}");

            if ($response->successful()) {
                $result = $response->json();
                $status = $result['data']['status'] ?? 'pending';

                if ($status === 'success') {
                    $payment->markAsSuccess($result['data']['reference'] ?? null);
                    $this->finalizePayment($payment);
                    return [
                        'success' => true,
                        'status' => 'success',
                        'message' => 'Payment verified successfully',
                        'data' => $result['data'],
                    ];
                } elseif ($status === 'pending') {
                    return [
                        'success' => false,
                        'status' => 'pending',
                        'message' => 'Payment is still pending',
                        'data' => $result['data'],
                    ];
                } else {
                    $payment->markAsFailed($result['data']['gateway_response'] ?? 'Payment failed');
                    return [
                        'success' => false,
                        'status' => 'failed',
                        'message' => $result['data']['gateway_response'] ?? 'Payment failed',
                        'data' => $result['data'],
                    ];
                }
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Payment verification failed',
            ];
        } catch (\Exception $e) {
            Log::error('Paystack verification error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Verify wallet payment
     */
    protected function verifyWalletPayment(Payment $payment): array
    {
        return [
            'success' => true,
            'status' => $payment->status,
            'message' => 'Wallet payment status checked',
            'data' => [
                'reference' => $payment->payment_reference,
                'status' => $payment->status,
                'paid_at' => $payment->paid_at,
            ],
        ];
    }

    /**
     * Verify bank transfer payment
     */
    protected function verifyBankTransferPayment(Payment $payment): array
    {
        return [
            'success' => true,
            'status' => $payment->status,
            'message' => 'Bank transfer payment status checked',
            'data' => [
                'reference' => $payment->payment_reference,
                'status' => $payment->status,
            ],
        ];
    }

    /**
     * Finalize payment after verification
     */
    protected function finalizePayment(Payment $payment): void
    {
        $order = $payment->order;

        // Capture old status before update for correct realtime payload
        $oldStatus = $order->status;

        // Update order
        $order->update([
            'payment_status' => Order::PAYMENT_STATUS_PAID,
            'status' => Order::STATUS_CONFIRMED,
            'processed_at' => $order->processed_at ?? now(),
        ]);
        $order->refresh();

        // Create transaction
        Transaction::create([
            'user_id' => $payment->user_id,
            'order_id' => $order->id,
            'payment_id' => $payment->id,
            'type' => 'payment',
            'amount' => $payment->amount,
            'currency' => 'GHS',
            'status' => 'completed',
            'reference' => $payment->payment_reference,
            'description' => "Payment for order #{$order->order_number}",
            'completed_at' => now(),
        ]);

        // Realtime broadcast — only if status actually changed
        if ($oldStatus !== Order::STATUS_CONFIRMED) {
            $fresh = $order->fresh() ?? $order;
            event(new OrderStatusChanged($fresh, $oldStatus, Order::STATUS_CONFIRMED));
            dispatch(new SendOrderStatusNotification($fresh, $oldStatus, Order::STATUS_CONFIRMED));
        }

        // Send order confirmation
        dispatch(new \App\Jobs\Order\SendOrderConfirmation($order));

        Log::info('Payment finalized', [
            'payment_id' => $payment->id,
            'order_id' => $order->id,
            'amount' => $payment->amount,
        ]);
    }

    /**
     * Process refund
     */
    public function processRefund(Order $order): array
    {
        try {
            $payment = $order->payment;

            if (!$payment) {
                throw new \Exception('Payment not found for this order');
            }

            if ($payment->status === Payment::STATUS_REFUNDED) {
                throw new \Exception('Payment already refunded');
            }

            // Process refund based on payment method
            switch ($payment->payment_method) {
                case 'mobile_money':
                case 'card':
                    return $this->processGatewayRefund($payment);

                case 'wallet':
                    return $this->processWalletRefund($payment);

                default:
                    throw new \Exception("Refund not supported for payment method: {$payment->payment_method}");
            }
        } catch (\Exception $e) {
            Log::error('Refund processing error', [
                'order_id' => $order->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process gateway refund (Hubtel/Paystack)
     */
    protected function processGatewayRefund(Payment $payment): array
    {
        try {
            $reference = $payment->transaction_id ?? $payment->payment_reference;

            if (!$reference) {
                throw new \Exception('Payment reference not found');
            }

            if (str_contains($payment->payment_method, 'mobile_money')) {
                return $this->processHubtelRefund($payment, $reference);
            } else {
                return $this->processPaystackRefund($payment, $reference);
            }
        } catch (\Exception $e) {
            Log::error('Gateway refund error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process Hubtel refund
     */
    protected function processHubtelRefund(Payment $payment, string $reference): array
    {
        try {
            $response = Http::withBasicAuth($this->hubtelApiKey, $this->hubtelSecretKey)
                ->post("https://api.hubtel.com/v1/merchantaccount/merchant/transactions/{$reference}/refund", [
                    'amount' => $payment->amount,
                    'reason' => 'Order refund',
                ]);

            if ($response->successful()) {
                $result = $response->json();
                $payment->update([
                    'status' => Payment::STATUS_REFUNDED,
                    'refunded_at' => now(),
                    'refund_amount' => $payment->amount,
                ]);

                $this->finalizeRefund($payment);

                return [
                    'success' => true,
                    'message' => 'Refund processed successfully',
                    'reference' => $result['reference'] ?? null,
                    'amount' => $payment->amount,
                ];
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Refund failed',
            ];
        } catch (\Exception $e) {
            Log::error('Hubtel refund error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process Paystack refund
     */
    protected function processPaystackRefund(Payment $payment, string $reference): array
    {
        try {
            $response = Http::withHeaders([
                'Authorization' => 'Bearer ' . $this->paystackSecretKey,
                'Content-Type' => 'application/json',
            ])->post('https://api.paystack.co/refund', [
                'transaction' => $reference,
                'amount' => $payment->amount * 100,
                'currency' => 'GHS',
            ]);

            if ($response->successful()) {
                $result = $response->json();
                $payment->update([
                    'status' => Payment::STATUS_REFUNDED,
                    'refunded_at' => now(),
                    'refund_amount' => $payment->amount,
                ]);

                $this->finalizeRefund($payment);

                return [
                    'success' => true,
                    'message' => 'Refund processed successfully',
                    'reference' => $result['data']['reference'] ?? null,
                    'amount' => $payment->amount,
                ];
            }

            return [
                'success' => false,
                'message' => $response->json()['message'] ?? 'Refund failed',
            ];
        } catch (\Exception $e) {
            Log::error('Paystack refund error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Process wallet refund
     */
    protected function processWalletRefund(Payment $payment): array
    {
        try {
            $user = User::query()->find($payment->user_id);
            if (! $user) {
                throw new \Exception('Wallet user not found');
            }

            /** @var WalletService $walletService */
            $walletService = app(WalletService::class);
            $walletService->credit(
                $user,
                (float) $payment->amount,
                "Refund for payment #{$payment->payment_reference}",
                WalletTransactionCategory::Refund,
                $payment->payment_reference,
                ['payment_id' => $payment->id],
                null,
                true
            );
            $wallet = $walletService->getOrCreateWallet($user);

            $payment->update([
                'status' => Payment::STATUS_REFUNDED,
                'refunded_at' => now(),
                'refund_amount' => $payment->amount,
            ]);

            $this->finalizeRefund($payment);

            return [
                'success' => true,
                'message' => 'Wallet refund processed successfully',
                'amount' => $payment->amount,
                'balance_after' => $wallet->balance,
            ];
        } catch (\Exception $e) {
            Log::error('Wallet refund error', [
                'payment_id' => $payment->id,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => $e->getMessage(),
            ];
        }
    }

    /**
     * Finalize refund
     */
    protected function finalizeRefund(Payment $payment): void
    {
        $order = $payment->order;

        // Update order
        $order->update([
            'payment_status' => Order::PAYMENT_STATUS_REFUNDED,
        ]);

        // Create refund transaction
        Transaction::create([
            'user_id' => $payment->user_id,
            'order_id' => $order->id,
            'payment_id' => $payment->id,
            'type' => 'refund',
            'amount' => $payment->amount,
            'currency' => 'GHS',
            'status' => 'completed',
            'reference' => $payment->payment_reference,
            'description' => "Refund for order #{$order->order_number}",
            'completed_at' => now(),
        ]);

        Log::info('Refund finalized', [
            'payment_id' => $payment->id,
            'order_id' => $order->id,
            'amount' => $payment->amount,
        ]);
    }

    /**
     * Generate payment reference
     */
    protected function generatePaymentReference(): string
    {
        return 'PAY-' . date('Y') . '-' . strtoupper(Str::random(10));
    }

    /**
     * Format phone number to 233 format
     */
    protected function formatPhoneNumber(string $phone): string
    {
        $phone = preg_replace('/\D/', '', $phone);

        if (strpos($phone, '233') !== 0) {
            if (strlen($phone) === 10) {
                $phone = '233' . substr($phone, 1);
            } else {
                $phone = '233' . $phone;
            }
        }

        return $phone;
    }

    /**
     * Generate bank transfer details
     */
    protected function generateBankTransferDetails(Order $order, Payment $payment): array
    {
        return [
            'bank_name' => 'GCB Bank',
            'account_number' => '1234567890',
            'account_name' => 'SiteDrop Marketplace',
            'reference' => $payment->payment_reference,
            'amount' => number_format($order->total_amount, 2),
            'currency' => 'GHS',
            'description' => "Payment for order #{$order->order_number}",
        ];
    }

    /**
     * Get available payment methods
     */
    public function getPaymentMethods(): array
    {
        return [
            'mobile_money' => [
                'id' => 'mobile_money',
                'name' => 'Mobile Money',
                'icon' => 'mobile',
                'networks' => ['MTN', 'Vodafone', 'AirtelTigo'],
                'is_active' => true,
                'is_instant' => true,
            ],
            'card' => [
                'id' => 'card',
                'name' => 'Card Payment',
                'icon' => 'credit-card',
                'providers' => ['Visa', 'Mastercard'],
                'is_active' => true,
                'is_instant' => true,
            ],
            'bank_transfer' => [
                'id' => 'bank_transfer',
                'name' => 'Bank Transfer',
                'icon' => 'bank',
                'is_active' => true,
                'is_instant' => false,
            ],
            'wallet' => [
                'id' => 'wallet',
                'name' => 'Wallet Balance',
                'icon' => 'wallet',
                'is_active' => true,
                'is_instant' => true,
            ],
        ];
    }
}
