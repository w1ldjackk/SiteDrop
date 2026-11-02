// resources/js/pages/backend/Roles/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import {
    Plus,
    Edit,
    Eye,
    Search,
    ChevronLeft,
    ChevronRight,
    Shield,
    Users,
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

interface Role {
    id: number;
    name: string;
    permissions_count: number;
    users_count?: number;
}

interface PaginationLink {
    url: string | null;
    label: string;
    active: boolean;
}

interface Props {
    roles: {
        data: Role[];
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
    { title: 'Roles', href: '/admin/roles' },
];

export default function RolesIndex({ roles, filters, can }: Props) {
    const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        router.get('/admin/roles', Object.fromEntries(formData), {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Roles | SiteDrop Admin">
                <meta name="description" content="Manage user roles and assigned permissions." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                {/* Header */}
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight">
                            Roles
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Manage user roles and their permissions
                        </p>
                    </div>

                    {can.create && (
                        <Button asChild>
                            <Link href="/admin/roles/create">
                                <Plus className="mr-2 h-4 w-4" />
                                New Role
                            </Link>
                        </Button>
                    )}
                </div>

                {/* Main Table Card */}
                <Card>
                    <CardHeader className="pb-4">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>All Roles</CardTitle>

                            <form
                                onSubmit={handleSearch}
                                className="flex w-full max-w-sm items-center gap-2"
                            >
                                <div className="relative flex-1">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Search by role name..."
                                        className="pl-9"
                                        defaultValue={filters.search}
                                    />
                                </div>
                                <Button type="submit" size="sm">
                                    Search
                                </Button>
                            </form>
                        </div>
                    </CardHeader>

                    <CardContent>
                        <div className="rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Role Name</TableHead>
                                        <TableHead>Permissions</TableHead>
                                        <TableHead>Users</TableHead>
                                        <TableHead className="w-28 text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {roles.data.map((role) => (
                                        <TableRow
                                            key={role.id}
                                            className="hover:bg-muted/40"
                                        >
                                            <TableCell className="font-medium">
                                                {role.name}
                                            </TableCell>

                                            {/* Permissions Count */}
                                            <TableCell>
                                                <div className="flex items-center gap-2">
                                                    <Shield className="h-4 w-4 text-muted-foreground" />
                                                    <Badge variant="secondary">
                                                        {role.permissions_count}
                                                    </Badge>
                                                </div>
                                            </TableCell>

                                            {/* Users Count */}
                                            <TableCell>
                                                <div className="flex items-center gap-2">
                                                    <Users className="h-4 w-4 text-muted-foreground" />
                                                    <Badge variant="outline">
                                                        {role.users_count ?? 0}
                                                    </Badge>
                                                </div>
                                            </TableCell>

                                            {/* Actions */}
                                            <TableCell className="text-right">
                                                <div className="flex items-center justify-end gap-1">
                                                    {/* View Button */}
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={`/admin/roles/${role.id}`}
                                                        >
                                                            <Eye className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                View role
                                                            </span>
                                                        </Link>
                                                    </Button>

                                                    {/* Edit Button */}
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={`/admin/roles/${role.id}/edit`}
                                                        >
                                                            <Edit className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                Edit role
                                                            </span>
                                                        </Link>
                                                    </Button>
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))}

                                    {roles.data.length === 0 && (
                                        <TableRow>
                                            <TableCell
                                                colSpan={4}
                                                className="py-12 text-center text-muted-foreground"
                                            >
                                                No roles found.
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
                                    {roles.links.map((link, index) => (
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
