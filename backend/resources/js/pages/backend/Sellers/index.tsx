// resources/js/pages/backend/Sellers/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Eye, Pencil, Plus, Search, Store, Trash2 } from 'lucide-react';
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
import type { BreadcrumbItem } from '@/types';

interface SellerRow {
    id: number;
    seller_code?: string;
    business_name: string;
    business_type?: string;
    business_phone?: string;
    business_email?: string;
    status: string;
    orders_count: number;
    products_count: number;
    docs_count?: number;
    user?: { id: number; name: string; email?: string; phone?: string } | null;
    created_at?: string;
}

interface Props {
    sellers: {
        data: SellerRow[];
        current_page: number;
        last_page: number;
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; status?: string };
    statuses: string[];
    can?: { create?: boolean; update?: boolean; delete?: boolean };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Sellers', href: '/admin/sellers' },
];

export default function SellersIndex({
    sellers,
    filters,
    statuses,
    can,
}: Props) {
    const canCreate = can?.create ?? true;
    const canUpdate = can?.update ?? true;
    const canDelete = can?.delete ?? true;

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((value, key) => {
            if (value.toString().trim()) query[key] = value.toString().trim();
        });
        router.get('/admin/sellers', query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    const deleteOne = (id: number, name: string) => {
        if (
            !confirm(
                `Delete seller "${name}"? The profile will be soft-deleted.`,
            )
        ) {
            return;
        }
        router.delete(`/admin/sellers/${id}`, { preserveScroll: true });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Sellers | SiteDrop Admin">
                <meta name="description" content="Manage sellers, onboarding, and verification documents." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                            <Store className="h-6 w-6" />
                            Sellers
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Manage seller profiles and owner accounts
                        </p>
                    </div>
                    {canCreate && (
                        <Button asChild className="cursor-pointer">
                            <Link href="/admin/sellers/create">
                                <Plus className="mr-2 h-4 w-4" />
                                New seller
                            </Link>
                        </Button>
                    )}
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>All sellers ({sellers.total})</CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 flex-col gap-3 sm:flex-row sm:items-end sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Business, email, phone..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="status"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm sm:w-44"
                                    defaultValue={filters.status ?? ''}
                                >
                                    <option value="">All statuses</option>
                                    {statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s}
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
                                    <TableHead className="w-32">
                                        Seller ID
                                    </TableHead>
                                    <TableHead>Business</TableHead>
                                    <TableHead>Owner</TableHead>
                                    <TableHead>Contact</TableHead>
                                    <TableHead>Products</TableHead>
                                    <TableHead>Orders</TableHead>
                                    <TableHead>Docs</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead className="w-28 text-right">
                                        Actions
                                    </TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {sellers.data.length === 0 ? (
                                    <TableRow>
                                        <TableCell
                                            colSpan={9}
                                            className="py-12 text-center text-muted-foreground"
                                        >
                                            No sellers found
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    sellers.data.map((seller) => (
                                        <TableRow key={seller.id}>
                                            <TableCell>
                                                <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-semibold">
                                                    {seller.seller_code ||
                                                        `SLR-${String(seller.id).padStart(6, '0')}`}
                                                </code>
                                            </TableCell>
                                            <TableCell className="font-medium">
                                                {seller.business_name}
                                                <div className="text-xs text-muted-foreground">
                                                    {seller.business_type ||
                                                        '—'}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                {seller.user?.name || '—'}
                                            </TableCell>
                                            <TableCell>
                                                <div className="text-sm">
                                                    {seller.business_email ||
                                                        seller.user?.email ||
                                                        '—'}
                                                </div>
                                                <div className="text-xs text-muted-foreground">
                                                    {seller.business_phone ||
                                                        seller.user?.phone ||
                                                        '—'}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                {seller.products_count}
                                            </TableCell>
                                            <TableCell>
                                                {seller.orders_count}
                                            </TableCell>
                                            <TableCell>
                                                {seller.docs_count ?? 0}
                                            </TableCell>
                                            <TableCell>
                                                <Badge
                                                    variant={
                                                        seller.status ===
                                                        'approved'
                                                            ? 'default'
                                                            : seller.status ===
                                                                'pending'
                                                              ? 'secondary'
                                                              : 'destructive'
                                                    }
                                                >
                                                    {seller.status}
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
                                                            href={`/admin/sellers/${seller.id}`}
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
                                                                href={`/admin/sellers/${seller.id}/edit`}
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
                                                                    seller.id,
                                                                    seller.business_name,
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
                        {sellers.last_page > 1 && (
                            <div className="flex flex-wrap gap-2 border-t p-4">
                                {sellers.links.map((link, i) =>
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
