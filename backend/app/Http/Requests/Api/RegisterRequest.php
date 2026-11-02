<?php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;

class RegisterRequest extends FormRequest
{
    /**
     * Determine if the user is authorized to make this request.
     */
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Get the validation rules that apply to the user request.
     *
     * @return array<string, \Illuminate\Contracts\Validation\ValidationRule|array<mixed>|string>
     */
    public function rules(): array
    {
        return [
            'name'                  => ['required', 'string', 'max:255'],
            'phone'                 => ['required', 'string', 'unique:users,phone'],
            'email'                 => ['nullable', 'string', 'email', 'max:255', 'unique:users,email'],
            'phone_country'         => ['required', 'in:GH'],
            'password'              => ['required', 'string', 'min:8', 'confirmed'],
            'password_confirmation' => ['required', 'string'],
            'role'                  => ['required', 'in:buyer,seller,driver,admin'],
        ];
    }

    /**
     * Get custom error messages for validation failures.
     */
    public function messages(): array
    {
        return [
            'name.required'                  => 'Full name is required.',
            'phone.required'                 => 'Phone number is required.',
            'phone.unique'                  => 'This phone number is already registered.',
            'email.email'                   => 'Please enter a valid email address.',
            'password.min'                  => 'Password must be at least 8 characters.',
            'password.confirmed'            => 'The password confirmation does not match.',
            'password_confirmation.required' => 'Please confirm your password.',
            'role.required'                 => 'Please select your role.',
            'role.in'                       => 'Invalid role selected.',
        ];
    }
}
