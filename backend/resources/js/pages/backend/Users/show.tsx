// resources/js/pages/backend/Users/show.tsx
import { Head, Link } from '@inertiajs/react';
import { Edit } from 'lucide-react';

import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface User {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    role?: string;
    phone_verified?: boolean;
    last_active_at?: string | null;
    created_at?: string | null;
    avatar_url?: string;
    roles: string[];
}

interface Props {
    user: User;
    can: {
        update: boolean;
        delete: boolean;
    };
}

export default function UsersShow({ user, can }: Props) {
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Users', href: '/admin/users' },
        { title: user.name, href: `/admin/users/${user.id}` },
    ];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${user.name} | User Profile`}>
                <meta name="description" content={`View user profile for ${user.name}.`} />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex items-center gap-3">
                        <IosBackButton href="/admin/users" />
                        <div className="flex items-center gap-3">
                            <div className="h-12 w-12 overflow-hidden rounded-full border bg-muted">
                                <img
                                    src={
                                        user.avatar_url ||
                                        `https://ui-avatars.com/api/?name=${encodeURIComponent(user.name)}&background=random`
                                    }
                                    alt={user.name}
                                    className="h-full w-full object-cover"
                                />
                            </div>
                            <div>
                                <h1 className="text-2xl font-bold tracking-tight">
                                    {user.name}
                                </h1>
                                <p className="text-sm text-muted-foreground">
                                    {(user.roles?.length
                                        ? user.roles
                                        : [user.role || 'buyer']
                                    ).join(' • ')}
                                </p>
                            </div>
                        </div>
                    </div>

                    {can.update && (
                        <Button variant="outline" asChild>
                            <Link href={`/admin/users/${user.id}/edit`}>
                                <Edit className="mr-2 h-4 w-4" />
                                Edit
                            </Link>
                        </Button>
                    )}
                </div>

                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Contact</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <p>
                                <span className="text-muted-foreground">Email: </span>
                                {user.email || '—'}
                            </p>
                            <p>
                                <span className="text-muted-foreground">Phone: </span>
                                {user.phone || '—'}
                            </p>
                            <p>
                                <span className="text-muted-foreground">
                                    Phone verified:{' '}
                                </span>
                                <Badge
                                    variant={
                                        user.phone_verified
                                            ? 'default'
                                            : 'outline'
                                    }
                                >
                                    {user.phone_verified ? 'Yes' : 'No'}
                                </Badge>
                            </p>
                        </CardContent>
                    </Card>
                    <Card>
                        <CardHeader>
                            <CardTitle>Account</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <p>
                                <span className="text-muted-foreground">Primary role: </span>
                                {user.role || '—'}
                            </p>
                            <p>
                                <span className="text-muted-foreground">Roles: </span>
                                {(user.roles || []).join(', ') || '—'}
                            </p>
                            <p>
                                <span className="text-muted-foreground">Last active: </span>
                                {user.last_active_at || '—'}
                            </p>
                            <p>
                                <span className="text-muted-foreground">Joined: </span>
                                {user.created_at || '—'}
                            </p>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </AppLayout>
    );
}
