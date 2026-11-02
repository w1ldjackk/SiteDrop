// resources/js/hooks/usePermissions.ts
import { usePage } from '@inertiajs/react';
import type { SharedData } from '@/types';

export const usePermissions = () => {
    const { auth } = usePage<SharedData>().props;
    const permissions = auth?.permissions ?? [];
    const roles = auth?.roles ?? [];
    const primary = auth?.role ?? null;

    /** Only super-admin bypasses every permission check */
    const isSuperAdmin =
        roles.includes('super-admin') || primary === 'super-admin';

    const isAdmin =
        isSuperAdmin || roles.includes('admin') || primary === 'admin';

    const can = (permission: string): boolean => {
        if (!permission) return false;
        if (isSuperAdmin) return true;
        return permissions.includes(permission);
    };

    /** True if the user has any of the given permissions. */
    const canAny = (...perms: string[]): boolean => {
        if (perms.length === 0) return true;
        if (isSuperAdmin) return true;
        return perms.some((p) => permissions.includes(p));
    };

    /** True if the user has all of the given permissions. */
    const canAll = (...perms: string[]): boolean => {
        if (perms.length === 0) return true;
        if (isSuperAdmin) return true;
        return perms.every((p) => permissions.includes(p));
    };

    const hasRole = (role: string): boolean => {
        return roles.includes(role) || primary === role;
    };

    return {
        can,
        canAny,
        canAll,
        hasRole,
        permissions,
        roles,
        isSuperAdmin,
        isAdmin,
    };
};
