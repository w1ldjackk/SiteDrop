<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Inertia\Inertia;
use Inertia\Response;
use Spatie\Permission\PermissionRegistrar;

class UserController extends Controller
{
    use AuthorizesRequests;

    /**
     * Assign Spatie roles (App\Models\Role) and mirror the first role onto users.role
     * for legacy readers (API payloads, dashboards). No separate "primary" role.
     *
     * @param  array<int, string>  $roleNames
     */
    private function syncRoles(User $user, array $roleNames): void
    {
        $names = array_values(array_unique(array_filter(array_map(
            static fn ($r) => is_string($r) ? trim($r) : '',
            $roleNames
        ))));

        $keepSuper = $user->isSuperAdmin();

        // Block elevating non–super-admins to super-admin via the form
        if (! $keepSuper) {
            $names = array_values(array_filter(
                $names,
                static fn (string $n) => $n !== 'super-admin'
            ));
        } elseif (! in_array('super-admin', $names, true)) {
            // Never strip super-admin from an existing super-admin
            $names[] = 'super-admin';
        }

        // Only roles that exist on the web guard (custom Role model / Spatie config)
        $existing = Role::query()
            ->where('guard_name', 'web')
            ->whereIn('name', $names)
            ->orderBy('name')
            ->pluck('name')
            ->all();

        // Preserve request order where possible
        $ordered = array_values(array_filter(
            $names,
            static fn (string $n) => in_array($n, $existing, true)
        ));

        $user->syncRoles($ordered);

        // Denormalized column for older code paths that still read users.role
        $mirror = $keepSuper
            ? 'super-admin'
            : ($ordered[0] ?? null);

        if ($mirror !== null && $user->role !== $mirror) {
            $user->forceFill(['role' => $mirror])->saveQuietly();
        }

        app(PermissionRegistrar::class)->forgetCachedPermissions();
    }

    /**
     * @return array<int, string>
     */
    private function availableRoleNames(bool $excludeSuperAdmin = true): array
    {
        $query = Role::query()->where('guard_name', 'web')->orderBy('name');

        if ($excludeSuperAdmin) {
            $query->where('name', '!=', 'super-admin');
        }

        return $query->pluck('name')->all();
    }

    public function index(Request $request): Response
    {
        $this->authorize('viewAny', User::class);

        $query = User::query()
            ->with(['roles:id,name'])
            ->select([
                'id',
                'name',
                'email',
                'phone',
                'role',
                'phone_verified',
                'last_active_at',
                'created_at',
            ])
            ->latest();

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        if ($role = $request->input('role')) {
            $query->where(function ($q) use ($role) {
                $q->where('role', $role)
                    ->orWhereHas('roles', fn ($r) => $r->where('name', $role));
            });
        }

        $users = $query->paginate(15)->withQueryString()->through(function (User $user) {
            $roles = $user->roles->pluck('name')->values()->all();

            return [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                // Convenience: first Spatie role (or mirrored column)
                'role' => $roles[0] ?? $user->role,
                'roles' => $roles,
                'phone_verified' => (bool) $user->phone_verified,
                'last_active_at' => optional($user->last_active_at)?->toDateTimeString(),
                'created_at' => optional($user->created_at)?->toDateTimeString(),
                'avatar_url' => 'https://ui-avatars.com/api/?name='.urlencode($user->name).'&background=random',
            ];
        });

        $auth = $request->user();

        return Inertia::render('backend/Users/index', [
            'users' => $users,
            'filters' => $request->only(['search', 'role']),
            'roles' => $this->availableRoleNames(excludeSuperAdmin: false),
            'can' => [
                'create' => $auth->can('create', User::class),
                'impersonate' => $auth->can('impersonate', User::class),
            ],
        ]);
    }

    public function create(): Response
    {
        $this->authorize('create', User::class);

        return Inertia::render('backend/Users/create', [
            'roles' => $this->availableRoleNames(),
        ]);
    }

    public function store(Request $request): RedirectResponse
    {
        $this->authorize('create', User::class);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255', 'unique:users,email'],
            'phone' => ['nullable', 'string', 'max:30'],
            'password' => ['required', 'string', 'min:6'],
            'roles' => ['required', 'array', 'min:1'],
            'roles.*' => [
                'string',
                Rule::exists('roles', 'name')->where(fn ($q) => $q->where('guard_name', 'web')),
            ],
        ]);

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'] ?? null,
            'phone' => $data['phone'] ?? null,
            'password' => Hash::make($data['password']),
            // Temporary; syncRoles overwrites with first assigned role
            'role' => $data['roles'][0] ?? 'buyer',
        ]);

        $this->syncRoles($user, $data['roles']);

        ActivityLogger::log(
            ActivityActions::USER_CREATED,
            "Admin created user {$user->name}",
            $user,
            ['roles' => $user->getRoleNames()->all()],
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/users/{$user->id}")
            ->with('success', 'User account created successfully.');
    }

    public function show(Request $request, $id): Response
    {
        $user = User::with(['roles:id,name'])->findOrFail($id);
        $this->authorize('view', $user);

        $roles = $user->roles->pluck('name')->values()->all();

        return Inertia::render('backend/Users/show', [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $roles[0] ?? $user->role,
                'phone_verified' => (bool) $user->phone_verified,
                'last_active_at' => optional($user->last_active_at)?->toDateTimeString(),
                'created_at' => optional($user->created_at)?->toDateTimeString(),
                'roles' => $roles,
                'avatar_url' => 'https://ui-avatars.com/api/?name='.urlencode($user->name).'&background=random',
            ],
            'can' => [
                'update' => $request->user()->can('update', $user),
                'delete' => $request->user()->can('delete', $user) && $user->id !== Auth::id(),
            ],
        ]);
    }

    public function edit(Request $request, $id): Response
    {
        $user = User::with('roles:id,name')->findOrFail($id);
        $this->authorize('update', $user);

        $roles = $user->roles->pluck('name')->values()->all();

        return Inertia::render('backend/Users/edit', [
            'user' => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'roles' => $roles,
            ],
            'roles' => $this->availableRoleNames(excludeSuperAdmin: ! $user->isSuperAdmin()),
        ]);
    }

    public function update(Request $request, $id): RedirectResponse
    {
        $user = User::findOrFail($id);
        $this->authorize('update', $user);

        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['nullable', 'email', 'max:255', Rule::unique('users', 'email')->ignore($user->id)],
            'phone' => ['nullable', 'string', 'max:30'],
            'password' => ['nullable', 'string', 'min:6'],
            'roles' => ['required', 'array', 'min:1'],
            'roles.*' => [
                'string',
                Rule::exists('roles', 'name')->where(fn ($q) => $q->where('guard_name', 'web')),
            ],
        ]);

        $user->name = $data['name'];
        $user->email = $data['email'] ?? $user->email;
        $user->phone = $data['phone'] ?? $user->phone;
        if (! empty($data['password'])) {
            $user->password = Hash::make($data['password']);
        }
        $user->save();

        $this->syncRoles($user, $data['roles']);

        ActivityLogger::log(
            ActivityActions::USER_UPDATED,
            "Admin updated user {$user->name}",
            $user,
            ['roles' => $user->fresh()->getRoleNames()->all()],
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/users/{$user->id}")
            ->with('success', 'User account updated successfully.');
    }

    public function destroy($id): RedirectResponse
    {
        $user = User::findOrFail($id);
        $this->authorize('delete', $user);

        if ($user->id === Auth::id() || $user->isSuperAdmin()) {
            return back()->with('error', 'You cannot delete this account.');
        }

        $name = $user->name;
        $userId = $user->id;
        $user->delete();

        ActivityLogger::log(
            ActivityActions::USER_DELETED,
            "Admin deleted user {$name}",
            null,
            ['user_id' => $userId, 'name' => $name],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to('/admin/users')
            ->with('success', 'User account deleted successfully.');
    }

    public function bulkAction(Request $request): RedirectResponse
    {
        $this->authorize('deleteAny', User::class);

        $ids = $request->input('ids', []);
        $action = $request->input('action', 'delete');

        if ($action === 'delete') {
            $count = User::whereIn('id', $ids)
                ->where('id', '!=', Auth::id())
                ->whereDoesntHave('roles', fn ($q) => $q->where('name', 'super-admin'))
                ->where(function ($q) {
                    $q->whereNull('role')->orWhere('role', '!=', 'super-admin');
                })
                ->delete();

            return back()->with('success', "{$count} user account(s) deleted.");
        }

        return back();
    }

    public function impersonate(Request $request, $id): RedirectResponse
    {
        $target = User::findOrFail($id);
        $this->authorize('impersonate', $target);

        session(['impersonate_original_id' => Auth::id()]);
        Auth::login($target);
        session()->flash('success', "You are now logged in as: {$target->name}");

        return redirect('/admin');
    }
}
