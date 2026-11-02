import { Head, Link, useForm } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface Seller {
    id: number;
    business_name: string;
    business_type?: string;
    business_registration_number?: string;
    tax_id?: string;
    business_phone?: string;
    business_email?: string;
    website?: string;
    description?: string;
    status: string;
    commission_rate?: number;
    minimum_order_amount?: number;
    delivery_radius_km?: number;
    bank_account_name?: string;
    bank_account_number?: string;
    bank_name?: string;
    bank_branch?: string;
    rejected_reason?: string;
    user?: {
        id: number;
        name: string;
        email?: string;
        phone?: string;
    } | null;
}

interface Props {
    seller: Seller;
    statuses: string[];
    business_types: string[];
}

export default function SellersEdit({
    seller,
    statuses,
    business_types,
}: Props) {
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Sellers', href: '/admin/sellers' },
        {
            title: seller.business_name,
            href: `/admin/sellers/${seller.id}`,
        },
        { title: 'Edit', href: `/admin/sellers/${seller.id}/edit` },
    ];

    const { data, setData, put, processing, errors } = useForm({
        owner_name: seller.user?.name || '',
        owner_email: seller.user?.email || '',
        owner_phone: seller.user?.phone || '',
        password: '',
        business_name: seller.business_name || '',
        business_type: seller.business_type || business_types[0] || 'supplier',
        business_registration_number:
            seller.business_registration_number || '',
        tax_id: seller.tax_id || '',
        business_phone: seller.business_phone || '',
        business_email: seller.business_email || '',
        website: seller.website || '',
        description: seller.description || '',
        status: seller.status || 'pending',
        commission_rate: String(seller.commission_rate ?? 10),
        minimum_order_amount: String(seller.minimum_order_amount ?? 0),
        delivery_radius_km: String(seller.delivery_radius_km ?? ''),
        bank_account_name: seller.bank_account_name || '',
        bank_account_number: seller.bank_account_number || '',
        bank_name: seller.bank_name || '',
        bank_branch: seller.bank_branch || '',
        rejected_reason: seller.rejected_reason || '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        put(`/admin/sellers/${seller.id}`);
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Edit ${seller.business_name} | Seller`}>
                <meta name="description" content={`Edit seller profile for ${seller.business_name}.`} />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={`/admin/sellers/${seller.id}`} />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Edit seller
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Update business profile and owner details
                        </p>
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <Card>
                        <CardHeader>
                            <CardTitle>Owner (User)</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-2">
                            <div className="space-y-2 md:col-span-2">
                                <Label htmlFor="owner_name">Name</Label>
                                <Input
                                    id="owner_name"
                                    value={data.owner_name}
                                    onChange={(e) =>
                                        setData('owner_name', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="owner_email">Email</Label>
                                <Input
                                    id="owner_email"
                                    type="email"
                                    value={data.owner_email}
                                    onChange={(e) =>
                                        setData('owner_email', e.target.value)
                                    }
                                />
                                {errors.owner_email && (
                                    <p className="text-sm text-destructive">
                                        {errors.owner_email}
                                    </p>
                                )}
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="owner_phone">Phone</Label>
                                <Input
                                    id="owner_phone"
                                    value={data.owner_phone}
                                    onChange={(e) =>
                                        setData('owner_phone', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-2">
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
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Business (SellerProfile)</CardTitle>
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
                            {data.status === 'rejected' && (
                                <div className="space-y-2 md:col-span-2">
                                    <Label htmlFor="rejected_reason">
                                        Rejection reason
                                    </Label>
                                    <Input
                                        id="rejected_reason"
                                        value={data.rejected_reason}
                                        onChange={(e) =>
                                            setData(
                                                'rejected_reason',
                                                e.target.value,
                                            )
                                        }
                                    />
                                </div>
                            )}
                        </CardContent>
                    </Card>

                    <div className="flex justify-end gap-3">
                        <Button type="button" variant="outline" asChild>
                            <Link href={`/admin/sellers/${seller.id}`}>
                                Cancel
                            </Link>
                        </Button>
                        <Button
                            type="submit"
                            disabled={processing}
                            className="cursor-pointer"
                        >
                            {processing ? 'Saving…' : 'Save changes'}
                        </Button>
                    </div>
                </form>
            </div>
        </AppLayout>
    );
}
