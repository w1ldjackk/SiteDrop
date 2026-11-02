<?php
// app/Http/Requests/Api/CheckoutRequest.php

namespace App\Http\Requests\Api;

use App\Constants\PaymentMethods;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CheckoutRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'delivery_address' => 'required|string|max:500',
            'delivery_phone' => 'nullable|string|max:20',
            'payment_method' => ['required', Rule::in(PaymentMethods::ALL)],
            'notes' => 'nullable|string|max:500',
            'latitude' => 'nullable|numeric|between:-90,90',
            'longitude' => 'nullable|numeric|between:-180,180',
            'delivery_scheduled_at' => 'nullable|date|after:now',

            // Mobile Money fields
            'phone_number' => 'required_if:payment_method,' . PaymentMethods::MOBILE_MONEY . '|string|max:20',
            'network' => 'required_if:payment_method,' . PaymentMethods::MOBILE_MONEY . '|string|in:MTN,Vodafone,AirtelTigo',

            // Card fields
            'card_token' => 'required_if:payment_method,' . PaymentMethods::CARD . '|string',
            'card_number' => 'required_if:payment_method,' . PaymentMethods::CARD . '|string|size:16',
            'card_expiry' => 'required_if:payment_method,' . PaymentMethods::CARD . '|string|regex:/^(0[1-9]|1[0-2])\/[0-9]{2}$/',
            'card_cvv' => 'required_if:payment_method,' . PaymentMethods::CARD . '|string|size:3',

            // Bank Transfer fields
            'bank_name' => 'required_if:payment_method,' . PaymentMethods::BANK_TRANSFER . '|string',
            'account_number' => 'required_if:payment_method,' . PaymentMethods::BANK_TRANSFER . '|string',
        ];
    }

    public function messages(): array
    {
        return [
            'delivery_address.required' => 'Delivery address is required',
            'payment_method.required' => 'Please select a payment method',
            'payment_method.in' => 'Invalid payment method selected',
            'phone_number.required_if' => 'Phone number is required for mobile money',
            'network.required_if' => 'Network is required for mobile money',
            'card_token.required_if' => 'Card token is required for card payment',
            'card_number.required_if' => 'Card number is required for card payment',
            'card_number.size' => 'Card number must be 16 digits',
            'card_expiry.required_if' => 'Card expiry date is required',
            'card_expiry.regex' => 'Card expiry must be in MM/YY format',
            'card_cvv.required_if' => 'CVV is required for card payment',
            'bank_name.required_if' => 'Bank name is required for bank transfer',
            'account_number.required_if' => 'Account number is required for bank transfer',
        ];
    }
}
