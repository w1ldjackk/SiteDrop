<?php

namespace App\Http\Controllers\Api\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\RegisterRequest;
use App\Models\Role;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use App\Traits\NormalizesGhanaPhone;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Hash;

class RegisterController extends Controller
{
    use AuthorizesRequests;
    use NormalizesGhanaPhone;

    public function register(RegisterRequest $request): JsonResponse
    {
        $phone = $request->phone;

        // === Smart normalization for Ghana users (works even if user typed 0 or forgot country code) ===
        if ($request->phone_country === 'GH') {
            $normalizedPhone = $this->normalizeGhanaPhone($phone);
            $request->merge(['phone' => $normalizedPhone]);
        }

        $roleName = $request->role ?: 'buyer';
        Role::findOrCreate($roleName, 'web');

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'phone' => $request->phone, // always saved as 233...
            'phone_country' => 'GH',
            'phone_verified' => false,
            'role' => $roleName, // mirrored; Spatie pivot is source of truth
            'password' => Hash::make($request->password),
        ]);

        $user->syncRoles([$roleName]);

        $token = $user->createToken('sitedrop-auth-token')->plainTextToken;

        ActivityLogger::log(
            ActivityActions::AUTH_REGISTER,
            "New user registered: {$user->name} ({$roleName})",
            $user,
            [
                'roles' => [$roleName],
                'phone' => $user->phone,
                'endpoint' => 'auth/register',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return $this->success(
            message: 'Account created successfully',
            status: 201,
            extra: [
                'user' => array_merge(
                    $user->only(['id', 'name', 'email', 'phone', 'phone_verified']),
                    [
                        'role' => $user->primaryRoleName(),
                        'roles' => $user->getRoleNames()->values()->all(),
                    ]
                ),
                'token' => $token,
            ],
        );
    }
}
