<?php
// app/Http/Requests/Api/SellerOnboardingRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SellerOnboardingRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'business_name' => 'required|string|max:255',
            'business_type' => ['required', Rule::in(['quarry', 'truck_owner', 'supplier', 'distributor', 'retailer', 'manufacturer'])],
            'business_registration_number' => 'sometimes|nullable|string|max:50',
            'tax_id' => 'sometimes|nullable|string|max:50',
            'business_phone' => 'required|string|max:20',
            'business_email' => 'required|email|max:255',
            'website' => 'sometimes|nullable|url|max:255',
            'description' => 'sometimes|nullable|string|max:2000',
            // Coverage areas pinned on the seller map: [{lat, lng, label?, radius_km?}].
            // Nullable so clients can omit the key instead of sending null.
            'service_areas' => 'sometimes|nullable|array',
            'service_areas.*' => 'array',
            'service_areas.*.lat' => 'nullable|numeric|between:-90,90',
            'service_areas.*.latitude' => 'nullable|numeric|between:-90,90',
            'service_areas.*.lng' => 'nullable|numeric|between:-180,180',
            'service_areas.*.longitude' => 'nullable|numeric|between:-180,180',
            'service_areas.*.label' => 'nullable|string|max:255',
            'service_areas.*.radius_km' => 'nullable|numeric|min:0|max:2000',
            'service_areas.*.radius' => 'nullable|numeric|min:0|max:2000',
            'commission_rate' => 'sometimes|nullable|numeric|min:0|max:100',
            'minimum_order_amount' => 'sometimes|nullable|numeric|min:0',
            'delivery_radius_km' => 'sometimes|nullable|numeric|min:0|max:500',
            'bank_account_name' => 'required|string|max:100',
            'bank_account_number' => 'required|string|max:50',
            'bank_name' => 'required|string|max:100',
            'bank_branch' => 'sometimes|nullable|string|max:100',
            'business_hours' => 'sometimes|nullable|array',
            'social_links' => 'sometimes|nullable|array',
            'logo' => 'sometimes|file|max:2048|mimes:jpg,jpeg,png,webp',
            'cover_image' => 'sometimes|file|max:5120|mimes:jpg,jpeg,png,webp',
            'documents.*' => 'sometimes|file|max:5120|mimes:pdf,jpg,jpeg,png',
        ];
    }

    public function messages(): array
    {
        return [
            'business_name.required' => 'Business name is required',
            'business_type.required' => 'Business type is required',
            'business_phone.required' => 'Business phone number is required',
            'business_email.required' => 'Business email is required',
            'bank_account_name.required' => 'Bank account name is required',
            'bank_account_number.required' => 'Bank account number is required',
            'bank_name.required' => 'Bank name is required',
        ];
    }
}
