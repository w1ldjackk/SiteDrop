// resources/js/hooks/useRole.ts
import { usePage } from '@inertiajs/react';
import type { SharedData } from '@/types';

export const useRole = () => {
    const { auth } = usePage<SharedData>().props;
    // Source of truth: Spatie roles shared from HandleInertiaRequests
    const roles = auth?.roles ?? [];
    const primary = roles[0] ?? auth?.role ?? null;

    const isSuperAdmin = () => roles.includes('super-admin');

    const isAdmin = () => isSuperAdmin() || roles.includes('admin');

    const can = (permission: string): boolean => {
        if (isSuperAdmin()) return true;
        return auth?.permissions?.includes(permission) ?? false;
    };

    const hasRole = (role: string) => roles.includes(role);

    return { isSuperAdmin, isAdmin, can, hasRole, roles, primary };
};
