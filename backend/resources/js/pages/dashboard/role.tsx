import { Head } from '@inertiajs/react';
import { RoleQuickLinks } from '@/components/role-quick-links';
import AppLayout from '@/layouts/app-layout';
import type { RoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    role: string;
    area?: string;
    user: {
        id: number;
        name: string;
        email?: string;
        phone?: string;
        roles: string[];
    };
}

export default function RoleDashboard({ role, area, user }: Props) {
    const slug = (area || role || 'buyer').toLowerCase();
    const label = slug
        .split('-')
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');

    const roleArea = (
        ['admin', 'buyer', 'seller', 'driver'].includes(slug) ? slug : 'buyer'
    ) as RoleArea;

    const breadcrumbs: BreadcrumbItem[] = [
        { title: label, href: `/${roleArea}` },
    ];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${label} home`} />

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">
                        Welcome, {user.name}
                    </h1>
                    <p className="mt-1 text-muted-foreground">
                        You are signed in as{' '}
                        <span className="font-medium text-foreground">
                            {label}
                        </span>
                        {user.roles.length > 1 && (
                            <span>
                                {' '}
                                · roles: {user.roles.join(', ')}
                            </span>
                        )}
                    </p>
                </div>

                <RoleQuickLinks
                    area={roleArea}
                    title={`${label} workspace`}
                    description={`Pages available under /${roleArea}`}
                />
            </div>
        </AppLayout>
    );
}
