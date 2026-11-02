<?php

namespace Tests\Feature;

use App\Models\Permission;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Feature coverage for admin roles / permissions / user role assignment.
 * Uses sqlite in-memory (phpunit.xml); seeds minimal roles/permissions.
 */
class RolePermissionCrudTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        // Minimal permission tables may already exist via migrations.
        // Create core roles used by policies/middleware.
        $super = Role::findOrCreate('super-admin', 'web');
        Role::findOrCreate('admin', 'web');
        Role::findOrCreate('buyer', 'web');
        Role::findOrCreate('seller', 'web');

        $perm = Permission::findOrCreate('manage roles', 'web');
        $super->givePermissionTo($perm);

        $this->admin = User::factory()->create([
            'role' => 'super-admin',
            'email_verified_at' => now(),
        ]);
        $this->admin->assignRole('super-admin');
    }

    public function test_admin_can_create_permission(): void
    {
        $response = $this->actingAs($this->admin)->post('/admin/permissions', [
            'name' => 'test feature permission',
            'section' => 'Tests',
        ]);

        $response->assertRedirect('/admin/permissions');
        $this->assertDatabaseHas('permissions', [
            'name' => 'test feature permission',
            'guard_name' => 'web',
        ]);
    }

    public function test_admin_can_create_role_with_permissions(): void
    {
        $p1 = Permission::findOrCreate('view orders', 'web');
        $p2 = Permission::findOrCreate('edit orders', 'web');

        $response = $this->actingAs($this->admin)->post('/admin/roles', [
            'name' => 'ops-manager',
            'permissions' => [$p1->id, $p2->id],
        ]);

        $response->assertRedirect('/admin/roles');

        $role = Role::where('name', 'ops-manager')->first();
        $this->assertNotNull($role);
        $this->assertTrue($role->hasPermissionTo('view orders'));
        $this->assertTrue($role->hasPermissionTo('edit orders'));
    }

    public function test_admin_can_update_role_permissions(): void
    {
        $role = Role::findOrCreate('support', 'web');
        $old = Permission::findOrCreate('view users', 'web');
        $new = Permission::findOrCreate('edit users', 'web');
        $role->syncPermissions([$old]);

        $response = $this->actingAs($this->admin)->put("/admin/roles/{$role->id}", [
            'name' => 'support',
            'permissions' => [$new->id],
        ]);

        $response->assertRedirect("/admin/roles/{$role->id}");
        $role->refresh();
        $this->assertFalse($role->hasPermissionTo('view users'));
        $this->assertTrue($role->hasPermissionTo('edit users'));
    }

    public function test_assigning_primary_role_syncs_spatie_roles(): void
    {
        $user = User::factory()->create([
            'role' => 'buyer',
            'email_verified_at' => now(),
        ]);
        $user->assignRole('buyer');

        $response = $this->actingAs($this->admin)->put("/admin/users/{$user->id}", [
            'name' => $user->name,
            'email' => $user->email,
            'phone' => $user->phone,
            'role' => 'seller',
            'roles' => [], // empty chips — primary must still sync
            'password' => '',
        ]);

        $response->assertRedirect("/admin/users/{$user->id}");
        $user->refresh();
        $this->assertSame('seller', $user->role);
        $this->assertTrue($user->hasRole('seller'));
        $this->assertFalse($user->hasRole('buyer'));
    }

    public function test_protected_role_cannot_be_deleted(): void
    {
        $role = Role::where('name', 'super-admin')->firstOrFail();

        $response = $this->actingAs($this->admin)->delete("/admin/roles/{$role->id}");

        $response->assertForbidden();
        $this->assertDatabaseHas('roles', ['name' => 'super-admin']);
    }

    public function test_admin_can_delete_custom_role(): void
    {
        $role = Role::findOrCreate('temp-role', 'web');

        $response = $this->actingAs($this->admin)->delete("/admin/roles/{$role->id}");

        $response->assertRedirect('/admin/roles');
        $this->assertDatabaseMissing('roles', ['id' => $role->id]);
    }
}
