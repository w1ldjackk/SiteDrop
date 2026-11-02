<?php

namespace App\Actions\Fortify;

use App\Concerns\PasswordValidationRules;
use App\Models\Role;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Laravel\Fortify\Contracts\CreatesNewUsers;

class CreateNewUser implements CreatesNewUsers
{
    use PasswordValidationRules;

    /**
     * Validate and create a newly registered user.
     *
     * @param  array<string, string>  $input
     */
    public function create(array $input): User
    {
        Validator::make($input, [
            'name' => ['required', 'string', 'max:255'],
            'phone' => ['required', 'string', 'unique:users,phone'],
            'phone_country' => ['nullable', 'string', 'max:5'],
            'email' => ['nullable', 'string', 'email', 'max:255', 'unique:users,email'],
            'role' => ['required', 'in:buyer,seller,driver,admin'],
            'password' => $this->passwordRules(),
        ])->validate();

        $roleName = $input['role'];

        // Ensure the custom Role model row exists for the web guard
        Role::findOrCreate($roleName, 'web');

        $user = User::create([
            'name' => $input['name'],
            'email' => $input['email'] ?? null,
            'phone' => $input['phone'],
            'phone_country' => $input['phone_country'] ?? 'GH',
            'password' => Hash::make($input['password']),
            'role' => $roleName, // mirrored; Spatie pivot is source of truth
            'phone_verified' => false,
        ]);

        $user->syncRoles([$roleName]);

        ActivityLogger::log(
            ActivityActions::AUTH_REGISTER,
            "New user registered (web): {$user->name} ({$roleName})",
            $user,
            [
                'roles' => [$roleName],
                'endpoint' => 'fortify/register',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return $user;
    }
}
