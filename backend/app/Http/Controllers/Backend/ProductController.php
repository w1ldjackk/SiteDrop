<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Concerns\ScopesByRoleArea;
use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

class ProductController extends Controller
{
    use ScopesByRoleArea;

    public function index(Request $request): Response
    {
        $user = $request->user();
        $query = Product::query()
            ->with(['seller:id,name,email'])
            ->latest();

        $this->scopeProductsQuery($query, $user);

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('sku', 'like', "%{$search}%")
                    ->orWhere('category', 'like', "%{$search}%");
            });
        }

        if ($request->filled('available')) {
            $query->where('is_available', $request->boolean('available'));
        }

        if ($category = $request->input('category')) {
            $query->where('category', $category);
        }

        $products = $query->paginate((int) $request->input('per_page', 15))
            ->withQueryString()
            ->through(fn (Product $p) => [
                'id' => $p->id,
                'name' => $p->name,
                'sku' => $p->sku,
                'category' => $p->category,
                'price_per_unit' => (float) $p->price_per_unit,
                'unit' => $p->unit,
                'stock_quantity' => $p->stock_quantity,
                'is_available' => (bool) $p->is_available,
                'is_featured' => (bool) $p->is_featured,
                'avg_rating' => $p->avg_rating,
                'orders_count' => $p->orders_count,
                'seller' => $p->seller,
                'created_at' => optional($p->created_at)?->toDateTimeString(),
            ]);

        $categoriesQuery = Product::query()->whereNotNull('category');
        $this->scopeProductsQuery($categoriesQuery, $user);
        $categories = $categoriesQuery->distinct()->orderBy('category')->pluck('category');

        return Inertia::render('backend/Products/index', [
            'products' => $products,
            'filters' => $request->only(['search', 'available', 'category']),
            'categories' => $categories,
            'area' => $this->roleAreaPrefix($request),
        ]);
    }

    public function show(Request $request, int $id): Response
    {
        $user = $request->user();
        $product = Product::with(['seller:id,name,email,phone'])->findOrFail($id);

        if ($user && ! $this->isAdminPanelUser($user)) {
            if ($user->isSeller() && (int) $product->seller_id !== (int) $user->id) {
                abort(403);
            }
            if ($user->isBuyer() && ! $product->is_available) {
                abort(404);
            }
            if ($user->isDriver()) {
                abort(403);
            }
        }

        return Inertia::render('backend/Products/show', [
            'product' => $product,
            'area' => $this->roleAreaPrefix($request),
        ]);
    }
}
