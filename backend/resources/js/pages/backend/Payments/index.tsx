import { Head, Link, router } from '@inertiajs/react';
import { DollarSign, Eye, Search } from 'lucide-react';
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
    payment_reference?: string;
    transaction_id?: string;
    amount: number;
    currency: string;
    payment_method?: string;
    status: string;
    user?: { name: string } | null;
    order?: { order_number: string } | null;
    paid_at?: string;
}

interface Props {
    payments: {
        data: Row[];
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; status?: string };
    statuses: string[];
    summary: {
        total: number;
        pending: number;
        success: number;
        failed: number;
    };
    area?: string;
}

export default function PaymentsIndex({
    payments,
    filters,
    statuses,
    summary,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Payments', href: path('payments') },
    ];

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get(path("payments"), query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Payments | SiteDrop Admin">
                <meta name="description" content="View and manage payments and transactions." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <DollarSign className="h-6 w-6" />
                        Payments
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Gateway transactions and settlement status
                    </p>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        {
                            label: 'Successful volume',
                            value: `GHS ${summary.total.toFixed(2)}`,
                        },
                        { label: 'Success', value: summary.success },
                        { label: 'Pending', value: summary.pending },
                        { label: 'Failed', value: summary.failed },
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
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>Transactions ({payments.total})</CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 gap-3 sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1 sm:max-w-sm">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Reference, txn, user..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="status"
                                    className="rounded-md border bg-background px-3 py-2 text-sm sm:w-36"
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
                                        <TableHead>Reference</TableHead>
                                        <TableHead>User</TableHead>
                                        <TableHead>Order</TableHead>
                                        <TableHead>Amount</TableHead>
                                        <TableHead>Method</TableHead>
                                        <TableHead>Status</TableHead>
                                        <TableHead className="text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {payments.data.length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={7}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No payments found
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        payments.data.map((p) => (
                                            <TableRow key={p.id}>
                                                <TableCell className="font-medium">
                                                    {p.payment_reference ||
                                                        p.transaction_id ||
                                                        `#${p.id}`}
                                                </TableCell>
                                                <TableCell>
                                                    {p.user?.name || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {p.order?.order_number ||
                                                        '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {p.currency}{' '}
                                                    {p.amount.toFixed(2)}
                                                </TableCell>
                                                <TableCell>
                                                    {p.payment_method || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    <Badge
                                                        variant={
                                                            p.status ===
                                                            'success'
                                                                ? 'default'
                                                                : 'secondary'
                                                        }
                                                    >
                                                        {p.status}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={path("payments", p.id)}
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
