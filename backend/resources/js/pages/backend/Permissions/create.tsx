// resources/js/pages/backend/Permissions/create.tsx
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
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Permissions', href: '/admin/permissions' },
    {
        title: 'Create Permission',
        href: '',
    },
];

export default function PermissionCreate() {
    const { data, setData, post, processing, errors } = useForm({
        name: '',
        section: '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post('/admin/permissions');
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Create Permission | SiteDrop Admin">
                <meta name="description" content="Create a new system permission." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-4">
                    <IosBackButton href="/admin/permissions" />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Create New Permission
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Define a new permission for the system
                        </p>
                    </div>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Permission Details</CardTitle>
                        <CardDescription>
                            Enter permission name and optional section
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleSubmit} className="space-y-6">
                            <div className="space-y-2">
                                <Label htmlFor="name">Permission Name *</Label>
                                <Input
                                    id="name"
                                    value={data.name}
                                    onChange={(e) =>
                                        setData('name', e.target.value)
                                    }
                                    placeholder="e.g. view orders, manage sellers"
                                />
                                {errors.name && (
                                    <p className="text-sm text-destructive">
                                        {errors.name}
                                    </p>
                                )}
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="section">
                                    Section (optional)
                                </Label>
                                <Input
                                    id="section"
                                    value={data.section}
                                    onChange={(e) =>
                                        setData('section', e.target.value)
                                    }
                                    placeholder="e.g. User Management, Orders, Sellers"
                                />
                                {errors.section && (
                                    <p className="text-sm text-destructive">
                                        {errors.section}
                                    </p>
                                )}
                            </div>

                            <div className="flex justify-end gap-4">
                                <Button type="button" variant="outline" asChild>
                                    <Link href="/admin/permissions">
                                        Cancel
                                    </Link>
                                </Button>
                                <Button type="submit" disabled={processing}>
                                    {processing
                                        ? 'Creating...'
                                        : 'Create Permission'}
                                </Button>
                            </div>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
