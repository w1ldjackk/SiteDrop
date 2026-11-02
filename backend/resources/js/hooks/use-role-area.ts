// resources/js/hooks/use-role-area.ts
import { usePage } from '@inertiajs/react';
import { useCallback, useMemo } from 'react';
import type { SharedData } from '@/types';

export type RoleArea = 'admin' | 'buyer' | 'seller' | 'driver';

export const ROLE_AREAS: RoleArea[] = ['admin', 'buyer', 'seller', 'driver'];

function isRoleArea(value: string | null | undefined): value is RoleArea {
    return (
        value === 'admin' ||
        value === 'buyer' ||
        value === 'seller' ||
        value === 'driver'
    );
}

/** Pathname without query/hash, trailing slash stripped (except root). */
export function pathOnly(url: string): string {
    if (!url) return '';
    try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
            return new URL(url).pathname.replace(/\/+$/, '') || '/';
        }
        const path = url.split('?')[0].split('#')[0];
        return path.replace(/\/+$/, '') || '/';
    } catch {
        return url.split('?')[0].replace(/\/+$/, '') || '/';
    }
}

/**
 * Resolve the active role area from (in order):
 * 1. Explicit prop (from controllers)
 * 2. Current URL segment
 * 3. auth.home_path
 * 4. auth.role / auth.roles
 */
export function resolveRoleArea(
    pathname: string,
    homePath?: string | null,
    role?: string | null,
    roles?: string[] | null,
    explicit?: string | null,
): RoleArea {
    if (isRoleArea(explicit)) {
        return explicit;
    }

    const fromPath = pathOnly(pathname).match(
        /^\/(admin|buyer|seller|driver)(?:\/|$)/,
    );
    if (fromPath && isRoleArea(fromPath[1])) {
        return fromPath[1];
    }

    if (homePath) {
        const fromHome = pathOnly(homePath).match(
            /^\/(admin|buyer|seller|driver)(?:\/|$)/,
        );
        if (fromHome && isRoleArea(fromHome[1])) {
            return fromHome[1];
        }
    }

    const candidates = [role, ...(roles ?? [])].filter(Boolean) as string[];
    for (const raw of candidates) {
        const r = raw.toLowerCase().replace(/[_\s]+/g, '-');
        if (r === 'super-admin' || r === 'ops-manager' || r === 'admin') {
            return 'admin';
        }
        if (isRoleArea(r)) {
            return r;
        }
    }

    return 'admin';
}

/**
 * Build a path under a role area.
 * path('admin', 'orders', 5) → /admin/orders/5
 * path('buyer') → /buyer
 */
export function areaPath(
    area: RoleArea,
    ...segments: Array<string | number | null | undefined>
): string {
    const rest = segments
        .filter((s) => s !== null && s !== undefined && s !== '')
        .map((s) => String(s).replace(/^\/+|\/+$/g, ''))
        .filter(Boolean)
        .join('/');

    return rest ? `/${area}/${rest}` : `/${area}`;
}

export type UseRoleAreaResult = {
    /** admin | buyer | seller | driver */
    area: RoleArea;
    /** e.g. /buyer */
    base: string;
    /** Build area-scoped URLs: path('orders', id) → /buyer/orders/1 */
    path: (...segments: Array<string | number | null | undefined>) => string;
    isAdminArea: boolean;
    /** True when current path matches href (exact or prefix). */
    isActive: (href: string, exact?: boolean) => boolean;
};

/**
 * Hook for role-area URL helpers. Prefer controller `area` prop when present.
 */
export function useRoleArea(areaProp?: string | null): UseRoleAreaResult {
    const page = usePage<SharedData>();
    const { auth } = page.props;

    const pathname = useMemo(() => {
        if (typeof window !== 'undefined') {
            return window.location.pathname;
        }
        return pathOnly(page.url || '');
    }, [page.url]);

    const area = useMemo(
        () =>
            resolveRoleArea(
                pathname,
                auth?.home_path,
                auth?.role ?? auth?.user?.role,
                auth?.roles,
                areaProp,
            ),
        [
            pathname,
            auth?.home_path,
            auth?.role,
            auth?.user?.role,
            auth?.roles,
            areaProp,
        ],
    );

    const base = `/${area}`;

    const path = useCallback(
        (...segments: Array<string | number | null | undefined>): string =>
            areaPath(area, ...segments),
        [area],
    );

    const isActive = useCallback(
        (href: string, exact = false): boolean => {
            const target = pathOnly(href);
            const current = pathOnly(pathname);

            if (exact || target === base) {
                return current === target;
            }

            return current === target || current.startsWith(`${target}/`);
        },
        [pathname, base],
    );

    return {
        area,
        base,
        path,
        isAdminArea: area === 'admin',
        isActive,
    };
}
