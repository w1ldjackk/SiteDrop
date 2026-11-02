// resources/js/pages/backend/Roles/show.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Edit, Trash2, Shield, Users } from 'lucide-react';
import { IosBackButton } from '@/components/ios-back-button';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
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
}

interface RoleUser {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    role?: string;
}

interface Role {
    id: number;
    name: string;
    guard_name: string;
    is_protected?: boolean;
    permissions: Permission[];
    users: RoleUser[];
    users_count: number;
}

interface Props {
    role: Role;
    can: {
        update: boolean;
        delete: boolean;
    };
}

export default function RoleShow({ role, can }: Props) {
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Roles', href: '/admin/roles' },
        { title: role.name, href: `/admin/roles/${role.id}` },
    ];

    const grouped = role.permissions.reduce(
        (acc, p) => {
            const section = p.section || 'General';
            if (!acc[section]) acc[section] = [];
            acc[section].push(p);
            return acc;
        },
        {} as Record<string, Permission[]>,
    );

    const handleDelete = () => {
        if (
            !confirm(
                `Delete role "${role.name}"? Users will lose this role assignment.`,
            )
        ) {
            return;
        }
        router.delete(`/admin/roles/${role.id}`);
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${role.name} | Role`}>
                <meta name="description" content={`View role ${role.name} and its permissions.`} />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex items-center gap-3">
                        <IosBackButton href="/admin/roles" />
                        <div>
                            <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                                <Shield className="h-6 w-6 text-primary" />
                                {role.name}
                            </h1>
                            <p className="text-sm text-muted-foreground">
                                Guard:{' '}
                                <span className="font-mono text-xs">
                                    {role.guard_name}
                                </span>
                                {role.is_protected && (
                                    <Badge className="ml-2" variant="secondary">
                                        Protected
                                    </Badge>
                                )}
                            </p>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        {can.update && (
                            <Button variant="outline" asChild>
                                <Link href={`/admin/roles/${role.id}/edit`}>
                                    <Edit className="mr-2 h-4 w-4" />
                                    Edit Role
                                </Link>
                            </Button>
                        )}
                        {can.delete && !role.is_protected && (
                            <Button variant="destructive" onClick={handleDelete}>
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete Role
                            </Button>
                        )}
                    </div>
                </div>

                <div className="grid gap-4 sm:grid-cols-2">
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm text-muted-foreground">
                                Permissions
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">
                            {role.permissions.length}
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader className="pb-2">
                            <CardTitle className="text-sm text-muted-foreground">
                                Users with this role
                            </CardTitle>
                        </CardHeader>
                        <CardContent className="text-2xl font-bold">
                            {role.users_count}
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Permissions by section</CardTitle>
                        <CardDescription>
                            Capabilities granted by this role
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-6">
                        {Object.keys(grouped).length === 0 ? (
                            <p className="text-sm text-muted-foreground">
                                No permissions assigned
                            </p>
                        ) : (
                            Object.entries(grouped).map(([section, perms]) => (
                                <div key={section}>
                                    <h3 className="mb-2 text-sm font-semibold text-primary">
                                        {section}
                                    </h3>
                                    <div className="flex flex-wrap gap-2">
                                        {perms.map((p) => (
                                            <Badge
                                                key={p.id}
                                                variant="secondary"
                                            >
                                                {p.name}
                                            </Badge>
                                        ))}
                                    </div>
                                </div>
                            ))
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Users className="h-5 w-5" />
                            Assigned users
                        </CardTitle>
                        <CardDescription>
                            Showing up to 50 users with this role
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="overflow-x-auto rounded-md border">
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Name</TableHead>
                                        <TableHead>Email</TableHead>
                                        <TableHead>Phone</TableHead>
                                        <TableHead>Primary role</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {(role.users || []).length === 0 ? (
                                        <TableRow>
                                            <TableCell
                                                colSpan={4}
                                                className="py-8 text-center text-muted-foreground"
                                            >
                                                No users assigned
                                            </TableCell>
                                        </TableRow>
                                    ) : (
                                        role.users.map((u) => (
                                            <TableRow key={u.id}>
                                                <TableCell className="font-medium">
                                                    <Link
                                                        href={`/admin/users/${u.id}`}
                                                        className="cursor-pointer text-primary hover:underline"
                                                    >
                                                        {u.name}
                                                    </Link>
                                                </TableCell>
                                                <TableCell>
                                                    {u.email || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {u.phone || '—'}
                                                </TableCell>
                                                <TableCell>
                                                    {u.role || '—'}
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
