<?php
// app/Http/Requests/Api/UpdateDeliveryStatusRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateDeliveryStatusRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'status' => ['required', Rule::in([
                'picked_up',
                'in_transit',
                'arrived',
                'completed',
                'failed',
            ])],
            'notes' => 'required_if:status,failed|string|max:500',
            'signature' => 'nullable|string',
            'rating' => 'nullable|numeric|min:1|max:5',
            'comment' => 'nullable|string|max:500',
            'images' => 'nullable|array',
            'images.*' => 'file|image|max:5120',
        ];
    }

    public function messages(): array
    {
        return [
            'status.required' => 'Status is required',
            'status.in' => 'Invalid status',
            'notes.required_if' => 'Reason is required when marking as failed',
        ];
    }
}
