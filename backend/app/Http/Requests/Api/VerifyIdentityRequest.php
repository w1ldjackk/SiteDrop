<?php
// app/Http/Requests/Api/VerifyIdentityRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class VerifyIdentityRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'document' => 'required|file|max:5120|mimes:pdf,jpg,jpeg,png',
            'document_type' => 'required|string|in:passport,drivers_license,national_id,others',
            'document_number' => 'sometimes|string|max:50',
        ];
    }
}
