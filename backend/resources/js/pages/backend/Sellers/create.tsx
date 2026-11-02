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

interface UserOption {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    label: string;
}

interface Props {
    statuses: string[];
    business_types: string[];
    users: UserOption[];
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Sellers', href: '/admin/sellers' },
    { title: 'New seller', href: '/admin/sellers/create' },
];

export default function SellersCreate({
    statuses,
    business_types,
    users,
}: Props) {
    const { data, setData, post, processing, errors } = useForm({
        user_id: '' as string | number,
        owner_name: '',
        owner_email: '',
        owner_phone: '',
        password: '',
        business_name: '',
        business_type: business_types[0] || 'supplier',
        business_registration_number: '',
        tax_id: '',
        business_phone: '',
        business_email: '',
        website: '',
        description: '',
        status: 'pending',
        commission_rate: '10',
        minimum_order_amount: '0',
        delivery_radius_km: '',
        bank_account_name: '',
        bank_account_number: '',
        bank_name: '',
        bank_branch: '',
    });

    const linkExisting = Boolean(data.user_id);

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post('/admin/sellers');
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Create Seller | SiteDrop Admin">
                <meta name="description" content="Onboard a new seller account." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href="/admin/sellers" />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            New seller
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Create a seller profile and owner account
                        </p>
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <Card>
                        <CardHeader>
                            <CardTitle>Owner account</CardTitle>
                            <CardDescription>
                                Link an existing user or create a new one
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <div className="space-y-2">
                                <Label htmlFor="user_id">
                                    Existing user (optional)
                                </Label>
                                <select
                                    id="user_id"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.user_id}
                                    onChange={(e) =>
                                        setData(
                                            'user_id',
                                            e.target.value
                                                ? Number(e.target.value)
                                                : '',
                                        )
                                    }
                                >
                                    <option value="">
                                        — Create new owner —
                                    </option>
                                    {users.map((u) => (
                                        <option key={u.id} value={u.id}>
                                            {u.label}
                                        </option>
                                    ))}
                                </select>
                            </div>

                            {!linkExisting && (
                                <div className="grid gap-4 md:grid-cols-2">
                                    <div className="space-y-2 md:col-span-2">
                                        <Label htmlFor="owner_name">
                                            Owner name *
                                        </Label>
                                        <Input
                                            id="owner_name"
                                            value={data.owner_name}
                                            onChange={(e) =>
                                                setData(
                                                    'owner_name',
                                                    e.target.value,
                                                )
                                            }
                                            required={!linkExisting}
                                        />
                                        {errors.owner_name && (
                                            <p className="text-sm text-destructive">
                                                {errors.owner_name}
                                            </p>
                                        )}
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="owner_email">
                                            Owner email
                                        </Label>
                                        <Input
                                            id="owner_email"
                                            type="email"
                                            value={data.owner_email}
                                            onChange={(e) =>
                                                setData(
                                                    'owner_email',
                                                    e.target.value,
                                                )
                                            }
                                        />
                                        {errors.owner_email && (
                                            <p className="text-sm text-destructive">
                                                {errors.owner_email}
                                            </p>
                                        )}
                                    </div>
                                    <div className="space-y-2">
                                        <Label htmlFor="owner_phone">
                                            Owner phone
                                        </Label>
                                        <Input
                                            id="owner_phone"
                                            value={data.owner_phone}
                                            onChange={(e) =>
                                                setData(
                                                    'owner_phone',
                                                    e.target.value,
                                                )
                                            }
                                        />
                                    </div>
                                    <div className="space-y-2 md:col-span-2">
                                        <Label htmlFor="password">
                                            Password (default: password123)
                                        </Label>
                                        <Input
                                            id="password"
                                            type="password"
                                            value={data.password}
                                            onChange={(e) =>
                                                setData(
                                                    'password',
                                                    e.target.value,
                                                )
                                            }
                                            placeholder="Optional"
                                        />
                                    </div>
                                </div>
                            )}
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Business profile</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-2">
                            <div className="space-y-2 md:col-span-2">
                                <Label htmlFor="business_name">
                                    Business name *
                                </Label>
                                <Input
                                    id="business_name"
                                    value={data.business_name}
                                    onChange={(e) =>
                                        setData(
                                            'business_name',
                                            e.target.value,
                                        )
                                    }
                                    required
                                />
                                {errors.business_name && (
                                    <p className="text-sm text-destructive">
                                        {errors.business_name}
                                    </p>
                                )}
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="business_type">Type</Label>
                                <select
                                    id="business_type"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.business_type}
                                    onChange={(e) =>
                                        setData(
                                            'business_type',
                                            e.target.value,
                                        )
                                    }
                                >
                                    {business_types.map((t) => (
                                        <option key={t} value={t}>
                                            {t.replace(/_/g, ' ')}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="status">Status</Label>
                                <select
                                    id="status"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.status}
                                    onChange={(e) =>
                                        setData('status', e.target.value)
                                    }
                                >
                                    {statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="business_email">
                                    Business email
                                </Label>
                                <Input
                                    id="business_email"
                                    type="email"
                                    value={data.business_email}
                                    onChange={(e) =>
                                        setData(
                                            'business_email',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="business_phone">
                                    Business phone
                                </Label>
                                <Input
                                    id="business_phone"
                                    value={data.business_phone}
                                    onChange={(e) =>
                                        setData(
                                            'business_phone',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="business_registration_number">
                                    Registration no.
                                </Label>
                                <Input
                                    id="business_registration_number"
                                    value={
                                        data.business_registration_number
                                    }
                                    onChange={(e) =>
                                        setData(
                                            'business_registration_number',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="tax_id">Tax ID</Label>
                                <Input
                                    id="tax_id"
                                    value={data.tax_id}
                                    onChange={(e) =>
                                        setData('tax_id', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="commission_rate">
                                    Commission %
                                </Label>
                                <Input
                                    id="commission_rate"
                                    type="number"
                                    step="0.1"
                                    value={data.commission_rate}
                                    onChange={(e) =>
                                        setData(
                                            'commission_rate',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="minimum_order_amount">
                                    Min. order (GHS)
                                </Label>
                                <Input
                                    id="minimum_order_amount"
                                    type="number"
                                    step="0.01"
                                    value={data.minimum_order_amount}
                                    onChange={(e) =>
                                        setData(
                                            'minimum_order_amount',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-2">
                                <Label htmlFor="description">
                                    Description
                                </Label>
                                <textarea
                                    id="description"
                                    className="min-h-[90px] w-full rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.description}
                                    onChange={(e) =>
                                        setData(
                                            'description',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                        </CardContent>
                    </Card>

                    <div className="flex justify-end gap-3">
                        <Button type="button" variant="outline" asChild>
                            <Link href="/admin/sellers">Cancel</Link>
                        </Button>
                        <Button
                            type="submit"
                            disabled={processing}
                            className="cursor-pointer"
                        >
                            {processing ? 'Creating…' : 'Create seller'}
                        </Button>
                    </div>
                </form>
            </div>
        </AppLayout>
    );
}
