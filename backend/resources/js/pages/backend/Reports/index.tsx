import { Head, router } from '@inertiajs/react';
import { BarChart3 } from 'lucide-react';
import { Button } from '@/components/ui/button';
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
    period: string;
    summary: Record<string, number>;
    daily: { date: string; orders: number; revenue: number }[];
    from: string;
    to: string;
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Reports', href: '/admin/reports' },
];

export default function ReportsIndex({ period, summary, daily, from, to }: Props) {
    const setPeriod = (p: string) => {
        router.get('/admin/reports', { period: p }, { preserveState: true });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Reports | SiteDrop Admin">
                <meta name="description" content="Platform reports and exports." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                            <BarChart3 className="h-6 w-6" />
                            Reports
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            {from} → {to}
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        {[
                            { id: '7d', label: '7 days' },
                            { id: '30d', label: '30 days' },
                            { id: '90d', label: '90 days' },
                            { id: 'year', label: '1 year' },
                        ].map((p) => (
                            <Button
                                key={p.id}
                                size="sm"
                                variant={period === p.id ? 'default' : 'outline'}
                                onClick={() => setPeriod(p.id)}
                            >
                                {p.label}
                            </Button>
                        ))}
                    </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        { label: 'Orders', value: summary.orders },
                        {
                            label: 'Revenue',
                            value: `GHS ${Number(summary.revenue ?? 0).toFixed(2)}`,
                        },
                        {
                            label: 'Payments',
                            value: `GHS ${Number(summary.payments ?? 0).toFixed(2)}`,
                        },
                        { label: 'New users', value: summary.new_users },
                        { label: 'New sellers', value: summary.new_sellers },
                        {
                            label: 'Deliveries done',
                            value: summary.deliveries_completed,
                        },
                        { label: 'New products', value: summary.products },
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

                <Card>
                    <CardHeader>
                        <CardTitle>Daily breakdown</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <div className="overflow-x-auto rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Date</TableHead>
                                        <TableHead>Orders</TableHead>
                                        <TableHead>Revenue</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {daily.length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={3}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No data for this period
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        daily.map((row) => (
                                            <TableRow key={row.date}>
                                                <TableCell>{row.date}</TableCell>
                                                <TableCell>{row.orders}</TableCell>
                                                <TableCell>
                                                    GHS{' '}
                                                    {Number(row.revenue).toFixed(2)}
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
