import { Head, router } from '@inertiajs/react';
import { EyeOff, CheckCircle2, MessageSquare, Search, Trash2 } from 'lucide-react';
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

interface Row {
    id: number;
    rating: number;
    comment?: string;
    type?: string;
    status: string;
    reviewer?: { name: string } | null;
    product?: { name: string } | null;
    created_at?: string;
}

interface Props {
    reviews: {
        data: Row[];
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    filters: { search?: string; status?: string };
    statuses: string[];
    can?: {
        delete?: boolean;
        moderate?: boolean;
    };
    area?: string;
}

export default function ReviewsIndex({
    reviews,
    filters,
    statuses,
    can,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Reviews', href: path('reviews') },
    ];

    // Default false — moderate/delete routes exist only under /admin
    const canDelete = can?.delete === true;
    const canModerate = can?.moderate === true;
    const [selected, setSelected] = useState<number[]>([]);

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get(path("reviews"), query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    const setStatus = (id: number, status: string) => {
        router.put(
            path("reviews", id),
            { status },
            { preserveScroll: true },
        );
    };

    const deleteOne = (id: number) => {
        if (!canDelete) return;
        if (
            !confirm(
                'Delete this review permanently? This cannot be undone.',
            )
        ) {
            return;
        }
        router.delete(path("reviews", id), {
            preserveScroll: true,
            onSuccess: () =>
                setSelected((prev) => prev.filter((x) => x !== id)),
        });
    };

    const toggleSelect = (id: number) => {
        setSelected((prev) =>
            prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
        );
    };

    const selectAllOnPage = () => {
        if (selected.length === reviews.data.length) {
            setSelected([]);
        } else {
            setSelected(reviews.data.map((r) => r.id));
        }
    };

    const bulkDelete = () => {
        if (!canDelete || selected.length === 0) return;
        if (
            !confirm(
                `Delete ${selected.length} selected review(s) permanently?`,
            )
        ) {
            return;
        }
        router.post(
            path("reviews", "bulk-delete"),
            { ids: selected },
            {
                preserveScroll: true,
                onSuccess: () => setSelected([]),
            },
        );
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Reviews | SiteDrop">
                <meta
                    name="description"
                    content="View and manage product and seller reviews."
                />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                            <MessageSquare className="h-6 w-6" />
                            Reviews
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            {canModerate
                                ? 'Moderate product and seller reviews'
                                : 'Reviews related to your account'}
                        </p>
                    </div>

                    {canDelete && (
                        <Button
                            variant="destructive"
                            className="cursor-pointer"
                            disabled={selected.length === 0}
                            onClick={bulkDelete}
                            title={
                                selected.length === 0
                                    ? 'Select one or more reviews first'
                                    : `Delete ${selected.length} selected`
                            }
                        >
                            <Trash2 className="mr-2 h-4 w-4" />
                            {selected.length > 0
                                ? `Delete selected (${selected.length})`
                                : 'Delete selected'}
                        </Button>
                    )}
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>
                                Reviews ({reviews?.total ?? reviews?.data?.length ?? 0})
                            </CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 gap-3 sm:justify-end"
                            >
                                <div className="relative min-w-[200px] flex-1 sm:max-w-sm">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Comment, reviewer, product..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <select
                                    name="status"
                                    className="cursor-pointer rounded-md border bg-background px-3 py-2 text-sm sm:w-36"
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
                                    {canDelete && (
                                        <TableHead className="w-10">
                                            <input
                                                type="checkbox"
                                                checked={
                                                    reviews.data.length > 0 &&
                                                    selected.length ===
                                                        reviews.data.length
                                                }
                                                onChange={selectAllOnPage}
                                                className="h-4 w-4 cursor-pointer rounded border"
                                                title="Select all on page"
                                                aria-label="Select all on page"
                                            />
                                        </TableHead>
                                    )}
                                    <TableHead>Rating</TableHead>
                                    <TableHead>Reviewer</TableHead>
                                    <TableHead>Product</TableHead>
                                    <TableHead>Comment</TableHead>
                                    <TableHead>Status</TableHead>
                                    {(canModerate || canDelete) && (
                                        <TableHead className="w-28 text-right">
                                            Actions
                                        </TableHead>
                                    )}
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {(reviews?.data ?? []).length === 0 ? (
                                    <TableRow>
                                        <TableCell
                                            colSpan={
                                                5 +
                                                (canDelete ? 1 : 0) +
                                                (canModerate || canDelete
                                                    ? 1
                                                    : 0)
                                            }
                                            className="py-12 text-center text-muted-foreground"
                                        >
                                            No reviews found
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    (reviews?.data ?? []).map((r) => (
                                        <TableRow key={r.id}>
                                            {canDelete && (
                                                <TableCell>
                                                    <input
                                                        type="checkbox"
                                                        checked={selected.includes(
                                                            r.id,
                                                        )}
                                                        onChange={() =>
                                                            toggleSelect(r.id)
                                                        }
                                                        className="h-4 w-4 cursor-pointer rounded border"
                                                    />
                                                </TableCell>
                                            )}
                                            <TableCell className="font-medium">
                                                {r.rating}/5
                                            </TableCell>
                                            <TableCell>
                                                {r.reviewer?.name || '—'}
                                            </TableCell>
                                            <TableCell>
                                                {r.product?.name || '—'}
                                            </TableCell>
                                            <TableCell className="max-w-xs truncate text-sm">
                                                {r.comment || '—'}
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="secondary">
                                                    {r.status}
                                                </Badge>
                                            </TableCell>
                                            {(canModerate || canDelete) && (
                                                <TableCell>
                                                    <div className="flex items-center justify-end gap-1">
                                                        {canModerate && (
                                                            <>
                                                                <Button
                                                                    variant="ghost"
                                                                    size="icon"
                                                                    type="button"
                                                                    className="cursor-pointer"
                                                                    title="Publish"
                                                                    onClick={() =>
                                                                        setStatus(
                                                                            r.id,
                                                                            'published',
                                                                        )
                                                                    }
                                                                >
                                                                    <CheckCircle2 className="h-4 w-4" />
                                                                    <span className="sr-only">
                                                                        Publish
                                                                    </span>
                                                                </Button>
                                                                <Button
                                                                    variant="ghost"
                                                                    size="icon"
                                                                    type="button"
                                                                    className="cursor-pointer"
                                                                    title="Hide"
                                                                    onClick={() =>
                                                                        setStatus(
                                                                            r.id,
                                                                            'hidden',
                                                                        )
                                                                    }
                                                                >
                                                                    <EyeOff className="h-4 w-4" />
                                                                    <span className="sr-only">
                                                                        Hide
                                                                    </span>
                                                                </Button>
                                                            </>
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
                                                                        r.id,
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
                                            )}
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
