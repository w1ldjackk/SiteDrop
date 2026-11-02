// resources/js/pages/backend/Roles/create.tsx
import { Head, Link, useForm } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';

import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface Permission {
    id: number;
    name: string;
    section?: string;
}

interface Props {
    permissions: Permission[];
    initial?: {
        name: string;
        permissions: number[];
    };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Roles', href: '/admin/roles' },
    { title: 'New Role', href: '' },
];

export default function RoleCreate({ permissions, initial }: Props) {
    const { data, setData, post, processing, errors, transform } = useForm(
        initial ?? {
            name: '',
            permissions: [] as number[],
        },
    );

    const selectedIds = (data.permissions ?? []).map((id) => Number(id));

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        transform((form) => ({
            ...form,
            permissions: (form.permissions ?? []).map((id) => Number(id)),
        }));
        post('/admin/roles');
    };

    const togglePermission = (permissionId: number) => {
        const id = Number(permissionId);
        setData((current) => {
            const currentPerms = (Array.isArray(current.permissions)
                ? current.permissions
                : []
            ).map((x) => Number(x));

            const updatedPerms = currentPerms.includes(id)
                ? currentPerms.filter((x) => x !== id)
                : [...currentPerms, id];

            return {
                ...current,
                permissions: updatedPerms,
            };
        });
    };

    // Group permissions by section
    const groupedPermissions = permissions.reduce(
        (groups, permission) => {
            const section = permission.section || 'General';
            if (!groups[section]) groups[section] = [];
            groups[section].push(permission);
            return groups;
        },
        {} as Record<string, Permission[]>,
    );

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Create Role | SiteDrop Admin">
                <meta name="description" content="Create a new role with selected permissions." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                {/* Header */}
                <div className="flex items-center gap-4">
                    <IosBackButton href="/admin/roles" />
                    <div>
                        <h1 className="text-3xl font-bold tracking-tight">
                            New Role
                        </h1>
                        <p className="text-muted-foreground">
                            Create a new role and assign permissions
                        </p>
                    </div>
                </div>

                <Card className="overflow-hidden">
                    <CardHeader className="pb-4">
                        <CardTitle>Role Information</CardTitle>
                        <CardDescription>
                            Set the role name and select required permissions
                        </CardDescription>
                    </CardHeader>

                    <CardContent className="space-y-8">
                        <form onSubmit={handleSubmit} className="space-y-8">
                            {/* Role Name */}
                            <div className="space-y-2">
                                <Label htmlFor="name" className="text-base">
                                    Role Name
                                </Label>
                                <Input
                                    id="name"
                                    value={data.name}
                                    onChange={(e) =>
                                        setData('name', e.target.value)
                                    }
                                    placeholder="e.g. ops-manager, support, auditor"
                                    className="text-base"
                                />
                                {errors.name && (
                                    <p className="text-sm text-destructive">
                                        {errors.name}
                                    </p>
                                )}
                            </div>

                            <Separator />

                            {/* Permissions Section */}
                            <div className="space-y-6">
                                <div className="flex items-center justify-between">
                                    <Label className="text-base">
                                        Permissions
                                    </Label>
                                    <span className="text-sm text-muted-foreground">
                                        {selectedIds.length} selected
                                    </span>
                                </div>

                                <div className="space-y-8">
                                    {Object.entries(groupedPermissions).map(
                                        ([section, perms]) => (
                                            <div
                                                key={section}
                                                className="space-y-4"
                                            >
                                                <div className="flex items-center gap-2">
                                                    <div className="h-px flex-1 bg-border" />
                                                    <h3 className="text-sm font-semibold tracking-widest text-muted-foreground uppercase">
                                                        {section}
                                                    </h3>
                                                    <div className="h-px flex-1 bg-border" />
                                                </div>

                                                {/* Compact permission cards */}
                                                <div className="grid grid-cols-1 gap-2 md:grid-cols-2 lg:grid-cols-3">
                                                    {perms.map((permission) => (
                                                        <label
                                                            key={permission.id}
                                                            htmlFor={`perm-${permission.id}`}
                                                            className="group flex cursor-pointer items-center gap-3 rounded-md border p-3 text-sm transition-all hover:bg-muted/50"
                                                        >
                                                            <Checkbox
                                                                id={`perm-${permission.id}`}
                                                                checked={selectedIds.includes(
                                                                    Number(
                                                                        permission.id,
                                                                    ),
                                                                )}
                                                                onCheckedChange={() =>
                                                                    togglePermission(
                                                                        permission.id,
                                                                    )
                                                                }
                                                                className="mt-0.5"
                                                            />
                                                            <span className="flex-1 font-medium group-hover:text-foreground">
                                                                {
                                                                    permission.name
                                                                }
                                                            </span>
                                                        </label>
                                                    ))}
                                                </div>
                                            </div>
                                        ),
                                    )}
                                </div>

                                {errors.permissions && (
                                    <p className="text-sm text-destructive">
                                        {errors.permissions}
                                    </p>
                                )}
                            </div>

                            {/* Actions */}
                            <div className="flex justify-end gap-3 border-t pt-6">
                                <Button type="button" variant="outline" asChild>
                                    <Link href="/admin/roles">Cancel</Link>
                                </Button>
                                <Button
                                    type="submit"
                                    disabled={processing}
                                    size="lg"
                                >
                                    {processing
                                        ? 'Creating Role...'
                                        : 'Create Role'}
                                </Button>
                            </div>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
