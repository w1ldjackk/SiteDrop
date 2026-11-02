<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Restrict a route group to one or more app roles.
 *
 * - Guests → redirect to login (or 401 JSON)
 * - Authenticated but wrong role → 403
 *
 * Usage: middleware('role.area:buyer') or role.area:seller,driver
 */
class EnsureUserHasRole
{
    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        $user = $request->user();

        if (! $user) {
            if ($request->expectsJson() || $request->is('api/*')) {
                return response()->json([
                    'status' => 'error',
                    'message' => 'Unauthenticated.',
                ], 401);
            }

            return redirect()->guest(route('login'));
        }

        foreach ($roles as $role) {
            // Allow comma-separated lists from a single middleware arg
            foreach (explode(',', $role) as $single) {
                $single = trim($single);
                if ($single !== '' && $user->hasAppRole($single)) {
                    return $next($request);
                }
            }
        }

        $allowed = collect($roles)
            ->flatMap(fn (string $r) => explode(',', $r))
            ->map(fn (string $r) => trim($r))
            ->filter()
            ->unique()
            ->implode(', ');

        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'status' => 'error',
                'message' => "Forbidden. Required role: {$allowed}.",
            ], 403);
        }

        abort(403, "You do not have permission to access this area. Required role: {$allowed}.");
    }
}
