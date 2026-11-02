// resources/js/pages/backend/Users/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Search, Plus, Eye, Edit } from 'lucide-react';

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
import { usePermissions } from '@/hooks/usePermissions';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface User {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    role?: string;
    roles: string[];
    phone_verified?: boolean;
    last_active_at?: string | null;
    avatar_url?: string;
}

interface UsersPaginated {
    data: User[];
    current_page: number;
    last_page: number;
    total: number;
    links: { url: string | null; label: string; active: boolean }[];
}

interface Props {
    users: UsersPaginated;
    filters: Record<string, string | null>;
    roles: string[];
    can?: { create?: boolean; impersonate?: boolean };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Users', href: '/admin/users' },
];

export default function UsersIndex({ users, filters, roles, can: canProps }: Props) {
    const { can } = usePermissions();

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = {};
        formData.forEach((value, key) => {
            if (value.toString().trim()) {
                query[key] = value.toString().trim();
            }
        });
        router.get('/admin/users', query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Users | SiteDrop Admin">
                <meta name="description" content="Manage platform users, admins and role assignments." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            System Users
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Manage platform accounts and roles
                        </p>
                    </div>

                    {(canProps?.create || can('create users')) && (
                        <Button asChild className="cursor-pointer">
                            <Link href="/admin/users/create">
                                <Plus className="mr-2 h-4 w-4" />
                                Add New User
                            </Link>
                        </Button>
                    )}
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>Users ({users.total})</CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 flex-col gap-4 sm:flex-row sm:items-end sm:justify-end"
                            >
                                <div className="min-w-[220px] flex-1">
                                    <div className="relative">
                                        <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                        <Input
                                            name="search"
                                            placeholder="Name, email, phone..."
                                            className="pl-9"
                                            defaultValue={filters.search ?? ''}
                                        />
                                    </div>
                                </div>
                                <div className="w-full sm:w-48">
                                    <select
                                        name="role"
                                        className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                        defaultValue={filters.role ?? ''}
                                    >
                                        <option value="">All roles</option>
                                        {roles.map((role) => (
                                            <option key={role} value={role}>
                                                {role}
                                            </option>
                                        ))}
                                    </select>
                                </div>
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
                                        <TableHead className="w-12">Avatar</TableHead>
                                        <TableHead>Name</TableHead>
                                        <TableHead>Email</TableHead>
                                        <TableHead>Phone</TableHead>
                                        <TableHead>Roles</TableHead>
                                        <TableHead>Phone verified</TableHead>
                                        <TableHead className="text-right">
                                            Actions
                                        </TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {users.data.length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={7}
                                                className="py-10 text-center text-muted-foreground"
                                            >
                                                No users found
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        users.data.map((user) => (
                                            <TableRow key={user.id}>
                                                <TableCell>
                                                    <div className="h-8 w-8 overflow-hidden rounded-full border bg-muted">
                                                        <img
                                                            src={
                                                                user.avatar_url ||
                                                                `https://ui-avatars.com/api/?name=${encodeURIComponent(user.name)}&background=random`
                                                            }
                                                            alt={user.name}
                                                            className="h-full w-full object-cover"
                                                        />
                                                    </div>
                                                </TableCell>
                                                <TableCell className="font-medium">
                                                    {user.name}
                                                </TableCell>
                                                <TableCell>
                                                    {user.email || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {user.phone || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    <div className="flex flex-wrap gap-1">
                                                        {(user.roles?.length
                                                            ? user.roles
                                                            : [user.role || 'buyer']
                                                        ).map((role: string) => (
                                                            <Badge
                                                                key={role}
                                                                variant="secondary"
                                                                className="text-xs"
                                                            >
                                                                {role}
                                                            </Badge>
                                                        ))}
                                                    </div>
                                                </TableCell>
                                                <TableCell>
                                                    <Badge
                                                        variant={
                                                            user.phone_verified
                                                                ? 'default'
                                                                : 'outline'
                                                        }
                                                    >
                                                        {user.phone_verified
                                                            ? 'Yes'
                                                            : 'No'}
                                                    </Badge>
                                                </TableCell>
                                                <TableCell className="text-right">
                                                    <div className="flex items-center justify-end gap-2">
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            asChild
                                                        >
                                                            <Link
                                                                href={`/admin/users/${user.id}`}
                                                            >
                                                                <Eye className="h-4 w-4" />
                                                            </Link>
                                                        </Button>
                                                        {(can('update users') ||
                                                            canProps?.create) && (
                                                            <Button
                                                                variant="ghost"
                                                                size="icon"
                                                                asChild
                                                            >
                                                                <Link
                                                                    href={`/admin/users/${user.id}/edit`}
                                                                >
                                                                    <Edit className="h-4 w-4" />
                                                                </Link>
                                                            </Button>
                                                        )}
                                                    </div>
                                                </TableCell>
                                            </TableRow>
                                        ))
                                    )}
                                </TableBody>
                            </Table>
                        </div>

                        {users.last_page > 1 && (
                            <div className="mt-4 flex flex-wrap gap-2">
                                {users.links.map((link, i) =>
                                    link.url ? (
                                        <Button
                                            key={i}
                                            size="sm"
                                            variant={
                                                link.active
                                                    ? 'default'
                                                    : 'outline'
                                            }
                                            onClick={() => router.get(link.url!)}
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
