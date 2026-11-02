// resources/js/pages/backend/Permissions/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import {
    Edit,
    Trash2,
    Eye,
    Plus,
    Search,
    ChevronLeft,
    ChevronRight,
} from 'lucide-react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
    Pagination,
    PaginationContent,
    PaginationEllipsis,
    PaginationItem,
    PaginationLink,
} from '@/components/ui/pagination';
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

interface Permission {
    id: number;
    name: string;
    guard_name: string;
    section?: string;
    roles_count: number;
}

interface PaginationLink {
    url: string | null;
    label: string;
    active: boolean;
}

interface Props {
    permissions: {
        data: Permission[];
        current_page: number;
        last_page: number;
        per_page: number;
        total: number;
        links: PaginationLink[];
    };
    filters: { search?: string };
    can: {
        create: boolean;
    };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Permissions', href: '/admin/permissions' },
];

export default function PermissionsIndex({ permissions, filters, can }: Props) {
    const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        router.get('/admin/permissions', Object.fromEntries(formData), {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Permissions | SiteDrop Admin">
                <meta name="description" content="Manage system permissions and access control." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                {/* Header */}
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Permissions
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Manage system permissions
                        </p>
                    </div>

                    {/* {can.create && ( */}
                    <Button asChild>
                        <Link href="/admin/permissions/create">
                            <Plus className="mr-2 h-4 w-4" />
                            New Permission
                        </Link>
                    </Button>
                    {/* )} */}
                </div>

                {/* Main Table Card with integrated filter */}
                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>All Permissions</CardTitle>

                            <form
                                onSubmit={handleSearch}
                                className="flex w-full max-w-sm items-center gap-2"
                            >
                                <div className="relative flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Search by name or section..."
                                        className="pl-9"
                                        defaultValue={filters.search}
                                    />
                                </div>
                                <Button type="submit" size="sm">
                                    Filter
                                </Button>
                            </form>
                        </div>
                    </CardHeader>

                    <CardContent>
                        <div className="rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Permission Name</TableHead>
                                        <TableHead>Section</TableHead>
                                        <TableHead>Roles</TableHead>
                                        <TableHead className="w-24 text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {permissions.data.map((permission) => (
                                        <TableRow
                                            key={permission.id}
                                            className="hover:bg-muted/40"
                                        >
                                            <TableCell className="font-medium">
                                                {permission.name}
                                            </TableCell>
                                            <TableCell>
                                                {permission.section ? (
                                                    <Badge variant="outline">
                                                        {permission.section}
                                                    </Badge>
                                                ) : (
                                                    '-'
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="secondary">
                                                    {permission.roles_count}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="text-right">
                                                <div className="flex justify-end gap-1">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={`/admin/permissions/${permission.id}`}
                                                        >
                                                            <Eye className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                View permission
                                                            </span>
                                                        </Link>
                                                    </Button>

                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={`/admin/permissions/${permission.id}/edit`}
                                                        >
                                                            <Edit className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                Edit permission
                                                            </span>
                                                        </Link>
                                                    </Button>

                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="text-destructive hover:bg-destructive/10 hover:text-destructive/90"
                                                    >
                                                        <Trash2 className="h-4 w-4" />
                                                        <span className="sr-only">
                                                            Delete permission
                                                        </span>
                                                    </Button>
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))}

                                    {permissions.data.length === 0 && (
                                        <TableRow>
                                            <TableCell
                                                colSpan={4}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No permissions found.
                                            </TableCell>
                                        </TableRow>
                                    )}
                                </TableBody>
                            </Table>
                        </div>

                        {/* Pagination */}
                        <div className="mt-6 flex justify-center">
                            <Pagination>
                                <PaginationContent>
                                    {permissions.links.map((link, index) => (
                                        <PaginationItem key={index}>
                                            {link.url ? (
                                                <PaginationLink
                                                    href={link.url}
                                                    isActive={link.active}
                                                    onClick={(e) => {
                                                        e.preventDefault();
                                                        if (link.url) {
                                                            router.get(
                                                                link.url,
                                                                {},
                                                                {
                                                                    preserveState: true,
                                                                },
                                                            );
                                                        }
                                                    }}
                                                >
                                                    {link.label ===
                                                    '&laquo; Previous' ? (
                                                        <ChevronLeft className="h-4 w-4" />
                                                    ) : link.label ===
                                                      'Next &raquo;' ? (
                                                        <ChevronRight className="h-4 w-4" />
                                                    ) : (
                                                        link.label
                                                    )}
                                                </PaginationLink>
                                            ) : (
                                                <PaginationEllipsis />
                                            )}
                                        </PaginationItem>
                                    ))}
                                </PaginationContent>
                            </Pagination>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
