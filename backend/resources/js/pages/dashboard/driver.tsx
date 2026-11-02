import { Head, Link } from '@inertiajs/react';
import { Bell, ShoppingCart, Truck } from 'lucide-react';
import { RoleQuickLinks } from '@/components/role-quick-links';
import { Button } from '@/components/ui/button';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    role?: string;
    user?: {
        id: number;
        name: string;
        email?: string;
        phone?: string;
        roles: string[];
    };
    area?: string;
}

export default function DriverDashboard({ user, area }: Props) {
    const { path, base } = useRoleArea(area ?? 'driver');

    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Driver', href: base },
    ];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Driver Dashboard" />

            <div className="flex h-full flex-1 flex-col gap-6 overflow-x-auto p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight">
                            Welcome{user?.name ? `, ${user.name}` : ''}
                        </h1>
                        <p className="mt-1 text-muted-foreground">
                            Deliveries and orders assigned to you.
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <Button asChild className="cursor-pointer">
                            <Link href={path('deliveries')}>
                                <Truck className="mr-2 h-4 w-4" />
                                My deliveries
                            </Link>
                        </Button>
                        <Button asChild variant="outline" className="cursor-pointer">
                            <Link href={path('orders')}>
                                <ShoppingCart className="mr-2 h-4 w-4" />
                                Related orders
                            </Link>
                        </Button>
                    </div>
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                    <Link
                        href={path('deliveries')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <Truck className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">
                            Deliveries
                        </p>
                        <p className="mt-1 text-lg font-semibold">
                            Open assignments
                        </p>
                    </Link>
                    <Link
                        href={path('orders')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <ShoppingCart className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">Orders</p>
                        <p className="mt-1 text-lg font-semibold">
                            Linked orders
                        </p>
                    </Link>
                    <Link
                        href={path('notifications')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <Bell className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">
                            Notifications
                        </p>
                        <p className="mt-1 text-lg font-semibold">
                            Alerts & updates
                        </p>
                    </Link>
                </div>

                <RoleQuickLinks
                    area="driver"
                    title="Workspace"
                    description="All driver area pages under /driver"
                />
            </div>
        </AppLayout>
    );
}
