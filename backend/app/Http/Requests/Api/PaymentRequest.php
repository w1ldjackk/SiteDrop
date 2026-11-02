<?php
// app/Http/Requests/Api/PaymentRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class PaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $rules = [
            'order_id' => 'required|exists:orders,id',
            'payment_method' => ['required', Rule::in(['mobile_money', 'card', 'bank_transfer', 'wallet'])],
        ];

        // Mobile money specific fields
        if ($this->payment_method === 'mobile_money') {
            $rules['phone_number'] = 'required|string|max:20';
            $rules['network'] = ['required', Rule::in(['MTN', 'Vodafone', 'AirtelTigo'])];
        }

        // Card payment specific fields
        if ($this->payment_method === 'card') {
            $rules['card_token'] = 'sometimes|string';
            $rules['authorization_code'] = 'sometimes|string';
        }

        return $rules;
    }

    public function messages(): array
    {
        return [
            'order_id.required' => 'Order ID is required',
            'order_id.exists' => 'Order not found',
            'payment_method.required' => 'Payment method is required',
            'payment_method.in' => 'Invalid payment method',
            'phone_number.required' => 'Phone number is required for mobile money',
            'network.required' => 'Network is required for mobile money',
            'network.in' => 'Invalid network selected',
        ];
    }
}
