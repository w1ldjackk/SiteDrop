import { Head, Link } from '@inertiajs/react';
import { DollarSign, Package, ShoppingCart } from 'lucide-react';
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

export default function SellerDashboard({ user, area }: Props) {
    const { path, base } = useRoleArea(area ?? 'seller');

    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Seller', href: base },
    ];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Seller Dashboard" />

            <div className="flex h-full flex-1 flex-col gap-6 overflow-x-auto p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight">
                            Welcome{user?.name ? `, ${user.name}` : ''}
                        </h1>
                        <p className="mt-1 text-muted-foreground">
                            Manage products, orders, and payouts for your store.
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <Button asChild className="cursor-pointer">
                            <Link href={path('products')}>
                                <Package className="mr-2 h-4 w-4" />
                                My products
                            </Link>
                        </Button>
                        <Button asChild variant="outline" className="cursor-pointer">
                            <Link href={path('orders')}>
                                <ShoppingCart className="mr-2 h-4 w-4" />
                                Orders
                            </Link>
                        </Button>
                    </div>
                </div>

                <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
                    <Link
                        href={path('products')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <Package className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">Products</p>
                        <p className="mt-1 text-lg font-semibold">
                            Manage catalogue
                        </p>
                    </Link>
                    <Link
                        href={path('orders')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <ShoppingCart className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">Orders</p>
                        <p className="mt-1 text-lg font-semibold">
                            Fulfill sales
                        </p>
                    </Link>
                    <Link
                        href={path('payments')}
                        className="rounded-xl border bg-card p-5 shadow-sm transition-colors hover:border-primary/40 hover:bg-muted/30"
                    >
                        <DollarSign className="mb-3 h-5 w-5 text-primary" />
                        <p className="text-sm text-muted-foreground">Payments</p>
                        <p className="mt-1 text-lg font-semibold">
                            View earnings
                        </p>
                    </Link>
                </div>

                <RoleQuickLinks
                    area="seller"
                    title="Workspace"
                    description="All seller area pages under /seller"
                />
            </div>
        </AppLayout>
    );
}
