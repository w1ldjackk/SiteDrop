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
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Option {
    id: number;
    label: string;
    seller_id?: number;
    price_per_unit?: number;
}

interface Props {
    statuses: string[];
    payment_statuses: string[];
    payment_methods: string[];
    buyers: Option[];
    sellers: Option[];
    products: Option[];
    area?: string;
}


export default function OrdersCreate({statuses,
    payment_statuses,
    payment_methods,
    buyers,
    sellers,
    products, area}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: base },
    { title: 'Orders', href: path("orders") },
    { title: 'New order', href: path("orders", "create") },
];

    const { data, setData, post, processing, errors, transform } = useForm({
        buyer_id: buyers[0]?.id?.toString() || '',
        seller_id: '',
        items: [
            {
                product_id: products[0]?.id?.toString() || '',
                quantity: '1',
                price: products[0]?.price_per_unit?.toString() || '',
            },
        ] as { product_id: string; quantity: string; price: string }[],
        delivery_fee: '0',
        service_fee: '',
        discount_amount: '0',
        tax_amount: '0',
        status: 'pending',
        payment_status: 'pending',
        payment_method: payment_methods[0] || 'mobile_money',
        delivery_address: '',
        delivery_phone: '',
        special_instructions: '',
        currency: 'GHS',
    });

    const updateLine = (
        index: number,
        field: 'product_id' | 'quantity' | 'price',
        value: string,
    ) => {
        setData((current) => {
            const items = [...current.items];
            const row = { ...items[index], [field]: value };
            if (field === 'product_id') {
                const p = products.find((x) => String(x.id) === value);
                if (p?.price_per_unit != null) {
                    row.price = String(p.price_per_unit);
                }
                // Keep seller aligned to first product's seller
                const sellerFromProduct =
                    p?.seller_id != null ? String(p.seller_id) : current.seller_id;
                items[index] = row;
                return {
                    ...current,
                    items,
                    seller_id:
                        index === 0 ? sellerFromProduct : current.seller_id,
                };
            }
            items[index] = row;
            return { ...current, items };
        });
    };

    const addLine = () => {
        setData((current) => ({
            ...current,
            items: [
                ...current.items,
                { product_id: '', quantity: '1', price: '' },
            ],
        }));
    };

    const removeLine = (index: number) => {
        setData((current) => ({
            ...current,
            items:
                current.items.length <= 1
                    ? current.items
                    : current.items.filter((_, i) => i !== index),
        }));
    };

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        transform((form) => ({
            ...form,
            items: form.items
                .filter((i) => i.product_id)
                .map((i) => ({
                    product_id: Number(i.product_id),
                    quantity: Number(i.quantity) || 1,
                    price: i.price === '' ? undefined : Number(i.price),
                })),
        }));
        post(path("orders"));
    };

    const subtotal = data.items.reduce((sum, line) => {
        return sum + (Number(line.quantity) || 0) * (Number(line.price) || 0);
    }, 0);
    const delivery = Number(data.delivery_fee) || 0;
    const service =
        data.service_fee === ''
            ? Math.round(subtotal * 0.1 * 100) / 100
            : Number(data.service_fee) || 0;
    const discount = Number(data.discount_amount) || 0;
    const tax = Number(data.tax_amount) || 0;
    const total = Math.max(0, subtotal + delivery + service + tax - discount);

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Create Order | SiteDrop Admin">
                <meta name="description" content="Manually create a new order." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path("orders")} />
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight">
                            New order
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Create an order for a buyer and product
                        </p>
                    </div>
                </div>

                <form onSubmit={handleSubmit} className="space-y-6">
                    <Card>
                        <CardHeader>
                            <CardTitle>Parties</CardTitle>
                            <CardDescription>
                                One order = one buyer + one seller (same as
                                checkout). All line items must share a seller.
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-2">
                            <div className="space-y-2">
                                <Label htmlFor="buyer_id">Buyer *</Label>
                                <select
                                    id="buyer_id"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.buyer_id}
                                    onChange={(e) =>
                                        setData('buyer_id', e.target.value)
                                    }
                                    required
                                >
                                    <option value="">Select buyer</option>
                                    {buyers.map((b) => (
                                        <option key={b.id} value={b.id}>
                                            {b.label}
                                        </option>
                                    ))}
                                </select>
                                {errors.buyer_id && (
                                    <p className="text-sm text-destructive">
                                        {errors.buyer_id}
                                    </p>
                                )}
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="seller_id">
                                    Seller (optional — from products)
                                </Label>
                                <select
                                    id="seller_id"
                                    className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                    value={data.seller_id}
                                    onChange={(e) =>
                                        setData('seller_id', e.target.value)
                                    }
                                >
                                    <option value="">
                                        Auto from first product
                                    </option>
                                    {sellers.map((s) => (
                                        <option key={s.id} value={s.id}>
                                            {s.label}
                                        </option>
                                    ))}
                                </select>
                            </div>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader className="flex flex-row items-center justify-between">
                            <div>
                                <CardTitle>Line items</CardTitle>
                                <CardDescription>
                                    Add multiple products to this order
                                </CardDescription>
                            </div>
                            <Button
                                type="button"
                                variant="outline"
                                size="sm"
                                className="cursor-pointer"
                                onClick={addLine}
                            >
                                + Add line
                            </Button>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            {data.items.map((line, index) => (
                                <div
                                    key={index}
                                    className="grid gap-3 rounded-lg border p-3 md:grid-cols-12"
                                >
                                    <div className="space-y-1 md:col-span-6">
                                        <Label>Product *</Label>
                                        <select
                                            className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                            value={line.product_id}
                                            onChange={(e) =>
                                                updateLine(
                                                    index,
                                                    'product_id',
                                                    e.target.value,
                                                )
                                            }
                                            required
                                        >
                                            <option value="">
                                                Select product
                                            </option>
                                            {products.map((p) => (
                                                <option key={p.id} value={p.id}>
                                                    {p.label}
                                                </option>
                                            ))}
                                        </select>
                                    </div>
                                    <div className="space-y-1 md:col-span-2">
                                        <Label>Qty *</Label>
                                        <Input
                                            type="number"
                                            step="0.01"
                                            min="0.01"
                                            value={line.quantity}
                                            onChange={(e) =>
                                                updateLine(
                                                    index,
                                                    'quantity',
                                                    e.target.value,
                                                )
                                            }
                                            required
                                        />
                                    </div>
                                    <div className="space-y-1 md:col-span-2">
                                        <Label>Unit price</Label>
                                        <Input
                                            type="number"
                                            step="0.01"
                                            min="0"
                                            value={line.price}
                                            onChange={(e) =>
                                                updateLine(
                                                    index,
                                                    'price',
                                                    e.target.value,
                                                )
                                            }
                                        />
                                    </div>
                                    <div className="flex items-end md:col-span-2">
                                        <Button
                                            type="button"
                                            variant="ghost"
                                            className="cursor-pointer text-destructive"
                                            disabled={data.items.length <= 1}
                                            onClick={() => removeLine(index)}
                                        >
                                            Remove
                                        </Button>
                                    </div>
                                </div>
                            ))}
                            {errors.items && (
                                <p className="text-sm text-destructive">
                                    {errors.items}
                                </p>
                            )}
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Fees & total</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-3">
                            <div className="space-y-2">
                                <Label htmlFor="delivery_fee">
                                    Delivery fee
                                </Label>
                                <Input
                                    id="delivery_fee"
                                    type="number"
                                    step="0.01"
                                    min="0"
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
                                <Label htmlFor="service_fee">
                                    Service fee (blank = 10%)
                                </Label>
                                <Input
                                    id="service_fee"
                                    type="number"
                                    step="0.01"
                                    min="0"
                                    value={data.service_fee}
                                    onChange={(e) =>
                                        setData('service_fee', e.target.value)
                                    }
                                    placeholder="Auto 10%"
                                />
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="discount_amount">
                                    Discount
                                </Label>
                                <Input
                                    id="discount_amount"
                                    type="number"
                                    step="0.01"
                                    min="0"
                                    value={data.discount_amount}
                                    onChange={(e) =>
                                        setData(
                                            'discount_amount',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-3">
                                <Label>Estimated total</Label>
                                <div className="rounded-md border bg-muted px-3 py-2 text-sm font-semibold">
                                    GHS {total.toFixed(2)}
                                    <span className="ml-2 font-normal text-muted-foreground">
                                        (lines subtotal {subtotal.toFixed(2)} ·{' '}
                                        {data.items.length} item
                                        {data.items.length === 1 ? '' : 's'})
                                    </span>
                                </div>
                            </div>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Status & delivery</CardTitle>
                        </CardHeader>
                        <CardContent className="grid gap-4 md:grid-cols-2">
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
                                            {s.replace(/_/g, ' ')}
                                        </option>
                                    ))}
                                </select>
                            </div>
                            <div className="space-y-2">
                                <Label htmlFor="payment_status">
                                    Payment status
                                </Label>
                                <select
                                    id="payment_status"
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
                                <Label htmlFor="payment_method">
                                    Payment method
                                </Label>
                                <select
                                    id="payment_method"
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
                            <div className="space-y-2">
                                <Label htmlFor="delivery_phone">
                                    Delivery phone
                                </Label>
                                <Input
                                    id="delivery_phone"
                                    value={data.delivery_phone}
                                    onChange={(e) =>
                                        setData(
                                            'delivery_phone',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-2">
                                <Label htmlFor="delivery_address">
                                    Delivery address
                                </Label>
                                <Input
                                    id="delivery_address"
                                    value={data.delivery_address}
                                    onChange={(e) =>
                                        setData(
                                            'delivery_address',
                                            e.target.value,
                                        )
                                    }
                                />
                            </div>
                            <div className="space-y-2 md:col-span-2">
                                <Label htmlFor="special_instructions">
                                    Special instructions
                                </Label>
                                <textarea
                                    id="special_instructions"
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
                            <Link href={path("orders")}>Cancel</Link>
                        </Button>
                        <Button
                            type="submit"
                            disabled={processing}
                            className="cursor-pointer"
                        >
                            {processing ? 'Creating…' : 'Create order'}
                        </Button>
                    </div>
                </form>
            </div>
        </AppLayout>
    );
}
