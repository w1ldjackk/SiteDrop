// resources/js/lib/role-nav.ts
import {
    LayoutDashboard,
    Users,
    Truck,
    Package,
    ShoppingCart,
    DollarSign,
    BarChart3,
    Settings,
    ShieldCheck,
    Store,
    BookOpen,
    MessageSquare,
    ScrollText,
    Activity,
    Star,
    Bell,
    ListOrdered,
    type LucideIcon,
} from 'lucide-react';
import type { RoleArea } from '@/hooks/use-role-area';
import { areaPath } from '@/hooks/use-role-area';

export type NavLink = {
    title: string;
    href: string;
    icon: LucideIcon;
    /** Match only exact path (e.g. dashboard /admin) */
    exact?: boolean;
    /**
     * Show link if user has ANY of these permissions.
     * Empty / omitted = always visible for this area (still section-filtered).
     * For non-admin areas we typically omit permissions.
     */
    permissions?: string[];
};

export type NavSection = {
    title: string;
    items: NavLink[];
    collapsible?: boolean;
    permissions?: string[];
};

function adminNav(): NavSection[] {
    return [
        {
            title: 'Overview',
            collapsible: false,
            permissions: ['view dashboard', 'manage admin'],
            items: [
                {
                    title: 'Dashboard',
                    href: areaPath('admin'),
                    icon: LayoutDashboard,
                    exact: true,
                    permissions: ['view dashboard', 'manage admin'],
                },
            ],
        },
        {
            title: 'Operations',
            collapsible: true,
            permissions: [
                'view sellers',
                'manage sellers',
                'view orders',
                'manage orders',
                'view deliveries',
                'manage deliveries',
                'view products',
                'manage products',
                'view trucks',
                'manage trucks',
            ],
            items: [
                {
                    title: 'Sellers',
                    href: areaPath('admin', 'sellers'),
                    icon: Store,
                    permissions: [
                        'view sellers',
                        'manage sellers',
                        'create sellers',
                        'edit sellers',
                        'approve sellers',
                        'view seller documents',
                    ],
                },
                {
                    title: 'Orders',
                    href: areaPath('admin', 'orders'),
                    icon: ShoppingCart,
                    permissions: [
                        'view orders',
                        'manage orders',
                        'create orders',
                        'edit orders',
                        'process orders',
                        'delete orders',
                    ],
                },
                {
                    title: 'Deliveries',
                    href: areaPath('admin', 'deliveries'),
                    icon: Truck,
                    permissions: [
                        'view deliveries',
                        'manage deliveries',
                        'assign deliveries',
                    ],
                },
                {
                    title: 'Products',
                    href: areaPath('admin', 'products'),
                    icon: Package,
                    permissions: ['view products', 'manage products'],
                },
                {
                    title: 'Trucks & Drivers',
                    href: areaPath('admin', 'trucks'),
                    icon: Truck,
                    permissions: ['view trucks', 'manage trucks'],
                },
            ],
        },
        {
            title: 'Finance',
            collapsible: true,
            permissions: [
                'view payments',
                'manage payments',
                'view reports',
                'view financial reports',
                'export reports',
                'view analytics',
            ],
            items: [
                {
                    title: 'Payments',
                    href: areaPath('admin', 'payments'),
                    icon: DollarSign,
                },
                {
                    title: 'Wallets',
                    href: areaPath('admin', 'wallets'),
                    icon: DollarSign,
                    permissions: [
                        'view payments',
                        'manage payments',
                        'process payments',
                        'refund payments',
                    ],
                },
                {
                    title: 'Reports',
                    href: areaPath('admin', 'reports'),
                    icon: BarChart3,
                    permissions: [
                        'view reports',
                        'view financial reports',
                        'export reports',
                    ],
                },
                {
                    title: 'Analytics',
                    href: areaPath('admin', 'analytics'),
                    icon: Activity,
                    permissions: ['view analytics', 'view dashboard'],
                },
            ],
        },
        {
            title: 'Insights',
            collapsible: false,
            permissions: [
                'view activity logs',
                'delete activity logs',
                'view reviews',
                'moderate reviews',
            ],
            items: [
                {
                    title: 'Activity Logs',
                    href: areaPath('admin', 'activity-logs'),
                    icon: ScrollText,
                    permissions: ['view activity logs', 'delete activity logs'],
                },
                {
                    title: 'Reviews',
                    href: areaPath('admin', 'reviews'),
                    icon: Star,
                    permissions: [
                        'view reviews',
                        'moderate reviews',
                        'delete reviews',
                    ],
                },
            ],
        },
        {
            title: 'System',
            collapsible: true,
            permissions: [
                'manage roles',
                'manage permissions',
                'view users',
                'manage users',
                'manage settings',
                'manage admin',
            ],
            items: [
                {
                    title: 'Roles',
                    href: areaPath('admin', 'roles'),
                    icon: ShieldCheck,
                    permissions: ['manage roles'],
                },
                {
                    title: 'Permissions',
                    href: areaPath('admin', 'permissions'),
                    icon: ShieldCheck,
                    permissions: ['manage permissions'],
                },
                {
                    title: 'Users',
                    href: areaPath('admin', 'users'),
                    icon: Users,
                    permissions: [
                        'view users',
                        'manage users',
                        'create users',
                        'edit users',
                    ],
                },
                {
                    title: 'System Settings',
                    href: areaPath('admin', 'system-settings'),
                    icon: Settings,
                    permissions: [
                        'manage settings',
                        'manage fees',
                        'manage commission',
                    ],
                },
            ],
        },
    ];
}

function buyerNav(): NavSection[] {
    return [
        {
            title: 'Overview',
            collapsible: false,
            items: [
                {
                    title: 'Dashboard',
                    href: areaPath('buyer'),
                    icon: LayoutDashboard,
                    exact: true,
                },
            ],
        },
        {
            title: 'Shopping',
            collapsible: true,
            items: [
                {
                    title: 'Orders',
                    href: areaPath('buyer', 'orders'),
                    icon: ShoppingCart,
                },
                {
                    title: 'Products',
                    href: areaPath('buyer', 'products'),
                    icon: Package,
                },
                {
                    title: 'Payments',
                    href: areaPath('buyer', 'payments'),
                    icon: DollarSign,
                },
                {
                    title: 'Wallet',
                    href: areaPath('buyer', 'wallet'),
                    icon: DollarSign,
                },
                {
                    title: 'Deliveries',
                    href: areaPath('buyer', 'deliveries'),
                    icon: Truck,
                },
                {
                    title: 'Reviews',
                    href: areaPath('buyer', 'reviews'),
                    icon: Star,
                },
            ],
        },
        {
            title: 'Account',
            collapsible: false,
            items: [
                {
                    title: 'Notifications',
                    href: areaPath('buyer', 'notifications'),
                    icon: Bell,
                },
            ],
        },
    ];
}

function sellerNav(): NavSection[] {
    return [
        {
            title: 'Overview',
            collapsible: false,
            items: [
                {
                    title: 'Dashboard',
                    href: areaPath('seller'),
                    icon: LayoutDashboard,
                    exact: true,
                },
                {
                    title: 'My Listing',
                    href: areaPath('seller', 'listing'),
                    icon: ListOrdered,
                },
            ],
        },
        {
            title: 'Business',
            collapsible: true,
            items: [
                {
                    title: 'Products',
                    href: areaPath('seller', 'products'),
                    icon: Package,
                },
                {
                    title: 'Orders',
                    href: areaPath('seller', 'orders'),
                    icon: ShoppingCart,
                },
                {
                    title: 'Payments',
                    href: areaPath('seller', 'payments'),
                    icon: DollarSign,
                },
                {
                    title: 'Wallet',
                    href: areaPath('seller', 'wallet'),
                    icon: DollarSign,
                },
                {
                    title: 'Deliveries',
                    href: areaPath('seller', 'deliveries'),
                    icon: Truck,
                },
                {
                    title: 'Reviews',
                    href: areaPath('seller', 'reviews'),
                    icon: Star,
                },
            ],
        },
        {
            title: 'Account',
            collapsible: false,
            items: [
                {
                    title: 'Notifications',
                    href: areaPath('seller', 'notifications'),
                    icon: Bell,
                },
            ],
        },
    ];
}

function driverNav(): NavSection[] {
    return [
        {
            title: 'Overview',
            collapsible: false,
            items: [
                {
                    title: 'Dashboard',
                    href: areaPath('driver'),
                    icon: LayoutDashboard,
                    exact: true,
                },
            ],
        },
        {
            title: 'Routes',
            collapsible: true,
            items: [
                {
                    title: 'Deliveries',
                    href: areaPath('driver', 'deliveries'),
                    icon: Truck,
                },
                {
                    title: 'Orders',
                    href: areaPath('driver', 'orders'),
                    icon: ShoppingCart,
                },
                {
                    title: 'Wallet',
                    href: areaPath('driver', 'wallet'),
                    icon: DollarSign,
                },
            ],
        },
        {
            title: 'Account',
            collapsible: false,
            items: [
                {
                    title: 'Notifications',
                    href: areaPath('driver', 'notifications'),
                    icon: Bell,
                },
            ],
        },
    ];
}

/** Full sidebar sections for a role area. */
export function getNavSectionsForArea(area: RoleArea): NavSection[] {
    switch (area) {
        case 'buyer':
            return buyerNav();
        case 'seller':
            return sellerNav();
        case 'driver':
            return driverNav();
        case 'admin':
        default:
            return adminNav();
    }
}

/** Flat list for header / mobile menus. */
export function getFlatNavForArea(area: RoleArea): NavLink[] {
    return getNavSectionsForArea(area).flatMap((s) => s.items);
}

/**
 * Dashboard quick links for a role area (excludes the dashboard home itself).
 * Includes footer support (+ API docs for admin).
 */
export function getDashboardQuickLinks(area: RoleArea): NavLink[] {
    const home = areaPath(area);
    const fromNav = getFlatNavForArea(area).filter(
        (item) => !(item.exact && item.href === home) && item.href !== home,
    );
    const footer = getFooterNavForArea(area);
    const seen = new Set<string>();
    const links: NavLink[] = [];

    for (const item of [...fromNav, ...footer]) {
        if (seen.has(item.href)) continue;
        seen.add(item.href);
        links.push(item);
    }

    return links;
}

/** Footer links under the role area. */
export function getFooterNavForArea(area: RoleArea): NavLink[] {
    const items: NavLink[] = [
        {
            title: 'Support',
            href: areaPath(area, 'support'),
            icon: MessageSquare,
        },
    ];

    if (area === 'admin') {
        items.push({
            title: 'API Docs',
            href: areaPath('admin', 'api-docs'),
            icon: BookOpen,
        });
    }

    return items;
}
