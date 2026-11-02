import { Head, Link, router, useForm } from '@inertiajs/react';
import { Pencil, Trash2 } from 'lucide-react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    order: Record<string, any>;
    statuses?: string[];
    payment_statuses?: string[];
    payment_methods?: string[];
    can?: { update?: boolean; delete?: boolean; cancel?: boolean };
    area?: string;
}

function Row({
    label,
    children,
}: {
    label: string;
    children: React.ReactNode;
}) {
    return (
        <div className="flex flex-col gap-0.5 sm:flex-row sm:gap-3">
            <span className="w-40 shrink-0 text-muted-foreground">{label}</span>
            <span className="flex-1 break-words">{children ?? '—'}</span>
        </div>
    );
}

export default function OrderShow({
    order,
    statuses = [],
    payment_statuses = [],
    can,
    area,
}: Props) {
    const { path, base, isAdminArea } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Orders', href: path('orders') },
        {
            title: order.order_number ?? `#${order.id}`,
            href: path('orders', order.id),
        },
    ];

    const canUpdate = can?.update ?? true;
    const canDelete = can?.delete ?? true;

    const { data, setData, put, processing } = useForm({
        status: order.status || 'pending',
        payment_status: order.payment_status || 'pending',
        cancellation_reason: order.cancellation_reason || '',
        status_only: true as boolean,
    });

    const saveStatus = (e: React.FormEvent) => {
        e.preventDefault();
        put(path("orders", order.id), { preserveScroll: true });
    };

    const deleteOrder = () => {
        if (
            !confirm(
                `Delete order ${order.order_number}? This soft-deletes the order.`,
            )
        ) {
            return;
        }
        router.delete(path("orders", order.id));
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Order ${order.order_number} | Orders`}>
                <meta name="description" content={`View details for order ${order.order_number}.`} />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="flex items-center gap-3">
                        <IosBackButton href={path("orders")} />
                        <div>
                            <code className="rounded bg-muted px-2 py-0.5 font-mono text-sm font-semibold">
                                {order.order_number}
                            </code>
                            <h1 className="mt-1 text-2xl font-bold">
                                Order details
                            </h1>
                            <div className="mt-1 flex flex-wrap gap-2">
                                <Badge>
                                    {String(order.status || '').replace(
                                        /_/g,
                                        ' ',
                                    )}
                                </Badge>
                                <Badge variant="outline">
                                    {order.payment_status}
                                </Badge>
                            </div>
                        </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        {canUpdate && (
                            <Button
                                size="sm"
                                variant="outline"
                                className="cursor-pointer"
                                asChild
                            >
                                <Link href={path("orders", order.id, "edit")}>
                                    <Pencil className="mr-2 h-4 w-4" />
                                    Edit
                                </Link>
                            </Button>
                        )}
                        {canDelete && (
                            <Button
                                size="sm"
                                variant="ghost"
                                type="button"
                                className="cursor-pointer text-destructive hover:text-destructive"
                                onClick={deleteOrder}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete
                            </Button>
                        )}
                    </div>
                </div>

                {canUpdate && statuses.length > 0 && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Quick status update</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form
                                onSubmit={saveStatus}
                                className="flex flex-col gap-3 sm:flex-row sm:items-end"
                            >
                                <div className="space-y-2">
                                    <Label>Status</Label>
                                    <select
                                        className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm sm:w-48"
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
                                    <Label>Payment</Label>
                                    <select
                                        className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm sm:w-40"
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
                                <Button
                                    type="submit"
                                    size="sm"
                                    disabled={processing}
                                    className="cursor-pointer"
                                >
                                    {processing ? 'Saving…' : 'Update status'}
                                </Button>
                            </form>
                        </CardContent>
                    </Card>
                )}

                {/* Line items — multi-product source of truth */}
                <Card>
                    <CardHeader>
                        <CardTitle>
                            Line items ({order.items_count ?? order.items?.length ?? 0})
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {Array.isArray(order.items) && order.items.length > 0 ? (
                            <div className="overflow-x-auto rounded-md border">
                                <table className="w-full text-sm">
                                    <thead>
                                        <tr className="border-b bg-muted/40 text-left">
                                            <th className="px-3 py-2 font-medium">
                                                Product
                                            </th>
                                            <th className="px-3 py-2 font-medium">
                                                Qty
                                            </th>
                                            <th className="px-3 py-2 font-medium">
                                                Unit price
                                            </th>
                                            <th className="px-3 py-2 text-right font-medium">
                                                Subtotal
                                            </th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {order.items.map(
                                            (item: any, idx: number) => (
                                                <tr
                                                    key={item.id ?? idx}
                                                    className="border-b last:border-0"
                                                >
                                                    <td className="px-3 py-2">
                                                        {item.product?.name ??
                                                            `Product #${item.product_id}`}
                                                        {item.unit && (
                                                            <span className="ml-1 text-xs text-muted-foreground">
                                                                / {item.unit}
                                                            </span>
                                                        )}
                                                    </td>
                                                    <td className="px-3 py-2">
                                                        {item.quantity}
                                                    </td>
                                                    <td className="px-3 py-2">
                                                        {order.currency ??
                                                            'GHS'}{' '}
                                                        {Number(
                                                            item.price ?? 0,
                                                        ).toFixed(2)}
                                                    </td>
                                                    <td className="px-3 py-2 text-right font-medium">
                                                        {order.currency ??
                                                            'GHS'}{' '}
                                                        {Number(
                                                            item.subtotal ??
                                                                item.quantity *
                                                                    item.price,
                                                        ).toFixed(2)}
                                                    </td>
                                                </tr>
                                            ),
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        ) : (
                            <p className="text-sm text-muted-foreground">
                                No line items — only legacy product field:{' '}
                                {order.product?.name ?? '—'} × {order.quantity}
                            </p>
                        )}
                    </CardContent>
                </Card>

                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Details</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <Row label="Buyer">
                                {order.buyer?.name ?? '—'}
                                {isAdminArea && order.buyer_id && (
                                    <Link
                                        href={path('users', order.buyer_id)}
                                        className="ml-2 text-primary underline"
                                    >
                                        #{order.buyer_id}
                                    </Link>
                                )}
                            </Row>
                            <Row label="Seller">
                                {order.seller?.name ?? '—'}
                                {isAdminArea && order.seller_id && (
                                    <Link
                                        href={path('users', order.seller_id)}
                                        className="ml-2 text-primary underline"
                                    >
                                        #{order.seller_id}
                                    </Link>
                                )}
                            </Row>
                            <Row label="Subtotal">
                                {order.currency ?? 'GHS'}{' '}
                                {Number(order.subtotal ?? 0).toFixed(2)}
                            </Row>
                            <Row label="Delivery fee">
                                {order.currency ?? 'GHS'}{' '}
                                {Number(order.delivery_fee ?? 0).toFixed(2)}
                            </Row>
                            <Row label="Service fee">
                                {order.currency ?? 'GHS'}{' '}
                                {Number(order.service_fee ?? 0).toFixed(2)}
                            </Row>
                            <Row label="Total">
                                <strong>
                                    {order.currency ?? 'GHS'}{' '}
                                    {Number(order.total_amount ?? 0).toFixed(2)}
                                </strong>
                            </Row>
                            <Row label="Seller earnings">
                                {order.currency ?? 'GHS'}{' '}
                                {Number(order.seller_earnings ?? 0).toFixed(2)}
                            </Row>
                            <Row label="Commission">
                                {order.currency ?? 'GHS'}{' '}
                                {Number(order.commission_amount ?? 0).toFixed(
                                    2,
                                )}
                            </Row>
                            <Row label="Created">
                                {order.created_at ?? '—'}
                            </Row>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Delivery & payment</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <Row label="Address">
                                {order.delivery_address ?? '—'}
                            </Row>
                            <Row label="Phone">
                                {order.delivery_phone ?? '—'}
                            </Row>
                            <Row label="Instructions">
                                {order.special_instructions ?? '—'}
                            </Row>
                            <Row label="Driver">
                                {order.delivery?.driver?.name ?? '—'}
                            </Row>
                            {isAdminArea && order.delivery?.id && (
                                <div className="flex flex-wrap items-center gap-2 pt-1">
                                    <Button size="sm" variant="outline" asChild>
                                        <Link
                                            href={path(
                                                'deliveries',
                                                order.delivery.id,
                                            )}
                                        >
                                            Manage delivery
                                        </Link>
                                    </Button>
                                    {!order.delivery?.driver &&
                                        ['confirmed', 'processing', 'ready_for_delivery'].includes(
                                            String(order.status ?? ''),
                                        ) && (
                                            <Button
                                                size="sm"
                                                type="button"
                                                className="cursor-pointer"
                                                onClick={() =>
                                                    router.post(
                                                        path(
                                                            'deliveries',
                                                            order.delivery.id,
                                                            'dispatch',
                                                        ),
                                                        {
                                                            online_only: true,
                                                            max_drivers: 5,
                                                        },
                                                        { preserveScroll: true },
                                                    )
                                                }
                                            >
                                                Push to online drivers
                                            </Button>
                                        )}
                                </div>
                            )}
                            <Row label="Payment method">
                                {order.payment_method?.replace(/_/g, ' ') ??
                                    '—'}
                            </Row>
                            <Row label="Payment status">
                                {order.payment_status ?? '—'}
                            </Row>
                            {order.cancellation_reason && (
                                <p className="text-destructive">
                                    Cancelled: {order.cancellation_reason}
                                </p>
                            )}
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>
                            Timeline (
                            {Array.isArray(order.timeline)
                                ? order.timeline.length
                                : 0}
                            )
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {Array.isArray(order.timeline) &&
                        order.timeline.length > 0 ? (
                            <ul className="space-y-2 text-sm">
                                {order.timeline.map((t: any) => (
                                    <li
                                        key={t.id}
                                        className="flex flex-col gap-0.5 border-b py-2 last:border-0 sm:flex-row sm:justify-between sm:gap-4"
                                    >
                                        <div>
                                            <Badge
                                                variant="outline"
                                                className="mb-1"
                                            >
                                                {String(
                                                    t.status || '—',
                                                ).replace(/_/g, ' ')}
                                            </Badge>
                                            <p>
                                                {t.description ||
                                                    t.note ||
                                                    '—'}
                                            </p>
                                        </div>
                                        <span className="shrink-0 text-muted-foreground">
                                            {t.created_at}
                                        </span>
                                    </li>
                                ))}
                            </ul>
                        ) : (
                            <p className="text-sm text-muted-foreground">
                                No timeline entries yet. Status changes will
                                appear here.
                            </p>
                        )}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
