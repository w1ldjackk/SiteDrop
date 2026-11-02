<?php

namespace App\Http\Controllers;

use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;

/**
 * Legacy dashboard URLs → role home path.
 *
 * Role dashboards themselves live in routes/{role}.php and are gated by role.area.
 */
class RoleHomeController extends Controller
{
    /**
     * /dashboard and other legacy entry points → /admin, /buyer, /seller, …
     */
    public function legacyDashboard(Request $request): RedirectResponse
    {
        $user = $request->user();

        if (! $user) {
            return redirect()->route('login');
        }

        return redirect()->to($user->homePath());
    }
}
