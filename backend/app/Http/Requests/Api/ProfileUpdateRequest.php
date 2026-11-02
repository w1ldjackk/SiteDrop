<?php
// app/Http/Requests/Api/ProfileUpdateRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProfileUpdateRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'name' => 'sometimes|string|max:255',
            'first_name' => 'sometimes|string|max:100',
            'last_name' => 'sometimes|string|max:100',
            'date_of_birth' => 'sometimes|date|before:today|after:1900-01-01',
            'gender' => ['sometimes', Rule::in(['male', 'female', 'other', 'prefer_not_to_say'])],
            'alternate_phone' => 'sometimes|string|max:20',
            'address' => 'sometimes|string|max:500',
            'coordinates' => 'sometimes|array',
            'coordinates.lat' => 'required_with:coordinates|numeric|between:-90,90',
            'coordinates.lng' => 'required_with:coordinates|numeric|between:-180,180',
            'bio' => 'sometimes|string|max:1000',
            'nationality' => 'sometimes|string|max:100',
            'occupation' => 'sometimes|string|max:100',
            'company' => 'sometimes|string|max:100',
            'emergency_contact_name' => 'sometimes|string|max:100',
            'emergency_contact_phone' => 'sometimes|string|max:20',
            'emergency_contact_relationship' => 'sometimes|string|max:50',
            'preferences' => 'sometimes|array',
            'social_links' => 'sometimes|array',
            'social_links.facebook' => 'sometimes|url|nullable',
            'social_links.twitter' => 'sometimes|url|nullable',
            'social_links.instagram' => 'sometimes|url|nullable',
            'social_links.linkedin' => 'sometimes|url|nullable',
        ];
    }
}
