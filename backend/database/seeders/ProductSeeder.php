<?php
// database/seeders/ProductSeeder.php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\Product;
use App\Models\User;
use App\Models\SellerProfile;
use Illuminate\Support\Str;

class ProductSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        $this->command->info('🌱 Seeding products...');

        // Get the seller user
        $seller = User::where('email', 'seller@sitedrop.gh')->first();

        if (!$seller) {
            $this->command->error('❌ Seller user not found. Please run PermissionSeederService first.');
            return;
        }

        // Check if seller has a seller profile
        $sellerProfile = SellerProfile::where('user_id', $seller->id)->first();
        if (!$sellerProfile) {
            $this->command->error('❌ Seller profile not found for seller@sitedrop.gh');
            return;
        }

        if ($sellerProfile->status !== 'approved') {
            $this->command->warn('⚠️ Seller profile is not approved. Products will still be created but may not be visible.');
        }

        // Define construction materials products
        $products = [
            // Sand Products
            [
                'name' => 'Sharp Sand - 1 Ton',
                'category' => 'sand',
                'sub_category' => 'building_sand',
                'description' => 'High-quality sharp sand perfect for plastering, bricklaying, and concrete works. Clean, well-graded, and free from impurities.',
                'price_per_unit' => 150.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 2,
                'maximum_order_quantity' => 50,
                'is_available' => true,
                'is_featured' => true,
                'images' => json_encode([
                    '/assets/img/seed/product-sharp-sand.png',
                ]),
                'specifications' => json_encode([
                    'type' => 'sharp_sand',
                    'grade' => 'construction_grade',
                    'color' => 'brownish_yellow',
                    'sieve_size' => '2mm',
                    'source' => 'River Bed',
                ]),
                'delivery_fee_per_km' => 5.00,
                'preparation_time_minutes' => 30,
                'weight_kg' => 1000,
                'stock_quantity' => 1000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
            [
                'name' => 'Plastering Sand - 1 Ton',
                'category' => 'sand',
                'sub_category' => 'plastering_sand',
                'description' => 'Fine, clean sand specifically for plastering and rendering works. Gives a smooth finish.',
                'price_per_unit' => 130.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 2,
                'maximum_order_quantity' => 40,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-plastering-sand.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'plastering_sand',
                    'grade' => 'fine_grade',
                    'color' => 'light_yellow',
                    'sieve_size' => '1mm',
                    'source' => 'River Bed',
                ]),
                'delivery_fee_per_km' => 5.00,
                'preparation_time_minutes' => 25,
                'weight_kg' => 1000,
                'stock_quantity' => 800,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Stone Products
            [
                'name' => 'Crushed Stones - 1/2 inch',
                'category' => 'stones',
                'sub_category' => 'crushed_stones',
                'description' => 'High-quality crushed stones for concrete works, foundations, and drainage. Perfect for construction projects.',
                'price_per_unit' => 200.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 1,
                'maximum_order_quantity' => 30,
                'is_available' => true,
                'is_featured' => true,
                'images' => json_encode([
                    '/assets/img/seed/product-crushed-stones.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'crushed_stone',
                    'size' => '1/2 inch',
                    'grade' => 'construction_grade',
                    'source' => 'Quarry',
                ]),
                'delivery_fee_per_km' => 6.00,
                'preparation_time_minutes' => 20,
                'weight_kg' => 1000,
                'stock_quantity' => 500,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
            [
                'name' => 'Crushed Stones - 3/4 inch',
                'category' => 'stones',
                'sub_category' => 'crushed_stones',
                'description' => 'Premium crushed stones for concrete and building foundations.',
                'price_per_unit' => 180.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 1,
                'maximum_order_quantity' => 25,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-crushed-stones-34.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'crushed_stone',
                    'size' => '3/4 inch',
                    'grade' => 'premium',
                    'source' => 'Quarry',
                ]),
                'delivery_fee_per_km' => 6.00,
                'preparation_time_minutes' => 20,
                'weight_kg' => 1000,
                'stock_quantity' => 400,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Gravel Products
            [
                'name' => 'Gravel - 3/4 inch',
                'category' => 'gravel',
                'sub_category' => 'gravel',
                'description' => 'Premium gravel for drainage, landscaping, and construction. Perfect for pathways and driveways.',
                'price_per_unit' => 180.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 2,
                'maximum_order_quantity' => 35,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-gravel.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'gravel',
                    'size' => '3/4 inch',
                    'grade' => 'premium',
                    'source' => 'Quarry',
                ]),
                'delivery_fee_per_km' => 5.00,
                'preparation_time_minutes' => 25,
                'weight_kg' => 1000,
                'stock_quantity' => 600,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
            [
                'name' => 'River Gravel - 1 inch',
                'category' => 'gravel',
                'sub_category' => 'river_gravel',
                'description' => 'Smooth river gravel for landscaping, drainage, and decorative purposes.',
                'price_per_unit' => 220.00,
                'unit' => 'ton',
                'minimum_order_quantity' => 2,
                'maximum_order_quantity' => 20,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-river-gravel.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'river_gravel',
                    'size' => '1 inch',
                    'grade' => 'premium',
                    'source' => 'River Bed',
                ]),
                'delivery_fee_per_km' => 6.00,
                'preparation_time_minutes' => 30,
                'weight_kg' => 1000,
                'stock_quantity' => 300,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Block Products
            [
                'name' => 'Cement Blocks - 6 inch',
                'category' => 'blocks',
                'sub_category' => 'cement_blocks',
                'description' => 'High-strength cement blocks for wall construction. Durable and weather-resistant.',
                'price_per_unit' => 12.00,
                'unit' => 'piece',
                'minimum_order_quantity' => 100,
                'maximum_order_quantity' => 2000,
                'is_available' => true,
                'is_featured' => true,
                'images' => json_encode([
                    '/assets/img/seed/product-cement-block.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'cement_block',
                    'size' => '6 inch',
                    'strength' => 'high_strength',
                    'dimensions' => '450mm x 225mm x 150mm',
                    'material' => 'cement_sand',
                ]),
                'delivery_fee_per_km' => 3.00,
                'preparation_time_minutes' => 45,
                'weight_kg' => 15,
                'stock_quantity' => 10000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
            [
                'name' => 'Cement Blocks - 8 inch',
                'category' => 'blocks',
                'sub_category' => 'cement_blocks',
                'description' => 'Heavy-duty 8-inch cement blocks for structural walls and foundations.',
                'price_per_unit' => 15.00,
                'unit' => 'piece',
                'minimum_order_quantity' => 100,
                'maximum_order_quantity' => 1500,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-cement-block-8.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'cement_block',
                    'size' => '8 inch',
                    'strength' => 'high_strength',
                    'dimensions' => '450mm x 225mm x 200mm',
                    'material' => 'cement_sand',
                ]),
                'delivery_fee_per_km' => 3.00,
                'preparation_time_minutes' => 45,
                'weight_kg' => 20,
                'stock_quantity' => 8000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Cement Products
            [
                'name' => 'Portland Cement - 50kg Bag',
                'category' => 'cement',
                'sub_category' => 'portland_cement',
                'description' => 'High-quality Portland cement for all construction needs. Meets international standards.',
                'price_per_unit' => 65.00,
                'unit' => 'bag',
                'minimum_order_quantity' => 10,
                'maximum_order_quantity' => 500,
                'is_available' => true,
                'is_featured' => true,
                'images' => json_encode([
                    '/assets/img/seed/product-cement.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'portland_cement',
                    'grade' => '42.5N',
                    'standards' => 'ASTM C150, EN 197-1',
                    'setting_time' => '45 minutes',
                ]),
                'delivery_fee_per_km' => 2.00,
                'preparation_time_minutes' => 15,
                'weight_kg' => 50,
                'stock_quantity' => 2000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Roofing Products
            [
                'name' => 'Roofing Sheets - Longspan',
                'category' => 'roofing',
                'sub_category' => 'roofing_sheets',
                'description' => 'Durable longspan roofing sheets with anti-corrosion coating.',
                'price_per_unit' => 85.00,
                'unit' => 'sheet',
                'minimum_order_quantity' => 20,
                'maximum_order_quantity' => 200,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-roofing.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'longspan',
                    'material' => 'galvanized_steel',
                    'thickness' => '0.6mm',
                    'coating' => 'anti_corrosion',
                    'color' => 'red',
                ]),
                'delivery_fee_per_km' => 4.00,
                'preparation_time_minutes' => 60,
                'weight_kg' => 25,
                'stock_quantity' => 500,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Pipe Products
            [
                'name' => 'PVC Pipes - 4 inch',
                'category' => 'plumbing',
                'sub_category' => 'pipes',
                'description' => 'Heavy-duty PVC pipes for plumbing and drainage systems.',
                'price_per_unit' => 45.00,
                'unit' => 'meter',
                'minimum_order_quantity' => 10,
                'maximum_order_quantity' => 500,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-pvc-pipes.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'pvc_pipe',
                    'size' => '4 inch',
                    'pressure' => 'Class 16',
                    'color' => 'white',
                ]),
                'delivery_fee_per_km' => 3.00,
                'preparation_time_minutes' => 20,
                'weight_kg' => 5,
                'stock_quantity' => 1000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Rebar/Steel Products
            [
                'name' => 'Rebar - 12mm',
                'category' => 'steel',
                'sub_category' => 'rebar',
                'description' => 'High-tensile rebar for reinforced concrete structures.',
                'price_per_unit' => 55.00,
                'unit' => 'piece',
                'minimum_order_quantity' => 50,
                'maximum_order_quantity' => 500,
                'is_available' => true,
                'is_featured' => true,
                'images' => json_encode([
                    '/assets/img/seed/product-rebar.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'rebar',
                    'size' => '12mm',
                    'grade' => '400',
                    'length' => '12 meters',
                ]),
                'delivery_fee_per_km' => 4.00,
                'preparation_time_minutes' => 30,
                'weight_kg' => 10,
                'stock_quantity' => 2000,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
            [
                'name' => 'Rebar - 16mm',
                'category' => 'steel',
                'sub_category' => 'rebar',
                'description' => 'Heavy-duty rebar for structural concrete works.',
                'price_per_unit' => 75.00,
                'unit' => 'piece',
                'minimum_order_quantity' => 50,
                'maximum_order_quantity' => 400,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-rebar-16mm.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'rebar',
                    'size' => '16mm',
                    'grade' => '400',
                    'length' => '12 meters',
                ]),
                'delivery_fee_per_km' => 4.00,
                'preparation_time_minutes' => 30,
                'weight_kg' => 16,
                'stock_quantity' => 1500,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],

            // Paint Products
            [
                'name' => 'Emulsion Paint - White 20L',
                'category' => 'paint',
                'sub_category' => 'emulsion',
                'description' => 'High-quality emulsion paint for interior and exterior walls.',
                'price_per_unit' => 250.00,
                'unit' => 'bucket',
                'minimum_order_quantity' => 1,
                'maximum_order_quantity' => 50,
                'is_available' => true,
                'is_featured' => false,
                'images' => json_encode([
                    '/assets/img/seed/product-paint.png'
                ]),
                'specifications' => json_encode([
                    'type' => 'emulsion_paint',
                    'color' => 'white',
                    'volume' => '20 liters',
                    'coverage' => '100 sqm',
                    'drying_time' => '24 hours',
                ]),
                'delivery_fee_per_km' => 3.00,
                'preparation_time_minutes' => 15,
                'weight_kg' => 25,
                'stock_quantity' => 100,
                'is_cod_available' => true,
                'is_delivery_available' => true,
                'views_count' => 0,
                'orders_count' => 0,
                'avg_rating' => 0,
            ],
        ];

        // Create or update products
        $createdCount = 0;
        $updatedCount = 0;

        foreach ($products as $productData) {
            // Generate SKU
            $productData['sku'] = $this->generateSku($productData['name'], $seller->id);

            // Add seller_id
            $productData['seller_id'] = $seller->id;

            // Check if product exists with same name and seller
            $existing = Product::where('seller_id', $seller->id)
                ->where('name', $productData['name'])
                ->first();

            if ($existing) {
                // Remove seller_id and sku from update (keep original)
                unset($productData['seller_id']);
                unset($productData['sku']);
                $existing->update($productData);
                $updatedCount++;
            } else {
                Product::create($productData);
                $createdCount++;
            }
        }

        $this->command->info('✅ Products seeded successfully!');
        $this->command->info("   - Created: {$createdCount} products");
        $this->command->info("   - Updated: {$updatedCount} products");
        $this->command->info("   - Total: " . count($products) . " products");

        // Display sample product categories
        $categories = Product::where('seller_id', $seller->id)
            ->select('category')
            ->distinct()
            ->pluck('category');

        $this->command->info("📦 Categories: " . $categories->implode(', '));
    }

    /**
     * Generate SKU for product
     */
    private function generateSku(string $name, int $sellerId): string
    {
        $prefix = strtoupper(substr(preg_replace('/[^a-zA-Z0-9]/', '', $name), 0, 3));
        $sellerCode = str_pad($sellerId, 3, '0', STR_PAD_LEFT);
        $random = strtoupper(Str::random(6));
        return $prefix . '-' . $sellerCode . '-' . $random;
    }
}
