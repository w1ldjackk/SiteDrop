<?php
// app/Http/Requests/Api/AssignDriverRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class AssignDriverRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'delivery_id' => 'required|exists:deliveries,id',
            'driver_id' => 'required|exists:users,id',
            'vehicle_id' => 'nullable|exists:trucks,id',
            'notes' => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'delivery_id.required' => 'Delivery ID is required',
            'driver_id.required' => 'Driver ID is required',
            'driver_id.exists' => 'Driver not found',
        ];
    }
}
