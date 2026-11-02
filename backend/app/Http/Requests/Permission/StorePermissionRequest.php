<?php

namespace App\Http\Requests\Permission;

use App\Models\Permission;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePermissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', Permission::class);
    }

    public function rules(): array
    {
        return [
            'name' => [
                'required',
                'string',
                'max:255',
                'regex:/^[a-zA-Z0-9-_ .]+$/',
                Rule::unique('permissions', 'name')
                    ->where('guard_name', 'web'),
            ],
            'section' => [
                'nullable',
                'string',
                'max:100',
            ],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Permission name is required.',
            'name.unique'   => 'This permission name already exists.',
            'name.regex'    => 'Permission name can only contain letters, numbers, hyphens, underscores, dots and spaces.',
            'section.max'   => 'Section name cannot be longer than 100 characters.',
        ];
    }

    protected function prepareForValidation()
    {
        // Optional: normalize name (trim, lowercase for consistency)
        if ($this->name) {
            $this->merge([
                'name' => trim($this->name),
            ]);
        }
    }
}
