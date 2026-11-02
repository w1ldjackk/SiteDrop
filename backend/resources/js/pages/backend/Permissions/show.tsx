// resources/js/pages/backend/Permissions/show.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Edit, Trash2, Users } from 'lucide-react';
import { IosBackButton } from '@/components/ios-back-button';

import { Badge } from '@/components/ui/badge';
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

interface User {
    id: number;
    name: string;
    email: string;
}

interface Role {
    id: number;
    name: string;
    guard_name: string;
    users?: User[];
}

interface Permission {
    id: number;
    name: string;
    guard_name: string;
    section?: string;
    roles: Role[];
}

interface Props {
    permission: Permission;
    can: {
        update: boolean;
        delete: boolean;
    };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Permissions', href: '/admin/permissions' },
    {
        title: 'Permission Details',
        href: '',
    },
];

export default function PermissionShow({ permission, can }: Props) {
    const handleDelete = () => {
        if (
            !confirm(
                `Delete permission "${permission.name}"? Roles that use it will lose this ability.`,
            )
        ) {
            return;
        }
        router.delete(`/admin/permissions/${permission.id}`);
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${permission.name} | Permission`}>
                <meta name="description" content={`Permission details for ${permission.name}.`} />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex items-center gap-4">
                        <IosBackButton href="/admin/permissions" />
                        <div>
                            <h1 className="text-2xl font-bold tracking-tight">
                                {permission.name}
                            </h1>
                            <p className="text-sm text-muted-foreground">
                                Guard: {permission.guard_name}
                                {permission.section &&
                                    ` • Section: ${permission.section}`}
                            </p>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        {can.update && (
                            <Button variant="outline" asChild>
                                <Link
                                    href={`/admin/permissions/${permission.id}/edit`}
                                >
                                    <Edit className="mr-2 h-4 w-4" />
                                    Edit Permission
                                </Link>
                            </Button>
                        )}
                        {can.delete && (
                            <Button
                                variant="destructive"
                                type="button"
                                className="cursor-pointer"
                                onClick={handleDelete}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete Permission
                            </Button>
                        )}
                    </div>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Users className="h-5 w-5" />
                            Assigned Roles ({permission.roles?.length ?? 0})
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {permission.roles?.length ? (
                            <div className="rounded-md border">
                                <Table>
                                    <TableHeader>
                                        <TableRow>
                                            <TableHead>Role Name</TableHead>
                                            <TableHead>Guard</TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {permission.roles.map((role) => (
                                            <TableRow key={role.id}>
                                                <TableCell className="font-medium">
                                                    {role.name}
                                                </TableCell>
                                                <TableCell>
                                                    <Badge variant="outline">
                                                        {role.guard_name}
                                                    </Badge>
                                                </TableCell>
                                            </TableRow>
                                        ))}
                                    </TableBody>
                                </Table>
                            </div>
                        ) : (
                            <p className="text-sm text-muted-foreground">
                                This permission is not assigned to any roles
                                yet.
                            </p>
                        )}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
