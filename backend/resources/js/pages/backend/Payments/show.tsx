import { Head, Link } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    payment: Record<string, any>;
    area?: string;
}

export default function PaymentShow({payment, area}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Payments', href: path("payments") },
        {
            title: payment.payment_reference ?? `#${payment.id}`,
            href: path("payments", payment.id),
        },
    ];

    
    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${payment.payment_reference ?? `Payment #${payment.id}`} | Payments`}>
                <meta name="description" content="Payment transaction details." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path("payments")} />
                    <div>
                        <h1 className="text-2xl font-bold">
                            {payment.payment_reference ?? `Payment #${payment.id}`}
                        </h1>
                        <Badge className="mt-1">{payment.status}</Badge>
                    </div>
                </div>
                <Card>
                    <CardHeader>
                        <CardTitle>Details</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <p>
                            <span className="text-muted-foreground">User: </span>
                            {payment.user?.name ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Order: </span>
                            {payment.order?.order_number ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Amount: </span>
                            {payment.currency ?? 'GHS'}{' '}
                            {Number(payment.amount ?? 0).toFixed(2)}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Method: </span>
                            {payment.payment_method ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Txn ID: </span>
                            {payment.transaction_id ?? '—'}
                        </p>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
