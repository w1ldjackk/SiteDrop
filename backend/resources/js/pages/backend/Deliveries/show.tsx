import { Head, Link, useForm } from '@inertiajs/react';
import { useState } from 'react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Label } from '@/components/ui/label';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface DriverOption {
    id: number;
    name: string;
    phone?: string | null;
    is_online: boolean;
    last_active_at?: string | null;
}

interface OfferRow {
    id: number;
    driver_id: number;
    driver_name?: string | null;
    is_online?: boolean;
    status: string;
    expires_at?: string | null;
    responded_at?: string | null;
}

interface Props {
    delivery: Record<string, any>;
    area?: string;
    canAssign?: boolean;
    offers?: OfferRow[];
    availableDrivers?: DriverOption[];
}

export default function DeliveryShow({
    delivery,
    area,
    canAssign = false,
    offers = [],
    availableDrivers = [],
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Deliveries', href: path('deliveries') },
        {
            title: delivery.tracking_number ?? `#${delivery.id}`,
            href: path('deliveries', delivery.id),
        },
    ];

    const [selectedDriver, setSelectedDriver] = useState<string>('');
    const assignForm = useForm({ driver_id: '', notes: '' });
    const dispatchForm = useForm({ online_only: true as boolean, max_drivers: 5 as number });

    const submitAssign = (e: React.FormEvent) => {
        e.preventDefault();
        assignForm.post(path('deliveries', delivery.id, 'assign'), {
            preserveScroll: true,
            onSuccess: () => setSelectedDriver(''),
        });
    };

    const submitDispatch = (e: React.FormEvent) => {
        e.preventDefault();
        dispatchForm.post(path('deliveries', delivery.id, 'dispatch'), {
            preserveScroll: true,
        });
    };

    const hasDriver = Boolean(delivery.driver?.name ?? delivery.driver_id);
    const isPending = delivery.status === 'pending';

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Delivery ${delivery.tracking_number ?? delivery.id} | Deliveries`}>
                <meta name="description" content="Delivery tracking and status details." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path('deliveries')} />
                    <div>
                        <h1 className="text-2xl font-bold">
                            {delivery.tracking_number ?? `Delivery #${delivery.id}`}
                        </h1>
                        <Badge className="mt-1">{delivery.status}</Badge>
                    </div>
                </div>
                <Card>
                    <CardHeader>
                        <CardTitle>Details</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <p>
                            <span className="text-muted-foreground">Order: </span>
                            {delivery.order?.order_number ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Driver: </span>
                            {delivery.driver?.name ?? 'Unassigned'}
                            {delivery.driver?.phone ? ` (${delivery.driver.phone})` : ''}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Fee: </span>
                            GHS {Number(delivery.delivery_fee ?? 0).toFixed(2)}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Distance: </span>
                            {delivery.distance_km ?? '—'} km
                        </p>
                    </CardContent>
                </Card>

                {canAssign && (
                    <div className="grid gap-4 md:grid-cols-2">
                        <Card>
                            <CardHeader>
                                <CardTitle>Assign driver (manual)</CardTitle>
                            </CardHeader>
                            <CardContent>
                                {!isPending || hasDriver ? (
                                    <p className="text-sm text-muted-foreground">
                                        This delivery already has a driver or is no longer
                                        pending — manual assignment is disabled.
                                    </p>
                                ) : (
                                    <form onSubmit={submitAssign} className="space-y-3">
                                        <div className="space-y-2">
                                            <Label>Driver (online first)</Label>
                                            <select
                                                className="w-full cursor-pointer rounded-md border bg-background px-3 py-2 text-sm"
                                                value={selectedDriver}
                                                onChange={(e) => {
                                                    setSelectedDriver(e.target.value);
                                                    assignForm.setData(
                                                        'driver_id',
                                                        e.target.value,
                                                    );
                                                }}
                                            >
                                                <option value="">Select a driver…</option>
                                                {availableDrivers.map((d) => (
                                                    <option key={d.id} value={d.id}>
                                                        {d.is_online ? '🟢' : '⚪'}{' '}
                                                        {d.name}
                                                        {d.phone ? ` · ${d.phone}` : ''}{' '}
                                                        {d.is_online ? '(online)' : '(offline)'}
                                                    </option>
                                                ))}
                                            </select>
                                            {assignForm.errors.driver_id && (
                                                <p className="text-sm text-destructive">
                                                    {assignForm.errors.driver_id}
                                                </p>
                                            )}
                                        </div>
                                        <div className="space-y-2">
                                            <Label>Dispatch notes (optional)</Label>
                                            <input
                                                className="w-full rounded-md border bg-background px-3 py-2 text-sm"
                                                placeholder="e.g. Fragile — call buyer on arrival"
                                                value={assignForm.data.notes}
                                                onChange={(e) =>
                                                    assignForm.setData('notes', e.target.value)
                                                }
                                            />
                                        </div>
                                        <Button
                                            type="submit"
                                            size="sm"
                                            disabled={assignForm.processing || !selectedDriver}
                                            className="cursor-pointer"
                                        >
                                            {assignForm.processing
                                                ? 'Assigning…'
                                                : 'Assign driver'}
                                        </Button>
                                    </form>
                                )}
                            </CardContent>
                        </Card>

                        <Card>
                            <CardHeader>
                                <CardTitle>Broadcast to online drivers</CardTitle>
                            </CardHeader>
                            <CardContent>
                                {hasDriver ? (
                                    <p className="text-sm text-muted-foreground">
                                        A driver already accepted this trip — no need to
                                        broadcast.
                                    </p>
                                ) : (
                                    <form onSubmit={submitDispatch} className="space-y-3">
                                        <p className="text-sm text-muted-foreground">
                                            Pushes a trip request to available drivers.
                                            First to accept wins; others expire
                                            automatically.
                                        </p>
                                        <label className="flex cursor-pointer items-center gap-2 text-sm">
                                            <input
                                                type="checkbox"
                                                checked={Boolean(dispatchForm.data.online_only)}
                                                onChange={(e) =>
                                                    dispatchForm.setData(
                                                        'online_only',
                                                        e.target.checked,
                                                    )
                                                }
                                            />
                                            Online drivers only (recommended for
                                            confirmed orders)
                                        </label>
                                        {'dispatch' in (dispatchForm.errors as object) && (
                                            <p className="text-sm text-destructive">
                                                {
                                                    (dispatchForm.errors as Record<string, string>)
                                                        .dispatch
                                                }
                                            </p>
                                        )}
                                        <Button
                                            type="submit"
                                            size="sm"
                                            variant="outline"
                                            disabled={dispatchForm.processing}
                                            className="cursor-pointer"
                                        >
                                            {dispatchForm.processing
                                                ? 'Sending…'
                                                : 'Send trip requests'}
                                        </Button>
                                    </form>
                                )}
                            </CardContent>
                        </Card>
                    </div>
                )}

                {canAssign && offers.length > 0 && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Trip requests ({offers.length})</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <div className="overflow-x-auto rounded-md border">
                                <table className="w-full text-sm">
                                    <thead>
                                        <tr className="border-b bg-muted/40 text-left">
                                            <th className="px-3 py-2 font-medium">Driver</th>
                                            <th className="px-3 py-2 font-medium">Status</th>
                                            <th className="px-3 py-2 font-medium">Expires</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {offers.map((o) => (
                                            <tr key={o.id} className="border-b last:border-0">
                                                <td className="px-3 py-2">
                                                    {o.is_online ? '🟢 ' : '⚪ '}
                                                    {o.driver_name ?? `#${o.driver_id}`}
                                                </td>
                                                <td className="px-3 py-2">
                                                    <Badge variant="outline">{o.status}</Badge>
                                                </td>
                                                <td className="px-3 py-2 text-muted-foreground">
                                                    {o.expires_at ?? '—'}
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </CardContent>
                    </Card>
                )}

                <Button variant="outline" size="sm" asChild>
                    <Link href={path('deliveries')}>Back to deliveries</Link>
                </Button>
            </div>
        </AppLayout>
    );
}
