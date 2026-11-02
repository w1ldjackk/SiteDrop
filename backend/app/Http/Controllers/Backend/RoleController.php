<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Http\Requests\Role\StoreRoleRequest;
use App\Http\Requests\Role\UpdateRoleRequest;
use App\Models\Permission;
use App\Models\Role;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;

class RoleController extends Controller
{
    use AuthorizesRequests;

    public function index(Request $request): Response
    {
        $this->authorize('viewAny', Role::class);

        $query = Role::query()
            ->withCount(['permissions', 'users'])
            ->orderBy('name');

        if ($search = $request->input('search')) {
            $query->where('name', 'like', "%{$search}%");
        }

        $roles = $query->paginate(15)->withQueryString()->through(function (Role $role) {
            return [
                'id' => $role->id,
                'name' => $role->name,
                'guard_name' => $role->guard_name,
                'permissions_count' => $role->permissions_count,
                'users_count' => $role->users_count,
                'is_protected' => $role->isProtected(),
            ];
        });

        return Inertia::render('backend/Roles/index', [
            'roles' => $roles,
            'filters' => $request->only(['search']),
            'can' => [
                'create' => $request->user()->can('create', Role::class),
            ],
        ]);
    }

    public function create(): Response
    {
        $this->authorize('create', Role::class);

        $permissions = Permission::query()
            ->orderBy('section')
            ->orderBy('name')
            ->get(['id', 'name', 'section', 'guard_name']);

        return Inertia::render('backend/Roles/create', [
            'permissions' => $permissions,
        ]);
    }

    public function store(StoreRoleRequest $request): RedirectResponse
    {
        $this->authorize('create', Role::class);

        $role = Role::create([
            'name' => $request->validated('name'),
            'guard_name' => 'web',
        ]);

        $permissionIds = $this->normalizePermissionIds($request->validated('permissions') ?? []);
        if ($permissionIds !== []) {
            $role->syncPermissions(
                Permission::whereIn('id', $permissionIds)->get()
            );
        }

        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        ActivityLogger::log(
            ActivityActions::ROLE_CREATED,
            "Role \"{$role->name}\" created",
            $role,
            ['permissions' => $permissionIds],
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to('/admin/roles')
            ->with('success', 'Role created successfully.');
    }

    public function show(Role $role): Response
    {
        $this->authorize('view', $role);

        $role->load(['permissions:id,name,section,guard_name']);
        $users = $role->users()
            ->select(['users.id', 'users.name', 'users.email', 'users.phone'])
            ->limit(50)
            ->get()
            ->map(fn ($u) => [
                'id' => $u->id,
                'name' => $u->name,
                'email' => $u->email,
                'phone' => $u->phone,
            ]);

        return Inertia::render('backend/Roles/show', [
            'role' => [
                'id' => $role->id,
                'name' => $role->name,
                'guard_name' => $role->guard_name,
                'is_protected' => $role->isProtected(),
                'permissions' => $role->permissions->map(fn (Permission $p) => [
                    'id' => $p->id,
                    'name' => $p->name,
                    'section' => $p->section,
                    'guard_name' => $p->guard_name,
                ]),
                'users' => $users,
                'users_count' => $role->users()->count(),
            ],
            'can' => [
                'update' => Auth::user()->can('update', $role),
                'delete' => Auth::user()->can('delete', $role),
            ],
        ]);
    }

    public function edit(Role $role): Response
    {
        $this->authorize('update', $role);

        $role->load('permissions:id,name');

        $permissions = Permission::query()
            ->orderBy('section')
            ->orderBy('name')
            ->get(['id', 'name', 'section', 'guard_name']);

        return Inertia::render('backend/Roles/edit', [
            'role' => [
                'id' => $role->id,
                'name' => $role->name,
                'guard_name' => $role->guard_name,
                'is_protected' => $role->isProtected(),
            ],
            'permissions' => $permissions,
            // Force int IDs so frontend checkbox includes() matches
            'selected' => $role->permissions->pluck('id')->map(fn ($id) => (int) $id)->values()->all(),
        ]);
    }

    public function update(UpdateRoleRequest $request, Role $role): RedirectResponse
    {
        $this->authorize('update', $role);

        // Never rename protected roles
        if (! $role->isProtected()) {
            $role->update([
                'name' => $request->validated('name'),
            ]);
        }

        $permissionIds = $this->normalizePermissionIds($request->validated('permissions') ?? []);
        $role->syncPermissions(
            $permissionIds === []
                ? []
                : Permission::whereIn('id', $permissionIds)->get()
        );

        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        ActivityLogger::log(
            ActivityActions::ROLE_UPDATED,
            "Role \"{$role->name}\" updated",
            $role,
            ['permissions' => $permissionIds],
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to("/admin/roles/{$role->id}")
            ->with('success', 'Role updated successfully.');
    }

    /**
     * @param  array<int, mixed>  $ids
     * @return array<int, int>
     */
    private function normalizePermissionIds(array $ids): array
    {
        return array_values(array_unique(array_filter(array_map(
            static fn ($id) => is_numeric($id) ? (int) $id : null,
            $ids
        ))));
    }

    public function destroy(Role $role): RedirectResponse
    {
        $this->authorize('delete', $role);

        if ($role->isProtected()) {
            return back()->with('error', 'Cannot delete a protected system role.');
        }

        $name = $role->name;
        $role->delete();

        ActivityLogger::log(
            ActivityActions::ROLE_DELETED,
            "Role \"{$name}\" deleted",
            null,
            ['name' => $name],
            level: \App\Models\ActivityLog::LEVEL_WARNING,
            module: 'admin',
            userId: Auth::id(),
        );

        return redirect()
            ->to('/admin/roles')
            ->with('success', 'Role deleted successfully.');
    }

    public function bulkDelete(Request $request): RedirectResponse
    {
        $this->authorize('deleteAny', Role::class);

        $ids = $request->input('ids', []);

        Role::whereIn('id', $ids)
            ->whereNotIn('name', Role::PROTECTED)
            ->delete();

        return back()->with('success', 'Selected roles deleted.');
    }
}
