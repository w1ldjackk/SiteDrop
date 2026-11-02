import { Link, usePage } from '@inertiajs/react';
import type { PropsWithChildren } from 'react';
import Heading from '@/components/heading';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { useCurrentUrl } from '@/hooks/use-current-url';
import { cn } from '@/lib/utils';
import type { NavItem } from '@/types';

/**
 * Settings live under the active role area:
 *   /admin/settings/*, /buyer/settings/*, /seller/settings/*, /driver/settings/*
 */
function settingsBaseFromPath(pathname: string): string {
    const match = pathname.match(/^\/(admin|buyer|seller|driver)(?:\/|$)/);
    if (match) {
        return `/${match[1]}/settings`;
    }

    // Fallback for edge cases
    return '/admin/settings';
}

export default function SettingsLayout({ children }: PropsWithChildren) {
    const { isCurrentUrl } = useCurrentUrl();
    const { url } = usePage();
    const pathname =
        typeof window !== 'undefined'
            ? window.location.pathname
            : (url?.split('?')[0] ?? '/admin');

    const base = settingsBaseFromPath(pathname);

    const sidebarNavItems: NavItem[] = [
        { title: 'Profile', href: `${base}/profile`, icon: null },
        { title: 'Password', href: `${base}/password`, icon: null },
        { title: 'Two-Factor Auth', href: `${base}/two-factor`, icon: null },
        { title: 'Appearance', href: `${base}/appearance`, icon: null },
    ];

    // When server-side rendering, we only render the layout on the client...
    if (typeof window === 'undefined') {
        return null;
    }

    return (
        <div className="px-4 py-6">
            <Heading
                title="Settings"
                description="Manage your profile and account settings"
            />

            <div className="flex flex-col lg:flex-row lg:space-x-12">
                <aside className="w-full max-w-xl lg:w-48">
                    <nav
                        className="flex flex-col space-y-1 space-x-0"
                        aria-label="Settings"
                    >
                        {sidebarNavItems.map((item, index) => (
                            <Button
                                key={`${item.href}-${index}`}
                                size="sm"
                                variant="ghost"
                                asChild
                                className={cn('w-full justify-start', {
                                    'bg-muted': isCurrentUrl(item.href),
                                })}
                            >
                                <Link href={item.href}>
                                    {item.icon && (
                                        <item.icon className="h-4 w-4" />
                                    )}
                                    {item.title}
                                </Link>
                            </Button>
                        ))}
                    </nav>
                </aside>

                <Separator className="my-6 lg:hidden" />

                <div className="flex-1 md:max-w-2xl">
                    <section className="max-w-xl space-y-12">
                        {children}
                    </section>
                </div>
            </div>
        </div>
    );
}
