import { Head, Link } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    stats: Record<string, number>;
    area?: string;
}


export default function OrderStatistics({stats, area}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: base },
    { title: 'Orders', href: path("orders") },
    { title: 'Statistics', href: path("orders", "statistics") },
];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Order Statistics | SiteDrop Admin">
                <meta name="description" content="Order statistics and metrics." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path("orders")} />
                    <h1 className="text-2xl font-bold">Order statistics</h1>
                </div>
                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                    {Object.entries(stats).map(([key, value]) => (
                        <Card key={key}>
                            <CardHeader className="pb-2">
                                <CardTitle className="text-sm capitalize text-muted-foreground">
                                    {key.replaceAll('_', ' ')}
                                </CardTitle>
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold">
                                    {typeof value === 'number' && key === 'revenue'
                                        ? `GHS ${value.toFixed(2)}`
                                        : value}
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>
            </div>
        </AppLayout>
    );
}
