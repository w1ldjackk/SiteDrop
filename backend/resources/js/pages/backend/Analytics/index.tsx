import { Head, Link } from '@inertiajs/react';
import { Activity } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface Props {
    kpis: Record<string, number>;
    order_status: Record<string, number>;
    payment_status: Record<string, number>;
    top_products: {
        id: number;
        name: string;
        orders_count: number;
        avg_rating?: number;
        price_per_unit: number;
    }[];
    top_sellers: {
        id: number;
        business_name: string;
        status: string;
        orders_count: number;
    }[];
    users_by_role: Record<string, number>;
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Analytics', href: '/admin/analytics' },
];

export default function AnalyticsIndex({
    kpis,
    order_status,
    payment_status,
    top_products,
    top_sellers,
    users_by_role,
}: Props) {
    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Analytics | SiteDrop Admin">
                <meta name="description" content="Platform analytics, KPIs and performance insights." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <Activity className="h-6 w-6" />
                        Analytics
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Platform health and performance signals
                    </p>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    {[
                        { label: 'Users', value: kpis.users },
                        { label: 'Sellers', value: kpis.sellers },
                        { label: 'Products', value: kpis.products },
                        { label: 'Orders', value: kpis.orders },
                        {
                            label: 'Revenue',
                            value: `GHS ${Number(kpis.revenue ?? 0).toFixed(2)}`,
                        },
                        {
                            label: 'Active deliveries',
                            value: kpis.active_deliveries,
                        },
                    ].map((s) => (
                        <Card key={s.label}>
                            <CardHeader className="pb-2">
                                <CardTitle className="text-sm font-medium text-muted-foreground">
                                    {s.label}
                                </CardTitle>
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold">{s.value}</div>
                            </CardContent>
                        </Card>
                    ))}
                </div>

                <div className="grid gap-4 lg:grid-cols-3">
                    <Card>
                        <CardHeader>
                            <CardTitle>Users by role</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            {Object.entries(users_by_role).map(([k, v]) => (
                                <div
                                    key={k}
                                    className="flex items-center justify-between"
                                >
                                    <span className="capitalize text-muted-foreground">
                                        {k}
                                    </span>
                                    <span className="font-medium">{v}</span>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Orders by status</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            {Object.entries(order_status).map(([k, v]) => (
                                <div
                                    key={k}
                                    className="flex items-center justify-between"
                                >
                                    <Badge variant="outline">{k}</Badge>
                                    <span className="font-medium">{v}</span>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Payments by status</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            {Object.entries(payment_status).map(([k, v]) => (
                                <div
                                    key={k}
                                    className="flex items-center justify-between"
                                >
                                    <Badge variant="outline">{k}</Badge>
                                    <span className="font-medium">{v}</span>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                </div>

                <div className="grid gap-4 lg:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Top products</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Product</TableHead>
                                        <TableHead>Orders</TableHead>
                                        <TableHead>Rating</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {top_products.map((p) => (
                                        <TableRow key={p.id}>
                                            <TableCell>
                                                <Link
                                                    href={`/admin/products/${p.id}`}
                                                    className="font-medium hover:underline"
                                                >
                                                    {p.name}
                                                </Link>
                                            </TableCell>
                                            <TableCell>{p.orders_count}</TableCell>
                                            <TableCell>
                                                {p.avg_rating ?? '—'}
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Top sellers</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Seller</TableHead>
                                        <TableHead>Orders</TableHead>
                                        <TableHead>Status</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {top_sellers.map((s) => (
                                        <TableRow key={s.id}>
                                            <TableCell>
                                                <Link
                                                    href={`/admin/sellers/${s.id}`}
                                                    className="font-medium hover:underline"
                                                >
                                                    {s.business_name}
                                                </Link>
                                            </TableCell>
                                            <TableCell>{s.orders_count}</TableCell>
                                            <TableCell>
                                                <Badge variant="secondary">
                                                    {s.status}
                                                </Badge>
                                            </TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </AppLayout>
    );
}
