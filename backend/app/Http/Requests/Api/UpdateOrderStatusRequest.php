<?php
// app/Http/Requests/Api/UpdateOrderStatusRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateOrderStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([
                'confirmed',
                'processing',
                'ready_for_delivery',
                'in_transit',
                'delivered',
                'completed',
                'cancelled'
            ])],
            'reason' => 'required_if:status,cancelled|string|max:500',
            'notes' => 'nullable|string|max:500',
        ];
    }

    public function messages(): array
    {
        return [
            'status.required' => 'Status is required',
            'status.in' => 'Invalid status value',
            'reason.required_if' => 'Reason is required when cancelling',
        ];
    }
}
