import { Head, Link, router } from '@inertiajs/react';
import { ExternalLink, FileText, Pencil, Trash2 } from 'lucide-react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface Doc {
    name: string;
    url?: string | null;
    type?: string | null;
    size?: number | string | null;
}

interface Props {
    seller: Record<string, any>;
    stats: Record<string, number>;
    can?: { update?: boolean; delete?: boolean; moderate?: boolean };
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

export default function SellerShow({ seller, stats, can }: Props) {
    const canUpdate = can?.update ?? true;
    const canDelete = can?.delete ?? true;
    const canModerate = can?.moderate ?? true;
    const docs: Doc[] = Array.isArray(seller.verification_documents)
        ? seller.verification_documents
        : [];
    const sellerCode =
        seller.seller_code ||
        `SLR-${String(seller.id).padStart(6, '0')}`;

    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Sellers', href: '/admin/sellers' },
        {
            title: seller.business_name,
            href: `/admin/sellers/${seller.id}`,
        },
    ];

    const action = (path: string) => {
        router.post(path, {}, { preserveScroll: true });
    };

    const rejectWithReason = () => {
        const reason =
            window.prompt('Rejection reason (optional):', '') ?? '';
        router.post(
            `/admin/sellers/${seller.id}/reject`,
            { reason: reason || 'Rejected by admin' },
            { preserveScroll: true },
        );
    };

    const deleteSeller = () => {
        if (
            !confirm(
                `Delete seller "${seller.business_name}" (${sellerCode})? This soft-deletes the profile.`,
            )
        ) {
            return;
        }
        router.delete(`/admin/sellers/${seller.id}`);
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${sellerCode} · ${seller.business_name} | Seller`}>
                <meta name="description" content={`View details for seller ${seller.business_name}.`} />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="flex items-center gap-3">
                        <IosBackButton href="/admin/sellers" />
                        <div>
                            <div className="mb-1 flex flex-wrap items-center gap-2">
                                <code className="rounded bg-muted px-2 py-0.5 font-mono text-sm font-semibold">
                                    {sellerCode}
                                </code>
                                <Badge>{seller.status}</Badge>
                                {seller.email_verified && (
                                    <Badge variant="outline">
                                        email verified
                                    </Badge>
                                )}
                            </div>
                            <h1 className="text-2xl font-bold">
                                {seller.business_name}
                            </h1>
                            <p className="text-sm text-muted-foreground">
                                {seller.business_type?.replace(/_/g, ' ') ||
                                    '—'}{' '}
                                · user #{seller.user_id}
                            </p>
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
                                <Link
                                    href={`/admin/sellers/${seller.id}/edit`}
                                >
                                    <Pencil className="mr-2 h-4 w-4" />
                                    Edit
                                </Link>
                            </Button>
                        )}
                        {canModerate && (
                            <>
                                <Button
                                    size="sm"
                                    className="cursor-pointer"
                                    onClick={() =>
                                        action(
                                            `/admin/sellers/${seller.id}/approve`,
                                        )
                                    }
                                >
                                    Approve
                                </Button>
                                <Button
                                    size="sm"
                                    variant="secondary"
                                    className="cursor-pointer"
                                    onClick={() =>
                                        action(
                                            `/admin/sellers/${seller.id}/activate`,
                                        )
                                    }
                                >
                                    Activate
                                </Button>
                                <Button
                                    size="sm"
                                    variant="outline"
                                    className="cursor-pointer"
                                    onClick={() =>
                                        action(
                                            `/admin/sellers/${seller.id}/suspend`,
                                        )
                                    }
                                >
                                    Suspend
                                </Button>
                                <Button
                                    size="sm"
                                    variant="destructive"
                                    className="cursor-pointer"
                                    onClick={rejectWithReason}
                                >
                                    Reject
                                </Button>
                            </>
                        )}
                        {canDelete && (
                            <Button
                                size="sm"
                                variant="ghost"
                                type="button"
                                className="cursor-pointer text-destructive hover:text-destructive"
                                onClick={deleteSeller}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete
                            </Button>
                        )}
                    </div>
                </div>

                {/* Pending banner — remind to review docs before approval */}
                {seller.status === 'pending' && (
                    <div className="rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900 dark:border-amber-800 dark:bg-amber-950 dark:text-amber-100">
                        This seller is <strong>pending approval</strong>. Review
                        verification documents below before approving.
                        {docs.length === 0 && (
                            <span className="mt-1 block opacity-90">
                                No verification documents uploaded yet.
                            </span>
                        )}
                    </div>
                )}

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        { label: 'Orders', value: stats.orders_total },
                        { label: 'Pending', value: stats.orders_pending },
                        { label: 'Completed', value: stats.orders_completed },
                        {
                            label: 'Earnings',
                            value: `GHS ${Number(stats.revenue ?? 0).toFixed(2)}`,
                        },
                    ].map((s) => (
                        <Card key={s.label}>
                            <CardHeader className="pb-2">
                                <CardTitle className="text-sm text-muted-foreground">
                                    {s.label}
                                </CardTitle>
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold">
                                    {s.value}
                                </div>
                            </CardContent>
                        </Card>
                    ))}
                </div>

                {(seller.logo_url || seller.cover_image_url) && (
                    <div className="grid gap-4 md:grid-cols-2">
                        {seller.logo_url && (
                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm">
                                        Logo
                                    </CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <img
                                        src={seller.logo_url}
                                        alt="Logo"
                                        className="max-h-32 rounded border object-contain"
                                    />
                                </CardContent>
                            </Card>
                        )}
                        {seller.cover_image_url && (
                            <Card>
                                <CardHeader>
                                    <CardTitle className="text-sm">
                                        Cover
                                    </CardTitle>
                                </CardHeader>
                                <CardContent>
                                    <img
                                        src={seller.cover_image_url}
                                        alt="Cover"
                                        className="max-h-40 w-full rounded border object-cover"
                                    />
                                </CardContent>
                            </Card>
                        )}
                    </div>
                )}

                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Owner (User)</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <Row label="Name">{seller.user?.name ?? '—'}</Row>
                            <Row label="Email">{seller.user?.email ?? '—'}</Row>
                            <Row label="Phone">{seller.user?.phone ?? '—'}</Row>
                            <Row label="Role">{seller.user?.role ?? '—'}</Row>
                            <Row label="Phone verified">
                                {seller.user?.phone_verified ? 'Yes' : 'No'}
                            </Row>
                            {seller.user?.id && (
                                <Button
                                    variant="link"
                                    className="h-auto cursor-pointer px-0"
                                    asChild
                                >
                                    <Link
                                        href={`/admin/users/${seller.user.id}`}
                                    >
                                        Open user #{seller.user.id}
                                    </Link>
                                </Button>
                            )}
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Business</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <Row label="Seller ID">{sellerCode}</Row>
                            <Row label="Type">
                                {seller.business_type?.replace(/_/g, ' ') ||
                                    '—'}
                            </Row>
                            <Row label="Reg. no.">
                                {seller.business_registration_number || '—'}
                            </Row>
                            <Row label="Tax ID">{seller.tax_id || '—'}</Row>
                            <Row label="Business email">
                                {seller.business_email || '—'}
                            </Row>
                            <Row label="Business phone">
                                {seller.business_phone || '—'}
                            </Row>
                            <Row label="Website">
                                {seller.website ? (
                                    <a
                                        href={seller.website}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="inline-flex items-center gap-1 text-primary underline"
                                    >
                                        {seller.website}
                                        <ExternalLink className="h-3 w-3" />
                                    </a>
                                ) : (
                                    '—'
                                )}
                            </Row>
                            <Row label="Commission">
                                {seller.commission_rate ?? '—'}%
                            </Row>
                            <Row label="Min. order">
                                {seller.minimum_order_amount != null
                                    ? `GHS ${seller.minimum_order_amount}`
                                    : '—'}
                            </Row>
                            <Row label="Delivery radius">
                                {seller.delivery_radius_km != null
                                    ? `${seller.delivery_radius_km} km`
                                    : '—'}
                            </Row>
                            <Row label="Products / Reviews">
                                {seller.products_count ?? 0} /{' '}
                                {seller.reviews_count ?? 0}
                            </Row>
                            <Row label="Approved at">
                                {seller.approved_at || '—'}
                            </Row>
                            <Row label="Created">
                                {seller.created_at || '—'}
                            </Row>
                            {seller.rejected_reason && (
                                <p className="text-destructive">
                                    Rejected: {seller.rejected_reason}
                                </p>
                            )}
                            <p className="pt-2 text-muted-foreground">
                                {seller.description || 'No description'}
                            </p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Banking</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-2 text-sm">
                            <Row label="Account name">
                                {seller.bank_account_name || '—'}
                            </Row>
                            <Row label="Account number">
                                {seller.bank_account_number || '—'}
                            </Row>
                            <Row label="Bank">{seller.bank_name || '—'}</Row>
                            <Row label="Branch">
                                {seller.bank_branch || '—'}
                            </Row>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Service areas</CardTitle>
                        </CardHeader>
                        <CardContent className="text-sm">
                            {Array.isArray(seller.service_areas) &&
                            seller.service_areas.length > 0 ? (
                                <div className="flex flex-wrap gap-2">
                                    {seller.service_areas.map(
                                        (a: string, i: number) => (
                                            <Badge
                                                key={i}
                                                variant="secondary"
                                            >
                                                {typeof a === 'string'
                                                    ? a
                                                    : JSON.stringify(a)}
                                            </Badge>
                                        ),
                                    )}
                                </div>
                            ) : (
                                <p className="text-muted-foreground">
                                    None listed
                                </p>
                            )}
                        </CardContent>
                    </Card>
                </div>

                {/* Verification documents — visible for super-admin/admin even before approval */}
                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <FileText className="h-5 w-5" />
                            Verification documents ({docs.length})
                        </CardTitle>
                    </CardHeader>
                    <CardContent>
                        {docs.length === 0 ? (
                            <p className="text-sm text-muted-foreground">
                                No documents uploaded. You can still approve or
                                request documents from the seller.
                            </p>
                        ) : (
                            <ul className="divide-y rounded-md border">
                                {docs.map((doc, i) => (
                                    <li
                                        key={i}
                                        className="flex flex-wrap items-center justify-between gap-3 px-4 py-3 text-sm"
                                    >
                                        <div>
                                            <div className="font-medium">
                                                {doc.name}
                                            </div>
                                            <div className="text-xs text-muted-foreground">
                                                {[doc.type, doc.size]
                                                    .filter(Boolean)
                                                    .join(' · ') || '—'}
                                            </div>
                                        </div>
                                        {doc.url ? (
                                            <Button
                                                size="sm"
                                                variant="outline"
                                                className="cursor-pointer"
                                                asChild
                                            >
                                                <a
                                                    href={doc.url}
                                                    target="_blank"
                                                    rel="noreferrer"
                                                >
                                                    View
                                                    <ExternalLink className="ml-2 h-3.5 w-3.5" />
                                                </a>
                                            </Button>
                                        ) : (
                                            <span className="text-xs text-muted-foreground">
                                                No URL
                                            </span>
                                        )}
                                    </li>
                                ))}
                            </ul>
                        )}
                    </CardContent>
                </Card>

                {(Array.isArray(seller.social_links) &&
                    seller.social_links.length > 0) ||
                (seller.business_hours &&
                    (Array.isArray(seller.business_hours)
                        ? seller.business_hours.length > 0
                        : Object.keys(seller.business_hours || {}).length >
                          0)) ? (
                    <div className="grid gap-4 md:grid-cols-2">
                        <Card>
                            <CardHeader>
                                <CardTitle>Social links</CardTitle>
                            </CardHeader>
                            <CardContent className="text-sm">
                                <pre className="overflow-x-auto rounded bg-muted p-3 text-xs">
                                    {JSON.stringify(
                                        seller.social_links,
                                        null,
                                        2,
                                    )}
                                </pre>
                            </CardContent>
                        </Card>
                        <Card>
                            <CardHeader>
                                <CardTitle>Business hours</CardTitle>
                            </CardHeader>
                            <CardContent className="text-sm">
                                <pre className="overflow-x-auto rounded bg-muted p-3 text-xs">
                                    {JSON.stringify(
                                        seller.business_hours,
                                        null,
                                        2,
                                    )}
                                </pre>
                            </CardContent>
                        </Card>
                    </div>
                ) : null}
            </div>
        </AppLayout>
    );
}
