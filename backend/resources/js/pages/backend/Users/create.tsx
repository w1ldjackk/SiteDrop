// resources/js/pages/backend/Users/create.tsx
import { Head, useForm } from '@inertiajs/react';
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
    { title: 'Users', href: '/admin/users' },
    { title: 'Add New User', href: '/admin/users/create' },
];

interface Props {
    /** Role names from App\Models\Role (Spatie, web guard) */
    roles: string[];
}

export default function UsersCreate({ roles }: Props) {
    const defaultRole = roles.includes('buyer')
        ? 'buyer'
        : roles[0] || '';

    const { data, setData, post, processing, errors } = useForm({
        name: '',
        email: '',
        phone: '',
        password: '',
        roles: defaultRole ? [defaultRole] : ([] as string[]),
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
        post('/admin/users');
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Create User | SiteDrop Admin">
                <meta name="description" content="Add a new user to the platform." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href="/admin/users" />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Add New User
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Create a platform account and assign roles
                        </p>
                    </div>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>User information</CardTitle>
                        <CardDescription>
                            Name, contact, password and roles (Spatie)
                        </CardDescription>
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
                                    {errors.email && (
                                        <p className="text-sm text-destructive">
                                            {errors.email}
                                        </p>
                                    )}
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
                                    {errors.phone && (
                                        <p className="text-sm text-destructive">
                                            {errors.phone}
                                        </p>
                                    )}
                                </div>
                            </div>

                            <div className="space-y-2">
                                <Label htmlFor="password">Password</Label>
                                <Input
                                    id="password"
                                    type="password"
                                    value={data.password}
                                    onChange={(e) =>
                                        setData('password', e.target.value)
                                    }
                                    required
                                />
                                {errors.password && (
                                    <p className="text-sm text-destructive">
                                        {errors.password}
                                    </p>
                                )}
                            </div>

                            <div className="space-y-2">
                                <Label>Roles *</Label>
                                <p className="text-xs text-muted-foreground">
                                    Select one or more roles from Roles
                                    management. These are stored via Spatie
                                    (model_roles).
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
                                    {roles.length === 0 && (
                                        <p className="text-sm text-muted-foreground">
                                            No roles found. Create roles under
                                            Admin → Roles first.
                                        </p>
                                    )}
                                </div>
                                {errors.roles && (
                                    <p className="text-sm text-destructive">
                                        {errors.roles}
                                    </p>
                                )}
                            </div>

                            <Button type="submit" disabled={processing}>
                                {processing ? 'Creating…' : 'Create user'}
                            </Button>
                        </form>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
