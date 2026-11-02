// resources/js/pages/backend/Orders/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import {
    Eye,
    Pencil,
    Plus,
    Search,
    ShoppingCart,
    Trash2,
} from 'lucide-react';
import { useState } from 'react';
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

interface OrderRow {
    id: number;
    order_number: string;
    status: string;
    payment_status?: string;
    total_amount: number;
    currency: string;
    quantity?: number;
    items_count?: number;
    items_summary?: string;
    buyer?: { name: string } | null;
    seller?: { name: string } | null;
    product?: { name: string } | null;
    created_at?: string;
}

interface Props {
    orders: {
        data: OrderRow[];
        last_page: number;
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; status?: string; payment_status?: string };
    statuses: string[];
    payment_statuses?: string[];
    can?: { create?: boolean; update?: boolean; delete?: boolean };
    area?: string;
}

export default function OrdersIndex({
    orders,
    filters,
    statuses,
    can,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Orders', href: path('orders') },
    ];

    const canCreate = can?.create ?? true;
    const canUpdate = can?.update ?? true;
    const canDelete = can?.delete ?? true;
    const [selected, setSelected] = useState<number[]>([]);

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get(path("orders"), query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    const toggleSelect = (id: number) => {
        setSelected((prev) =>
            prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
        );
    };

    const selectAllOnPage = () => {
        if (selected.length === orders.data.length) {
            setSelected([]);
        } else {
            setSelected(orders.data.map((o) => o.id));
        }
    };

    const deleteOne = (id: number, number: string) => {
        if (!confirm(`Delete order ${number}? This soft-deletes the order.`)) {
            return;
        }
        router.delete(path("orders", id), { preserveScroll: true });
    };

    const bulkDelete = () => {
        if (!canDelete || selected.length === 0) return;
        if (!confirm(`Delete ${selected.length} selected order(s)?`)) return;
        router.post(
            path("orders", "bulk-delete"),
            { ids: selected },
            {
                preserveScroll: true,
                onSuccess: () => setSelected([]),
            },
        );
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Orders | SiteDrop Admin">
                <meta name="description" content="View, manage and process customer orders." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                            <ShoppingCart className="h-6 w-6" />
                            Orders
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Create, track and manage marketplace orders
                        </p>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        {canDelete && (
                            <Button
                                variant="destructive"
                                className="cursor-pointer"
                                disabled={selected.length === 0}
                                onClick={bulkDelete}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                {selected.length > 0
                                    ? `Delete selected (${selected.length})`
                                    : 'Delete selected'}
                            </Button>
                        )}
                        {canCreate && (
                            <Button asChild className="cursor-pointer">
                                <Link href={path("orders", "create")}>
                                    <Plus className="mr-2 h-4 w-4" />
                                    New order
                                </Link>
                            </Button>
                        )}
                    </div>
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>All orders ({orders.total})</CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 flex-col gap-3 sm:flex-row sm:items-end sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Order #, buyer, seller..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="status"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm sm:w-40"
                                    defaultValue={filters.status ?? ''}
                                >
                                    <option value="">All statuses</option>
                                    {statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s.replace(/_/g, ' ')}
                                        </option>
                                    ))}
                                </select>
                                <Button
                                    type="submit"
                                    size="sm"
                                    className="cursor-pointer"
                                >
                                    Filter
                                </Button>
                            </form>
                        </div>
                    </CardHeader>
                    <CardContent className="p-0">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    {canDelete && (
                                        <TableHead className="w-10">
                                            <input
                                                type="checkbox"
                                                className="h-4 w-4 cursor-pointer rounded border"
                                                checked={
                                                    orders.data.length > 0 &&
                                                    selected.length ===
                                                        orders.data.length
                                                }
                                                onChange={selectAllOnPage}
                                            />
                                        </TableHead>
                                    )}
                                    <TableHead>Order</TableHead>
                                    <TableHead>Buyer</TableHead>
                                    <TableHead>Seller</TableHead>
                                    <TableHead>Items</TableHead>
                                    <TableHead>Amount</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead>Payment</TableHead>
                                    <TableHead className="w-28 text-right">
                                        Actions
                                    </TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {orders.data.length === 0 ? (
                                    <TableRow>
                                        <TableCell
                                            colSpan={canDelete ? 9 : 8}
                                            className="py-12 text-center text-muted-foreground"
                                        >
                                            No orders found
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    orders.data.map((order) => (
                                        <TableRow key={order.id}>
                                            {canDelete && (
                                                <TableCell>
                                                    <input
                                                        type="checkbox"
                                                        className="h-4 w-4 cursor-pointer rounded border"
                                                        checked={selected.includes(
                                                            order.id,
                                                        )}
                                                        onChange={() =>
                                                            toggleSelect(
                                                                order.id,
                                                            )
                                                        }
                                                    />
                                                </TableCell>
                                            )}
                                            <TableCell className="font-medium">
                                                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-semibold">
                                                    {order.order_number}
                                                </code>
                                                <div className="text-xs text-muted-foreground">
                                                    {order.created_at}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                {order.buyer?.name || '—'}
                                            </TableCell>
                                            <TableCell>
                                                {order.seller?.name || '—'}
                                            </TableCell>
                                            <TableCell>
                                                <div className="text-sm">
                                                    {order.items_summary ||
                                                        order.product?.name ||
                                                        '—'}
                                                </div>
                                                {(order.items_count ?? 0) >
                                                    1 && (
                                                    <div className="text-xs text-muted-foreground">
                                                        {order.items_count} line
                                                        items
                                                    </div>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {order.currency}{' '}
                                                {Number(
                                                    order.total_amount,
                                                ).toFixed(2)}
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="secondary">
                                                    {order.status.replace(
                                                        /_/g,
                                                        ' ',
                                                    )}
                                                </Badge>
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="outline">
                                                    {order.payment_status ||
                                                        '—'}
                                                </Badge>
                                            </TableCell>
                                            <TableCell>
                                                <div className="flex items-center justify-end gap-1">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="cursor-pointer"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={path("orders", order.id)}
                                                            title="View"
                                                        >
                                                            <Eye className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                View
                                                            </span>
                                                        </Link>
                                                    </Button>
                                                    {canUpdate && (
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            className="cursor-pointer"
                                                            asChild
                                                        >
                                                            <Link
                                                                href={path("orders", order.id, "edit")}
                                                                title="Edit"
                                                            >
                                                                <Pencil className="h-4 w-4" />
                                                                <span className="sr-only">
                                                                    Edit
                                                                </span>
                                                            </Link>
                                                        </Button>
                                                    )}
                                                    {canDelete && (
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            type="button"
                                                            className="cursor-pointer text-destructive hover:text-destructive"
                                                            title="Delete"
                                                            onClick={() =>
                                                                deleteOne(
                                                                    order.id,
                                                                    order.order_number,
                                                                )
                                                            }
                                                        >
                                                            <Trash2 className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                Delete
                                                            </span>
                                                        </Button>
                                                    )}
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                        {orders.last_page > 1 && (
                            <div className="flex flex-wrap gap-2 border-t p-4">
                                {orders.links.map((link, i) =>
                                    link.url ? (
                                        <Button
                                            key={i}
                                            size="sm"
                                            variant={
                                                link.active
                                                    ? 'default'
                                                    : 'outline'
                                            }
                                            className="cursor-pointer"
                                            onClick={() =>
                                                router.get(link.url!)
                                            }
                                            dangerouslySetInnerHTML={{
                                                __html: link.label,
                                            }}
                                        />
                                    ) : null,
                                )}
                            </div>
                        )}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
