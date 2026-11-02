import { Head, Link, router } from '@inertiajs/react';
import { Eye, Search, Truck } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Row {
    id: number;
    tracking_number?: string;
    status: string;
    delivery_fee: number;
    distance_km?: number;
    driver?: { name: string; phone?: string } | null;
    order?: { order_number: string } | null;
    created_at?: string;
}

interface Props {
    deliveries: {
        data: Row[];
        last_page: number;
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; status?: string };
    statuses: string[];
    area?: string;
}

export default function DeliveriesIndex({
    deliveries,
    filters,
    statuses,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Deliveries', href: path('deliveries') },
    ];

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get(path("deliveries"), query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Deliveries | SiteDrop Admin">
                <meta name="description" content="Track and manage deliveries across the platform." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <Truck className="h-6 w-6" />
                        Deliveries
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Monitor delivery jobs and driver assignments
                    </p>
                </div>
                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>
                                All deliveries ({deliveries.total})
                            </CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 flex-col gap-3 sm:flex-row sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Tracking #, driver, order..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="status"
                                    className="rounded-md border bg-background px-3 py-2 text-sm sm:w-40"
                                    defaultValue={filters.status ?? ''}
                                >
                                    <option value="">All statuses</option>
                                    {statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s}
                                        </option>
                                    ))}
                                </select>
                                <Button type="submit" size="sm">
                                    Filter
                                </Button>
                            </form>
                        </div>
                    </CardHeader>
                    <CardContent>
                        <div className="overflow-x-auto rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Tracking</TableHead>
                                        <TableHead>Order</TableHead>
                                        <TableHead>Driver</TableHead>
                                        <TableHead>Fee</TableHead>
                                        <TableHead>Status</TableHead>
                                        <TableHead className="text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {deliveries.data.length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={6}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No deliveries found
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        deliveries.data.map((d) => (
                                            <TableRow key={d.id}>
                                                <TableCell className="font-medium">
                                                    {d.tracking_number ||
                                                        `#${d.id}`}
                                                </TableCell>
                                                <TableCell>
                                                    {d.order?.order_number ||
                                                        '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {d.driver?.name ||
                                                        'Unassigned'}
                                                </TableCell>
                                                <TableCell>
                                                    GHS{' '}
                                                    {d.delivery_fee.toFixed(2)}
                                                </TableCell>
                                                <TableCell>
                                                    <Badge variant="secondary">
                                                        {d.status}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={path("deliveries", d.id)}
                                                        >
                                                            <Eye className="h-4 w-4" />
                                                        </Link>
                                                    </Button>
                                                </TableCell>
                                            </TableRow>
                                        ))
                                    )}
                                </TableBody>
                            </Table>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
