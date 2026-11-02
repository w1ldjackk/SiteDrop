<?php
// app/Http/Requests/Api/CreateOrderRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class CreateOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'delivery_address' => 'required|string|max:500',
            'delivery_coordinates' => 'sometimes|array',
            'delivery_coordinates.lat' => 'required_with:delivery_coordinates|numeric|between:-90,90',
            'delivery_coordinates.lng' => 'required_with:delivery_coordinates|numeric|between:-180,180',
            'special_instructions' => 'nullable|string|max:500',
            'delivery_scheduled_at' => 'nullable|date|after:now',
            'payment_method' => 'required|in:mobile_money,bank_transfer,card,wallet,cash',
            'payment_provider' => 'nullable|string|in:hubtel,paystack',
        ];
    }

    public function messages(): array
    {
        return [
            'delivery_address.required' => 'Delivery address is required',
            'payment_method.required' => 'Please select a payment method',
            'payment_method.in' => 'Invalid payment method selected',
            'delivery_scheduled_at.after' => 'Delivery schedule must be in the future',
        ];
    }
}
