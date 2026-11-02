<?php

namespace App\Services;

use App\Models\Gateway;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Exception;

class MoolreService
{
    protected string $baseUrl;
    protected string $username;
    protected string $apiKey;
    protected ?string $publicKey;
    protected string $accountNumber;
    protected string $currency;
    protected ?Gateway $gateway;

    public function __construct(?Gateway $gateway = null)
    {
        $this->gateway = $gateway;
        $config = config('services.moolre', []);

        $this->username      = $config['username']       ?? null;
        $this->apiKey        = $config['api_key']        ?? null;
        $this->publicKey     = $config['public_key']     ?? null;
        $this->accountNumber = $config['account_number'] ?? null;
        $this->currency      = $config['currency']       ?? 'GHS';
        $this->baseUrl       = rtrim($config['base_url'] ?? 'https://api.moolre.com/open', '/');

        if ($gateway && $gateway->credentials) {
            $creds = $gateway->credentials;
            $this->username      = $creds['username']       ?? $this->username;
            $this->apiKey        = $creds['api_key']        ?? $this->apiKey;
            $this->publicKey     = $creds['public_key']     ?? $this->publicKey;
            $this->accountNumber = $creds['account_number'] ?? $this->accountNumber;
            $this->currency      = $creds['currency']       ?? $this->currency;
            $this->baseUrl       = rtrim($creds['base_url'] ?? $this->baseUrl, '/');
        }

        $this->validateCredentials();
    }

    private function validateCredentials(): void
    {
        $missing = [];
        if (!$this->username)      $missing[] = 'username';
        if (!$this->apiKey)        $missing[] = 'api_key';
        if (!$this->accountNumber) $missing[] = 'account_number';
        if ($missing) {
            throw new Exception('Moolre gateway missing credentials: ' . implode(', ', $missing));
        }
    }

    private function headers(bool $usePublicKey = false): array
    {
        $headers = [
            'Content-Type' => 'application/json',
            'X-API-USER'   => $this->username,
        ];

        $key = $usePublicKey ? $this->publicKey : $this->apiKey;
        $headerKey = $usePublicKey ? 'X-API-PUBKEY' : 'X-API-KEY';

        if ($key) {
            $headers[$headerKey] = $key;
        }

        return $headers;
    }

    /**
     * Generic POST with retry + callback
     */
    private function post(
        string $endpoint,
        array $payload,
        callable $successCallback,
        bool $usePublicKey = false,
        int $retries = 1
    ): ?array {
        $url = $this->baseUrl . $endpoint;

        for ($i = 0; $i <= $retries; $i++) {
            try {
                $response = Http::withHeaders($this->headers($usePublicKey))
                    ->timeout(30)
                    ->connectTimeout(60)
                    ->post($url, $payload);

                $json = $response->json();

                if ($response->failed()) {
                    Log::error("Moolre API error [{$response->status()}]", [
                        'url'     => $url,
                        'payload' => $payload,
                        'body'    => $response->body()
                    ]);
                    continue;
                }

                $result = $successCallback($json);

                if (is_array($result)) {
                    return $result;
                }

                if (is_string($result)) {
                    return ['name' => $result];
                }

                Log::warning('Moolre non-success response', [
                    'url'      => $url,
                    'payload'  => $payload,
                    'response' => $json
                ]);
            } catch (Exception $e) {
                Log::error('Moolre exception', [
                    'url'     => $url,
                    'error'   => $e->getMessage(),
                    'payload' => $payload
                ]);
            }
        }

        return null;
    }

    public function accountStatus(): ?array
    {
        return $this->post('/account/status', [
            'type'          => 1,
            'accountnumber' => $this->accountNumber,
        ], fn($json) => data_get($json, 'status') == 1 && data_get($json, 'code') === 'SW01'
            ? data_get($json, 'data') : null);
    }

    public function listTransactions(array $filters = []): ?array
    {
        $payload = array_merge([
            'type'          => 2,
            'accountnumber' => $this->accountNumber,
        ], $filters);

        return $this->post('/account/status', $payload, fn($json) =>
        in_array(data_get($json, 'code'), ['ST08', 'ST09'])
            ? data_get($json, 'data') : null);
    }


    public function validateName(string $receiver, int $channel, ?string $sublistid = null): ?array
    {
        $payload = [
            'type'          => 1,
            'receiver'      => (string) $receiver,
            'channel'       => $channel,
            'currency'      => $this->currency,
            'accountnumber' => $this->accountNumber,
        ];
        if ($sublistid) {
            $payload['sublistid'] = strtoupper(trim($sublistid));
        }

        $rawResult = $this->post('/transact/validate', $payload, function ($json) {


            $status = data_get($json, 'status');
            $code = data_get($json, 'code');

            if ($status != 1 || !in_array($code, ['AVD01', 'SVD08'])) {
                Log::warning('Moolre Validate Failed', ['code' => $code, 'message' => data_get($json, 'message')]);
                return null;
            }

            $data = data_get($json, 'data');
            $name = is_string($data) ? $data : data_get($data, 'name') ?? data_get($data, 'recipient_name');
            return $name ?: null;
        });
        return is_string($rawResult) ? ['name' => $rawResult] : $rawResult;
    }

    public function initiateTransfer(
        int $channel,
        string $amount,
        string $receiver,
        string $externalref,
        ?string $reference = null,
        ?string $sublistid = null
    ): ?array {
        $payload = [
            'type'          => 1,
            'channel'       => $channel,
            'currency'      => $this->currency,
            'amount'        => $amount,
            'receiver'      => $receiver,
            'externalref'   => $externalref,
            'accountnumber' => $this->accountNumber,
        ];
        if ($reference) $payload['reference'] = $reference;
        if ($sublistid) $payload['sublistid'] = $sublistid;

        return $this->post('/transact/transfer', $payload, fn($json) =>
        data_get($json, 'status') == 1 && data_get($json, 'code') === 'OBGH01'
            ? data_get($json, 'data') : null);
    }

    public function checkStatus(int $idtype, string $id, bool $usePublicKey = true): ?array
    {
        $payload = [
            'type'          => 1,
            'idtype'        => $idtype,
            'id'            => $id,
            'accountnumber' => $this->accountNumber,
        ];

        return $this->post('/transact/status', $payload, fn($json) =>
        data_get($json, 'status') == 1 && in_array(data_get($json, 'code'), ['SS01', 'SS07'])
            ? data_get($json, 'data') : null, $usePublicKey);
    }

    public function initiatePayment(
        int $channel,
        string $payer,
        string $amount,
        string $externalref,
        ?string $reference = null,
        ?string $otpcode = null,
        ?string $sessionid = null
    ): ?array {
        $payload = [
            'type'          => 1,
            'channel'       => $channel,
            'currency'      => $this->currency,
            'payer'         => $payer,
            'amount'        => $amount,
            'externalref'   => $externalref,
            'accountnumber' => $this->accountNumber,
            'callbackurl'   => route('user.moolre.callback', [], true),
        ];
        if ($reference) $payload['reference'] = $reference;
        if ($otpcode)   $payload['otpcode']   = $otpcode;
        if ($sessionid) $payload['sessionid'] = $sessionid;

        return $this->post('/transact/payment', $payload, fn($json) => [
            'status'  => data_get($json, 'status'),
            'code'    => data_get($json, 'code'),
            'message' => data_get($json, 'message'),
            'data'    => data_get($json, 'data'),
        ], true);
    }

    public function verifyWebhookSecret(string $receivedSecret): bool
    {
        $secret = config('services.moolre.webhook_secret')
            ?? ($this->gateway?->credentials['webhook_secret'] ?? null);

        if (!$secret) return true;

        return hash_equals($secret, $receivedSecret);
    }
}
