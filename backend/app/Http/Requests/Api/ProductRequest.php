<?php
// app/Http/Requests/Api/ProductRequest.php

namespace App\Http\Requests\Api;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class ProductRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        $rules = [
            'name' => 'required|string|max:255',
            'category' => 'required|string|max:100',
            'sub_category' => 'nullable|string|max:100',
            'description' => 'nullable|string|max:5000',
            'price_per_unit' => 'required|numeric|min:0',
            'unit' => 'required|in:ton,bag,cubic_meter,truck,trip,piece,block,sheet,meter,bucket',
            'minimum_order_quantity' => 'required|integer|min:1',
            'maximum_order_quantity' => 'nullable|integer|min:1',
            'is_available' => 'sometimes|boolean',
            'is_featured' => 'sometimes|boolean',
            'stock_quantity' => 'required|integer|min:0',
            'weight_kg' => 'nullable|numeric|min:0',
            'specifications' => 'nullable|array',
            'delivery_fee_per_km' => 'nullable|numeric|min:0',
            'preparation_time_minutes' => 'nullable|integer|min:0',
            'is_cod_available' => 'sometimes|boolean',
            'is_delivery_available' => 'sometimes|boolean',
            'site_id' => 'nullable|integer|exists:sites,id',
            // Bracketed `images[]` parts arrive as an array; a lone `images`
            // part arrives as a single file (both handled in the controller).
            'images' => 'nullable',
            'images.*' => 'file|image|max:5120|mimes:jpg,jpeg,png,webp',
            // JSON-encoded list of kept image URLs on update (multipart sends
            // it as a string; plain JSON may send a real array).
            'existing_images' => 'nullable',
            // Kept image URL, or "new:{index}" pointing at an uploaded file.
            'featured_image' => 'nullable|string|max:500',
        ];

        // For update, make fields optional
        if ($this->isMethod('PUT') || $this->isMethod('PATCH')) {
            $rules = array_map(function ($rule) {
                if (is_string($rule) && strpos($rule, 'required') === 0) {
                    return 'sometimes|' . str_replace('required|', '', $rule);
                }
                return $rule;
            }, $rules);
        }

        return $rules;
    }

    public function messages(): array
    {
        return [
            'name.required' => 'Product name is required',
            'category.required' => 'Product category is required',
            'price_per_unit.required' => 'Price is required',
            'price_per_unit.min' => 'Price must be greater than 0',
            'unit.required' => 'Unit of measurement is required',
            'minimum_order_quantity.required' => 'Minimum order quantity is required',
            'stock_quantity.required' => 'Stock quantity is required',
            'images.*.image' => 'Each file must be an image',
            'images.*.max' => 'Each image must be less than 5MB',
        ];
    }
}

