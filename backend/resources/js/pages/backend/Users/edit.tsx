// resources/js/pages/backend/Users/edit.tsx
import { Head, useForm } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface User {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    roles: string[];
}

interface Props {
    user: User;
    /** Role names from App\Models\Role (Spatie, web guard) */
    roles: string[];
}

export default function UsersEdit({ user, roles }: Props) {
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Users', href: '/admin/users' },
        { title: user.name, href: `/admin/users/${user.id}` },
        { title: 'Edit', href: `/admin/users/${user.id}/edit` },
    ];

    const { data, setData, put, processing, errors } = useForm({
        name: user.name,
        email: user.email || '',
        phone: user.phone || '',
        roles: user.roles ?? [],
        password: '',
    });

    const toggleRole = (role: string) => {
        setData((current) => {
            const selected = current.roles.includes(role)
                ? current.roles.filter((r) => r !== role)
                : [...current.roles, role];
            return { ...current, roles: selected };
        });
    };

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        put(`/admin/users/${user.id}`, { preserveScroll: true });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Edit ${user.name} | User`}>
                <meta name="description" content={`Edit user account for ${user.name}.`} />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={`/admin/users/${user.id}`} />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Edit User
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Update account details and roles for {user.name}
                        </p>
                    </div>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>User information</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <form onSubmit={handleSubmit} className="space-y-5">
                            <div className="space-y-2">
                                <Label htmlFor="name">Name</Label>
                                <Input
                                    id="name"
                                    value={data.name}
                                    onChange={(e) =>
                                        setData('name', e.target.value)
                                    }
                                    required
                                />
                                {errors.name && (
                                    <p className="text-sm text-destructive">
                                        {errors.name}
                                    </p>
                                )}
                            </div>

                            <div className="grid gap-4 md:grid-cols-2">
                                <div className="space-y-2">
                                    <Label htmlFor="email">Email</Label>
                                    <Input
                                        id="email"
                                        type="email"
                                        value={data.email}
                                        onChange={(e) =>
                                            setData('email', e.target.value)
                                        }
                                    />
                                </div>
                                <div className="space-y-2">
                                    <Label htmlFor="phone">Phone</Label>
                                    <Input
                                        id="phone"
                                        value={data.phone}
                                        onChange={(e) =>
                                            setData('phone', e.target.value)
                                        }
                                    />
                                </div>
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="password">
                                    New password (optional)
                                </Label>
                                <Input
                                    id="password"
                                    type="password"
                                    value={data.password}
                                    onChange={(e) =>
                                        setData('password', e.target.value)
                                    }
                                    placeholder="Leave blank to keep current"
                                />
                            </div>

                            <div className="space-y-2">
                                <Label>Roles *</Label>
                                <p className="text-xs text-muted-foreground">
                                    Assign roles from Roles management. Stored
                                    only via Spatie (no separate primary role).
                                </p>
                                <div className="flex flex-wrap gap-2">
                                    {roles.map((role) => (
                                        <button
                                            key={role}
                                            type="button"
                                            onClick={() => toggleRole(role)}
                                            className={`cursor-pointer rounded-full border px-3 py-1.5 text-xs font-medium transition-colors ${
                                                data.roles.includes(role)
                                                    ? 'border-primary bg-primary text-primary-foreground'
                                                    : 'bg-background hover:bg-muted'
                                            }`}
                                        >
                                            {role}
                                        </button>
                                    ))}
                                </div>
                                {errors.roles && (
                                    <p className="text-sm text-destructive">
                                        {errors.roles}
                                    </p>
                                )}
                            </div>

                            <Button type="submit" disabled={processing}>
                                {processing ? 'Saving…' : 'Save changes'}
                            </Button>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
