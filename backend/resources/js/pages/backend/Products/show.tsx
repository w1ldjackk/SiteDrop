import { Head, Link } from '@inertiajs/react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface Props {
    product: Record<string, any>;
    area?: string;
}

export default function ProductShow({product, area}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Products', href: path("products") },
        { title: product.name, href: path("products", product.id) },
    ];

    
    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${product.name} | Product`}>
                <meta name="description" content={`Product details for ${product.name}.`} />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex items-center gap-3">
                    <IosBackButton href={path("products")} />
                    <div>
                        <h1 className="text-2xl font-bold">{product.name}</h1>
                        <div className="mt-1 flex gap-2">
                            <Badge>
                                {product.is_available ? 'Available' : 'Unavailable'}
                            </Badge>
                            {product.is_featured && (
                                <Badge variant="secondary">Featured</Badge>
                            )}
                        </div>
                    </div>
                </div>
                <Card>
                    <CardHeader>
                        <CardTitle>Details</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <p>
                            <span className="text-muted-foreground">Seller: </span>
                            {product.seller?.name ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Category: </span>
                            {product.category ?? '—'}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Price: </span>
                            GHS {Number(product.price_per_unit ?? 0).toFixed(2)} /{' '}
                            {product.unit}
                        </p>
                        <p>
                            <span className="text-muted-foreground">Stock: </span>
                            {product.stock_quantity ?? '—'}
                        </p>
                        <p className="pt-2 text-muted-foreground">
                            {product.description || 'No description'}
                        </p>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
