// resources/js/components/role-quick-links.tsx
import { Link } from '@inertiajs/react';
import { useMemo } from 'react';
import { useRoleArea, type RoleArea } from '@/hooks/use-role-area';
import { getDashboardQuickLinks } from '@/lib/role-nav';
import { cn } from '@/lib/utils';

type Props = {
    /** Override area (defaults to useRoleArea resolution). */
    area?: RoleArea;
    title?: string;
    description?: string;
    className?: string;
};

/**
 * Grid of role-area shortcuts for buyer / seller / driver / admin dashboards.
 */
export function RoleQuickLinks({
    area: areaProp,
    title = 'Quick links',
    description = 'Jump to common pages in your workspace.',
    className,
}: Props) {
    const { area: resolved } = useRoleArea(areaProp);
    const area = (areaProp ?? resolved) as RoleArea;

    const links = useMemo(() => getDashboardQuickLinks(area), [area]);

    if (links.length === 0) {
        return null;
    }

    return (
        <div
            className={cn(
                'rounded-2xl border bg-card p-6 shadow-sm',
                className,
            )}
        >
            <div className="mb-4">
                <h2 className="text-lg font-semibold">{title}</h2>
                {description && (
                    <p className="mt-1 text-sm text-muted-foreground">
                        {description}
                    </p>
                )}
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
                {links.map((item) => {
                    const Icon = item.icon;
                    return (
                        <Link
                            key={item.href}
                            href={item.href}
                            prefetch
                            className="group flex flex-col items-start gap-2 rounded-xl border bg-background p-4 transition-colors hover:border-primary/40 hover:bg-muted/50"
                        >
                            {Icon && (
                                <span className="rounded-lg bg-primary/10 p-2 text-primary transition-colors group-hover:bg-primary/15">
                                    <Icon className="h-5 w-5" />
                                </span>
                            )}
                            <span className="text-sm font-medium leading-tight">
                                {item.title}
                            </span>
                        </Link>
                    );
                })}
            </div>
        </div>
    );
}
