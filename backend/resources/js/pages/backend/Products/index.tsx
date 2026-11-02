import { Head, Link, router } from '@inertiajs/react';
import { Eye, Package, Search } from 'lucide-react';
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
    name: string;
    sku?: string;
    category?: string;
    price_per_unit: number;
    unit?: string;
    stock_quantity?: number;
    is_available: boolean;
    is_featured: boolean;
    seller?: { name: string } | null;
}

interface Props {
    products: {
        data: Row[];
        last_page: number;
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; available?: string; category?: string };
    categories: string[];
    area?: string;
}

export default function ProductsIndex({
    products,
    filters,
    categories,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Products', href: path('products') },
    ];

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get(path("products"), query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Products | SiteDrop Admin">
                <meta name="description" content="Browse and manage marketplace product listings." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <Package className="h-6 w-6" />
                        Products
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Catalogue of seller listings on the marketplace
                    </p>
                </div>
                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>All products ({products.total})</CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 flex-col gap-3 sm:flex-row sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Name, SKU, category..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="category"
                                    className="rounded-md border bg-background px-3 py-2 text-sm sm:w-40"
                                    defaultValue={filters.category ?? ''}
                                >
                                    <option value="">All categories</option>
                                    {categories.map((c) => (
                                        <option key={c} value={c}>
                                            {c}
                                        </option>
                                    ))}
                                </select>
                                <select
                                    name="available"
                                    className="rounded-md border bg-background px-3 py-2 text-sm sm:w-36"
                                    defaultValue={filters.available ?? ''}
                                >
                                    <option value="">Availability</option>
                                    <option value="1">Available</option>
                                    <option value="0">Unavailable</option>
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
                                        <TableHead>Product</TableHead>
                                        <TableHead>Seller</TableHead>
                                        <TableHead>Category</TableHead>
                                        <TableHead>Price</TableHead>
                                        <TableHead>Stock</TableHead>
                                        <TableHead>Status</TableHead>
                                        <TableHead className="text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {products.data.length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={7}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No products found
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        products.data.map((p) => (
                                            <TableRow key={p.id}>
                                                <TableCell className="font-medium">
                                                    {p.name}
                                                    <div className="text-xs text-muted-foreground">
                                                        {p.sku || '—'}
                                                    </div>
                                                </TableCell>
                                                <TableCell>
                                                    {p.seller?.name || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {p.category || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    GHS{' '}
                                                    {p.price_per_unit.toFixed(2)}
                                                    {p.unit
                                                        ? ` / ${p.unit}`
                                                        : ''}
                                                </TableCell>
                                                <TableCell>
                                                    {p.stock_quantity ?? '—'}
                                                </TableCell>
                                                <TableCell>
                                                    <Badge
                                                        variant={
                                                            p.is_available
                                                                ? 'default'
                                                                : 'secondary'
                                                        }
                                                    >
                                                        {p.is_available
                                                            ? 'Available'
                                                            : 'Unavailable'}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={path("products", p.id)}
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
