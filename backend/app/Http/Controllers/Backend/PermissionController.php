<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Http\Requests\Permission\StorePermissionRequest;
use App\Http\Requests\Permission\UpdatePermissionRequest;
use App\Models\Permission;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;

class PermissionController extends Controller
{
    use AuthorizesRequests;

    public function index(Request $request): Response
    {
        $this->authorize('viewAny', Permission::class);

        $query = Permission::query()
            ->withCount('roles')
            ->orderBy('section')
            ->orderBy('name');

        if ($search = $request->input('search')) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('section', 'like', "%{$search}%");
            });
        }

        if ($section = $request->input('section')) {
            $query->where('section', $section);
        }

        $permissions = $query->paginate(20)->withQueryString()->through(function (Permission $p) {
            return [
                'id' => $p->id,
                'name' => $p->name,
                'section' => $p->section ?: 'General',
                'guard_name' => $p->guard_name,
                'roles_count' => $p->roles_count,
            ];
        });

        $sections = Permission::query()
            ->whereNotNull('section')
            ->distinct()
            ->orderBy('section')
            ->pluck('section');

        return Inertia::render('backend/Permissions/index', [
            'permissions' => $permissions,
            'filters' => $request->only(['search', 'section']),
            'sections' => $sections,
            'can' => [
                'create' => $request->user()->can('create', Permission::class),
            ],
        ]);
    }

    public function create(): Response
    {
        $this->authorize('create', Permission::class);

        $sections = Permission::query()
            ->whereNotNull('section')
            ->distinct()
            ->orderBy('section')
            ->pluck('section');

        return Inertia::render('backend/Permissions/create', [
            'sections' => $sections,
        ]);
    }

    public function store(StorePermissionRequest $request): RedirectResponse
    {
        $this->authorize('create', Permission::class);

        $data = $request->validated();

        Permission::create([
            'name' => $data['name'],
            'section' => $data['section'] ?? 'General',
            'guard_name' => 'web',
        ]);

        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        return redirect()
            ->to('/admin/permissions')
            ->with('success', 'Permission created successfully.');
    }

    public function show(Permission $permission): Response
    {
        $this->authorize('view', $permission);

        $permission->load('roles:id,name,guard_name');
        $permission->loadCount('roles');

        return Inertia::render('backend/Permissions/show', [
            'permission' => [
                'id' => $permission->id,
                'name' => $permission->name,
                'section' => $permission->section ?: 'General',
                'guard_name' => $permission->guard_name,
                'roles_count' => $permission->roles_count,
                'roles' => $permission->roles->map(fn ($r) => [
                    'id' => $r->id,
                    'name' => $r->name,
                    'guard_name' => $r->guard_name,
                ]),
            ],
            'can' => [
                'update' => Auth::user()->can('update', $permission),
                'delete' => Auth::user()->can('delete', $permission),
            ],
        ]);
    }

    public function edit(Permission $permission): Response
    {
        $this->authorize('update', $permission);

        $sections = Permission::query()
            ->whereNotNull('section')
            ->distinct()
            ->orderBy('section')
            ->pluck('section');

        return Inertia::render('backend/Permissions/edit', [
            'permission' => [
                'id' => $permission->id,
                'name' => $permission->name,
                'section' => $permission->section ?: 'General',
                'guard_name' => $permission->guard_name,
            ],
            'sections' => $sections,
        ]);
    }

    public function update(UpdatePermissionRequest $request, Permission $permission): RedirectResponse
    {
        $this->authorize('update', $permission);

        $data = $request->validated();
        $permission->update([
            'name' => $data['name'],
            'section' => $data['section'] ?? $permission->section,
        ]);

        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        return redirect()
            ->to("/admin/permissions/{$permission->id}")
            ->with('success', 'Permission updated successfully.');
    }

    public function destroy(Permission $permission): RedirectResponse
    {
        $this->authorize('delete', $permission);

        $permission->delete();

        app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

        return redirect()
            ->to('/admin/permissions')
            ->with('success', 'Permission deleted successfully.');
    }

    public function bulkDelete(Request $request): RedirectResponse
    {
        $this->authorize('deleteAny', Permission::class);

        $ids = $request->input('ids', []);
        Permission::whereIn('id', $ids)->delete();

        return back()->with('success', 'Selected permissions deleted.');
    }
}
