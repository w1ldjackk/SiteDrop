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
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Option {
    id: number;
    label: string;
    seller_id?: number;
    price_per_unit?: number;
}

interface Order {
    id: number;
    order_number: string;
    buyer_id: number;
    seller_id: number;
    product_id: number;
    quantity: number;
    unit_price: number;
    delivery_fee: number;
    service_fee: number;
    discount_amount: number;
    tax_amount: number;
    status: string;
    payment_status: string;
    payment_method?: string;
    delivery_address?: string;
    delivery_phone?: string;
    special_instructions?: string;
    currency?: string;
    cancellation_reason?: string;
}

interface Props {
    order: Order;
    statuses: string[];
    payment_statuses: string[];
    payment_methods: string[];
    buyers: Option[];
    sellers: Option[];
    products: Option[];
    area?: string;
}

export default function OrdersEdit({order,
    statuses,
    payment_statuses,
    payment_methods,
    buyers,
    sellers,
    products, area}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Orders', href: path("orders") },
        {
            title: order.order_number,
            href: path("orders", order.id),
        },
        { title: 'Edit', href: path("orders", order.id, "edit") },
    ];

    
    const { data, setData, put, processing, errors } = useForm({
        buyer_id: String(order.buyer_id || ''),
        seller_id: String(order.seller_id || ''),
        product_id: String(order.product_id || ''),
        quantity: String(order.quantity ?? 1),
        unit_price: String(order.unit_price ?? 0),
        delivery_fee: String(order.delivery_fee ?? 0),
        service_fee: String(order.service_fee ?? 0),
        discount_amount: String(order.discount_amount ?? 0),
        tax_amount: String(order.tax_amount ?? 0),
        status: order.status || 'pending',
        payment_status: order.payment_status || 'pending',
        payment_method: order.payment_method || payment_methods[0] || '',
        delivery_address: order.delivery_address || '',
        delivery_phone: order.delivery_phone || '',
        special_instructions: order.special_instructions || '',
        currency: order.currency || 'GHS',
        cancellation_reason: order.cancellation_reason || '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        put(path("orders", order.id));
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Edit Order ${order.order_number} | Orders`}>
                <meta name="description" content={`Edit order ${order.order_number}.`} />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path("orders", order.id)} />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            Edit order
                        </h1>
                        <p className="font-mono text-sm text-muted-foreground">
                            {order.order_number}
                        </p>
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <Card>
                        <CardHeader>
                            <CardTitle>Parties & product</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-2">
                            <div className="space-y-2">
                                <Label>Buyer</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.buyer_id}
                                    onChange={(e) =>
                                        setData('buyer_id', e.target.value)
                                    }
                                >
                                    {buyers.map((b) => (
                                        <option key={b.id} value={b.id}>
                                            {b.label}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label>Seller</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.seller_id}
                                    onChange={(e) =>
                                        setData('seller_id', e.target.value)
                                    }
                                >
                                    {sellers.map((s) => (
                                        <option key={s.id} value={s.id}>
                                            {s.label}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2 md:col-span-2">
                                <Label>Product</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.product_id}
                                    onChange={(e) =>
                                        setData('product_id', e.target.value)
                                    }
                                >
                                    {products.map((p) => (
                                        <option key={p.id} value={p.id}>
                                            {p.label}
                                        </option>
                                    ))}
                                </select>
                                {errors.product_id && (
                                    <p className="text-sm text-destructive">
                                        {errors.product_id}
                                    </p>
                                )}
                            </div>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Pricing & status</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-3">
                            <div className="space-y-2">
                                <Label>Quantity</Label>
                                <Input
                                    type="number"
                                    step="0.01"
                                    value={data.quantity}
                                    onChange={(e) =>
                                        setData('quantity', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label>Unit price</Label>
                                <Input
                                    type="number"
                                    step="0.01"
                                    value={data.unit_price}
                                    onChange={(e) =>
                                        setData('unit_price', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label>Delivery fee</Label>
                                <Input
                                    type="number"
                                    step="0.01"
                                    value={data.delivery_fee}
                                    onChange={(e) =>
                                        setData(
                                            'delivery_fee',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label>Service fee</Label>
                                <Input
                                    type="number"
                                    step="0.01"
                                    value={data.service_fee}
                                    onChange={(e) =>
                                        setData('service_fee', e.target.value)
                                    }
                                />
                            </div>
                            <div className="space-y-2">
                                <Label>Status</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.status}
                                    onChange={(e) =>
                                        setData('status', e.target.value)
                                    }
                                >
                                    {statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s.replace(/_/g, ' ')}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label>Payment status</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.payment_status}
                                    onChange={(e) =>
                                        setData(
                                            'payment_status',
                                            e.target.value,
                                        )
                                    }
                                >
                                    {payment_statuses.map((s) => (
                                        <option key={s} value={s}>
                                            {s}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label>Payment method</Label>
                                <select
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.payment_method}
                                    onChange={(e) =>
                                        setData(
                                            'payment_method',
                                            e.target.value,
                                        )
                                    }
                                >
                                    {payment_methods.map((m) => (
                                        <option key={m} value={m}>
                                            {m.replace(/_/g, ' ')}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            {data.status === 'cancelled' && (
                                <div className="space-y-2 md:col-span-3">
                                    <Label>Cancellation reason</Label>
                                    <Input
                                        value={data.cancellation_reason}
                                        onChange={(e) =>
                                            setData(
                                                'cancellation_reason',
                                                e.target.value,
                                            )
                                        }
                                    />
                                </div>
                            )}
                            <div className="space-y-2 md:col-span-3">
                                <Label>Delivery address</Label>
                                <Input
                                    value={data.delivery_address}
                                    onChange={(e) =>
                                        setData(
                                            'delivery_address',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-3">
                                <Label>Special instructions</Label>
                                <textarea
                                    className="min-h-[80px] w-full rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.special_instructions}
                                    onChange={(e) =>
                                        setData(
                                            'special_instructions',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                        </CardContent>
                    </Card>

                    <div className="flex justify-end gap-3">
                        <Button type="button" variant="outline" asChild>
                            <Link href={path("orders", order.id)}>
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
