<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class AddressController extends Controller
{
    /**
     * GET /api/v1/addresses
     */
    public function index(Request $request): JsonResponse
    {
        $addresses = Address::query()
            ->where('user_id', $request->user()->id)
            ->orderByDesc('is_default')
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn (Address $a) => $this->transform($a))
            ->values();

        return $this->success([
            'addresses' => $addresses,
            'default_address_id' => optional(
                $addresses->firstWhere('is_default', true)
            )['id'] ?? null,
        ]);
    }

    /**
     * GET /api/v1/addresses/{id}
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $address = $this->findOwned($request, $id);

        return $this->success([
            'address' => $this->transform($address),
        ]);
    }

    /**
     * POST /api/v1/addresses
     */
    public function store(Request $request): JsonResponse
    {
        $data = $this->validated($request);
        $user = $request->user();

        $address = DB::transaction(function () use ($data, $user) {
            if (! empty($data['is_default'])) {
                Address::where('user_id', $user->id)->update(['is_default' => false]);
            } elseif (! Address::where('user_id', $user->id)->exists()) {
                // First address becomes default
                $data['is_default'] = true;
            }

            return Address::create([
                ...$data,
                'user_id' => $user->id,
                'coordinates' => $this->coordinatesFromRequest($data),
            ]);
        });

        return $this->success(
            data: ['address' => $this->transform($address->fresh())],
            message: 'Address saved',
            status: 201,
        );
    }

    /**
     * PUT /api/v1/addresses/{id}
     */
    public function update(Request $request, int $id): JsonResponse
    {
        $address = $this->findOwned($request, $id);
        $data = $this->validated($request, isUpdate: true);

        DB::transaction(function () use ($address, $data, $request) {
            if (array_key_exists('is_default', $data) && $data['is_default']) {
                Address::where('user_id', $request->user()->id)
                    ->where('id', '!=', $address->id)
                    ->update(['is_default' => false]);
            }

            $payload = $data;
            if (array_key_exists('latitude', $data) || array_key_exists('longitude', $data) || array_key_exists('coordinates', $data)) {
                $payload['coordinates'] = $this->coordinatesFromRequest($data, $address->coordinates);
            }
            unset($payload['latitude'], $payload['longitude']);

            $address->update($payload);
        });

        return $this->success(
            data: ['address' => $this->transform($address->fresh())],
            message: 'Address updated',
        );
    }

    /**
     * DELETE /api/v1/addresses/{id}
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $address = $this->findOwned($request, $id);
        $wasDefault = $address->is_default;
        $userId = $request->user()->id;

        $address->delete();

        if ($wasDefault) {
            $next = Address::where('user_id', $userId)->orderByDesc('updated_at')->first();
            if ($next) {
                $next->update(['is_default' => true]);
            }
        }

        return $this->success(message: 'Address deleted');
    }

    /**
     * POST /api/v1/addresses/{id}/default
     */
    public function setDefault(Request $request, int $id): JsonResponse
    {
        $address = $this->findOwned($request, $id);

        DB::transaction(function () use ($address, $request) {
            Address::where('user_id', $request->user()->id)->update(['is_default' => false]);
            $address->update(['is_default' => true]);
        });

        return $this->success(
            data: ['address' => $this->transform($address->fresh())],
            message: 'Default address updated',
        );
    }

    // ============================================================
    // Helpers
    // ============================================================

    protected function findOwned(Request $request, int $id): Address
    {
        return Address::where('user_id', $request->user()->id)
            ->where('id', $id)
            ->firstOrFail();
    }

    protected function validated(Request $request, bool $isUpdate = false): array
    {
        $required = $isUpdate ? 'sometimes' : 'required';

        $data = $request->validate([
            'address_type' => [$isUpdate ? 'sometimes' : 'nullable', Rule::in(['home', 'office', 'site', 'other'])],
            'label' => ['nullable', 'string', 'max:100'],
            'address_line_1' => [$required, 'string', 'max:255'],
            'address_line_2' => ['nullable', 'string', 'max:255'],
            'city' => [$required, 'string', 'max:120'],
            'state' => ['nullable', 'string', 'max:120'],
            'postal_code' => ['nullable', 'string', 'max:32'],
            'country' => [$isUpdate ? 'sometimes' : 'nullable', 'string', 'max:120'],
            'is_default' => ['sometimes', 'boolean'],
            'delivery_instructions' => ['nullable', 'string', 'max:1000'],
            'phone' => [$required, 'string', 'max:32'],
            'receiver_name' => [$required, 'string', 'max:120'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'coordinates' => ['nullable', 'array'],
            'coordinates.lat' => ['nullable', 'numeric', 'between:-90,90'],
            'coordinates.lng' => ['nullable', 'numeric', 'between:-180,180'],
            'coordinates.latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'coordinates.longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        if (! isset($data['address_type'])) {
            $data['address_type'] = 'home';
        }
        if (! isset($data['country']) || $data['country'] === '') {
            $data['country'] = 'Ghana';
        }
        if (array_key_exists('is_default', $data)) {
            $data['is_default'] = filter_var($data['is_default'], FILTER_VALIDATE_BOOLEAN);
        }

        return $data;
    }

    /**
     * @param  array<string, mixed>  $data
     * @param  array<string, mixed>|null  $existing
     * @return array{lat: float, lng: float}|null
     */
    protected function coordinatesFromRequest(array $data, ?array $existing = null): ?array
    {
        $lat = $data['latitude']
            ?? data_get($data, 'coordinates.lat')
            ?? data_get($data, 'coordinates.latitude')
            ?? data_get($existing, 'lat')
            ?? data_get($existing, 'latitude');

        $lng = $data['longitude']
            ?? data_get($data, 'coordinates.lng')
            ?? data_get($data, 'coordinates.longitude')
            ?? data_get($existing, 'lng')
            ?? data_get($existing, 'longitude');

        if ($lat === null || $lng === null || $lat === '' || $lng === '') {
            return null;
        }

        return [
            'lat' => (float) $lat,
            'lng' => (float) $lng,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    protected function transform(Address $address): array
    {
        $coords = is_array($address->coordinates) ? $address->coordinates : null;
        $lat = data_get($coords, 'lat') ?? data_get($coords, 'latitude');
        $lng = data_get($coords, 'lng') ?? data_get($coords, 'longitude');

        return [
            'id' => $address->id,
            'user_id' => $address->user_id,
            'address_type' => $address->address_type,
            'label' => $address->label,
            'address_line_1' => $address->address_line_1,
            'address_line_2' => $address->address_line_2,
            'city' => $address->city,
            'state' => $address->state,
            'postal_code' => $address->postal_code,
            'country' => $address->country,
            'coordinates' => $coords,
            'latitude' => $lat !== null ? (float) $lat : null,
            'longitude' => $lng !== null ? (float) $lng : null,
            'is_default' => (bool) $address->is_default,
            'delivery_instructions' => $address->delivery_instructions,
            'phone' => $address->phone,
            'receiver_name' => $address->receiver_name,
            'full_address' => $address->full_address,
            'created_at' => optional($address->created_at)?->toIso8601String(),
            'updated_at' => optional($address->updated_at)?->toIso8601String(),
        ];
    }
}
