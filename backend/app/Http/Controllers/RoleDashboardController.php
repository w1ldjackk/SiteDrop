<?php

namespace App\Http\Controllers;

use App\Enums\UserRole;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Role-area dashboard homes (buyer / seller / driver).
 * Ops-manager uses the admin dashboard (admin.php).
 */
class RoleDashboardController extends Controller
{
    public function buyer(Request $request): Response
    {
        return $this->render($request, UserRole::Buyer);
    }

    public function seller(Request $request): Response
    {
        return $this->render($request, UserRole::Seller);
    }

    public function driver(Request $request): Response
    {
        return $this->render($request, UserRole::Driver);
    }

    private function render(Request $request, UserRole $role): Response
    {
        $user = $request->user();
        $slug = $role->value;

        $page = match ($role) {
            UserRole::Buyer => 'dashboard/buyer',
            UserRole::Seller => 'dashboard/seller',
            UserRole::Driver => 'dashboard/driver',
            default => 'dashboard/role',
        };

        $viewPath = resource_path('js/pages/'.$page.'.tsx');
        if (! is_file($viewPath)) {
            $page = 'dashboard/role';
        }

        return Inertia::render($page, [
            'role' => $slug,
            'area' => $slug,
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'roles' => $user->getRoleNames()->values()->all(),
            ],
        ]);
    }
}
