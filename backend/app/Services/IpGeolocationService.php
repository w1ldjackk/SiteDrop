<?php

namespace App\Services;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\RequestException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

class IpGeolocationService
{
    protected Client $client;

    protected ?string $apiKey;

    protected int $cacheTTL = 3600; // 1 hour cache

    public function __construct(?Client $client = null)
    {
        $this->client = $client ?? new Client([
            'timeout' => 5,
            'connect_timeout' => 3,
        ]);
        $this->apiKey = config('services.ip_geolocation.api_key');
        $this->cacheTTL = (int) config('services.ip_geolocation.cache_ttl', 3600);
    }

    /**
     * Get location data for IP address with caching and local IP handling.
     *
     * @return array{
     *     city: ?string,
     *     region: ?string,
     *     country: ?string,
     *     timezone?: mixed,
     *     isp?: ?string,
     *     organization?: ?string,
     *     is_local: bool
     * }|null
     */
    public function getLocation(string $ip): ?array
    {
        if ($this->isLocalIp($ip)) {
            Log::info('Local IP detected, skipping geolocation', ['ip' => $ip]);

            return [
                'city' => 'Local Development',
                'region' => null,
                'country' => 'Local',
                'is_local' => true,
            ];
        }

        if (empty($this->apiKey)) {
            Log::warning('IP geolocation skipped: missing API key', ['ip' => $ip]);

            return null;
        }

        $cacheKey = "ip_location_{$ip}";
        $cachedLocation = Cache::get($cacheKey);

        if ($cachedLocation) {
            Log::info('IP location retrieved from cache', ['ip' => $ip]);

            return $cachedLocation;
        }

        try {
            Log::info('Fetching IP geolocation', ['ip' => $ip]);

            $response = $this->client->get('https://api.ipgeolocation.io/ipgeo', [
                'query' => [
                    'apiKey' => $this->apiKey,
                    'ip' => $ip,
                    'fields' => 'city,state_prov,country_name,timezone,isp,org',
                ],
            ]);

            $data = json_decode((string) $response->getBody(), true);

            if (! $data || isset($data['error_message'])) {
                throw new \Exception($data['error_message'] ?? 'Invalid API response');
            }

            $location = [
                'city' => $data['city'] ?? null,
                'region' => $data['state_prov'] ?? null,
                'country' => $data['country_name'] ?? null,
                'timezone' => $data['timezone'] ?? null,
                'isp' => $data['isp'] ?? null,
                'organization' => $data['org'] ?? null,
                'is_local' => false,
            ];

            Cache::put($cacheKey, $location, $this->cacheTTL);

            Log::info('IP geolocation successful', [
                'ip' => $ip,
                'location' => ($location['city'] ?? '?').', '.($location['country'] ?? '?'),
            ]);

            return $location;
        } catch (RequestException $e) {
            Log::warning('IP geolocation API request failed', [
                'ip' => $ip,
                'error' => $e->getMessage(),
                'status_code' => $e->hasResponse() ? $e->getResponse()->getStatusCode() : null,
            ]);
        } catch (\Exception $e) {
            Log::warning('IP geolocation failed', [
                'ip' => $ip,
                'error' => $e->getMessage(),
            ]);
        }

        return null;
    }

    /**
     * Check if IP is local/development.
     */
    private function isLocalIp(string $ip): bool
    {
        $localIps = [
            '127.0.0.1',
            '::1',
            '0.0.0.0',
            '::',
        ];

        if (in_array($ip, $localIps, true)) {
            return true;
        }

        // Private / loopback ranges (IPv4)
        if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4)) {
            return str_starts_with($ip, '127.')
                || str_starts_with($ip, '10.')
                || str_starts_with($ip, '192.168.')
                || (bool) preg_match('/^172\.(1[6-9]|2\d|3[0-1])\./', $ip);
        }

        return false;
    }

    /**
     * Get formatted location string for emails / activity logs.
     *
     * @param  array<string, mixed>|null  $location
     */
    public function getFormattedLocation(?array $location): string
    {
        if (! $location) {
            return 'Unknown Location';
        }

        if (! empty($location['is_local'])) {
            return 'Local Development';
        }

        $parts = array_filter([
            $location['city'] ?? null,
            $location['region'] ?? null,
            $location['country'] ?? null,
        ]);

        return $parts !== [] ? implode(', ', $parts) : 'Unknown Location';
    }

    /**
     * Resolve location for the current request IP.
     *
     * @return array<string, mixed>|null
     */
    public function getLocationForRequest(?string $ip = null): ?array
    {
        $ip = $ip ?: request()->ip() ?: '127.0.0.1';

        return $this->getLocation($ip);
    }

    /**
     * Formatted string for the current request IP.
     */
    public function getFormattedLocationForRequest(?string $ip = null): string
    {
        return $this->getFormattedLocation($this->getLocationForRequest($ip));
    }
}
