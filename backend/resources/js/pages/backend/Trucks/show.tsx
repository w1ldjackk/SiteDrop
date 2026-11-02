import { Head, router } from '@inertiajs/react';
import { useState } from 'react';
import { IosBackButton } from '@/components/ios-back-button';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface TruckDoc {
    id: number;
    title?: string | null;
    document_type?: string | null;
    status?: string | null;
    expiry_date?: string | null;
    file_path?: string | null;
}

interface TruckInsurance {
    insurance_company?: string | null;
    policy_number?: string | null;
    type?: string | null;
    coverage_start_date?: string | null;
    coverage_end_date?: string | null;
    status?: string | null;
}

interface TruckMaintenanceRow {
    id: number;
    maintenance_type?: string | null;
    status?: string | null;
    description?: string | null;
}

interface TruckLogRow {
    id: number;
    action?: string | null;
    description?: string | null;
}

interface TruckView {
    id: number;
    registration_number?: string | null;
    status?: string | null;
    is_verified?: boolean;
    rejected_reason?: string | null;
    make?: string | null;
    model?: string | null;
    year?: number | null;
    vehicle_type?: string | null;
    capacity_tons?: string | number | null;
    fuel_type?: string | null;
    current_mileage?: string | number | null;
    insurance_expiry?: string | null;
    verified_at?: string | null;
    user?: { name?: string | null } | null;
    driver?: { name?: string | null } | null;
    documents?: TruckDoc[];
    insurance?: TruckInsurance | null;
    maintenance_records?: TruckMaintenanceRow[];
    maintenanceRecords?: TruckMaintenanceRow[];
    logs?: TruckLogRow[];
}

interface Props {
    truck: TruckView;
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

export default function TruckShow({ truck }: Props) {
    const [rejectOpen, setRejectOpen] = useState(false);
    const [reason, setReason] = useState('');
    const [comment, setComment] = useState('');

    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Trucks & Drivers', href: '/admin/trucks' },
        {
            title: truck.registration_number ?? `#${truck.id}`,
            href: `/admin/trucks/${truck.id}`,
        },
    ];

    const approve = () => {
        router.post(
            `/admin/trucks/${truck.id}/approve`,
            comment.trim() !== '' ? { comment: comment.trim() } : {},
            { preserveScroll: true },
        );
    };

    const reject = () => {
        if (reason.trim() === '') return;
        router.post(
            `/admin/trucks/${truck.id}/reject`,
            { reason: reason.trim() },
            { preserveScroll: true },
        );
    };

    const docs: TruckDoc[] = Array.isArray(truck.documents)
        ? truck.documents
        : [];
    const maintenance: TruckMaintenanceRow[] = Array.isArray(
        truck.maintenance_records ?? truck.maintenanceRecords,
    )
        ? (truck.maintenance_records ?? truck.maintenanceRecords ?? [])
        : [];
    const logs: TruckLogRow[] = Array.isArray(truck.logs) ? truck.logs : [];
    const insurance: TruckInsurance | null = truck.insurance ?? null;

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`${truck.registration_number ?? `Truck #${truck.id}`} | Truck`}>
                <meta name="description" content="Inspect truck details, documents and maintenance, then approve or reject." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
                    <div className="flex items-center gap-3">
                        <IosBackButton href="/admin/trucks" />
                        <div>
                            <h1 className="text-2xl font-bold">
                                {truck.registration_number ?? `Truck #${truck.id}`}
                            </h1>
                            <div className="mt-1 flex flex-wrap items-center gap-2">
                                <Badge>{truck.status}</Badge>
                                <Badge
                                    variant={
                                        truck.is_verified
                                            ? 'default'
                                            : 'secondary'
                                    }
                                >
                                    {truck.is_verified
                                        ? 'Verified'
                                        : 'Unverified'}
                                </Badge>
                            </div>
                        </div>
                    </div>
                    <div className="flex flex-wrap gap-2">
                        <Button
                            size="sm"
                            className="cursor-pointer"
                            onClick={approve}
                        >
                            Approve
                        </Button>
                        <Button
                            size="sm"
                            variant="destructive"
                            className="cursor-pointer"
                            onClick={() => setRejectOpen((v) => !v)}
                        >
                            Reject
                        </Button>
                    </div>
                </div>

                {truck.rejected_reason && (
                    <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-900 dark:border-red-800 dark:bg-red-950 dark:text-red-100">
                        <strong>Rejected:</strong> {truck.rejected_reason}
                    </div>
                )}

                {rejectOpen && (
                    <Card className="border-destructive">
                        <CardHeader>
                            <CardTitle>Reject with comment</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            <textarea
                                className="min-h-24 w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                                placeholder="Why is this truck rejected? (required — sent to the driver)"
                                value={reason}
                                onChange={(e) => setReason(e.target.value)}
                            />
                            <div className="flex gap-2">
                                <Button
                                    size="sm"
                                    variant="destructive"
                                    className="cursor-pointer"
                                    disabled={reason.trim() === ''}
                                    onClick={reject}
                                >
                                    Confirm reject
                                </Button>
                                <Button
                                    size="sm"
                                    variant="outline"
                                    className="cursor-pointer"
                                    onClick={() => setRejectOpen(false)}
                                >
                                    Cancel
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                )}

                <Card>
                    <CardHeader>
                        <CardTitle>Approval note (optional)</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <input
                            className="w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                            placeholder="Note recorded with approval (optional)"
                            value={comment}
                            onChange={(e) => setComment(e.target.value)}
                        />
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Details</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <Row label="Vehicle">
                            {[truck.make, truck.model, truck.year]
                                .filter(Boolean)
                                .join(' ') || '—'}
                        </Row>
                        <Row label="Type">{truck.vehicle_type ?? '—'}</Row>
                        <Row label="Capacity">
                            {truck.capacity_tons ?? '—'} tons
                        </Row>
                        <Row label="Fuel">{truck.fuel_type ?? '—'}</Row>
                        <Row label="Mileage">
                            {truck.current_mileage ?? '—'}
                        </Row>
                        <Row label="Insurance expiry">
                            {truck.insurance_expiry ?? '—'}
                        </Row>
                        <Row label="Owner">{truck.user?.name ?? '—'}</Row>
                        <Row label="Driver">
                            {truck.driver?.name ?? 'Unassigned'}
                        </Row>
                        <Row label="Verified at">
                            {truck.verified_at ?? '—'}
                        </Row>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>
                            Documents ({docs.length})
                        </CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        {docs.length === 0 && (
                            <p className="text-muted-foreground">
                                No documents uploaded.
                            </p>
                        )}
                        {docs.map((d: TruckDoc) => (
                            <div
                                key={d.id}
                                className="flex items-center justify-between gap-3 rounded-md border px-3 py-2"
                            >
                                <div>
                                    <p className="font-medium">{d.title}</p>
                                    <p className="text-xs text-muted-foreground">
                                        {String(
                                            d.document_type ?? '',
                                        ).replace(/_/g, ' ')}{' '}
                                        · {d.status}
                                        {d.expiry_date
                                            ? ` · expires ${d.expiry_date}`
                                            : ''}
                                    </p>
                                </div>
                                {d.file_path && (
                                    <a
                                        className="text-sm text-primary underline"
                                        href={
                                            d.file_path.startsWith('/assets/') ||
                                            d.file_path.startsWith('http')
                                                ? d.file_path
                                                : `/storage/${d.file_path}`
                                        }
                                        target="_blank"
                                        rel="noreferrer"
                                    >
                                        View
                                    </a>
                                )}
                            </div>
                        ))}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Insurance</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        {!insurance && (
                            <p className="text-muted-foreground">
                                No insurance policy on file.
                            </p>
                        )}
                        {insurance && (
                            <>
                                <Row label="Company">
                                    {insurance.insurance_company}
                                </Row>
                                <Row label="Policy">
                                    {insurance.policy_number}
                                </Row>
                                <Row label="Type">
                                    {String(insurance.type ?? '').replace(
                                        /_/g,
                                        ' ',
                                    )}
                                </Row>
                                <Row label="Cover">
                                    {insurance.coverage_start_date ?? '—'} →{' '}
                                    {insurance.coverage_end_date ?? '—'}
                                </Row>
                                <Row label="Status">{insurance.status}</Row>
                            </>
                        )}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>
                            Maintenance ({maintenance.length})
                        </CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        {maintenance.length === 0 && (
                            <p className="text-muted-foreground">
                                No maintenance records.
                            </p>
                        )}
                        {maintenance.map((m: TruckMaintenanceRow) => (
                            <div
                                key={m.id}
                                className="rounded-md border px-3 py-2"
                            >
                                <p className="font-medium">
                                    {String(
                                        m.maintenance_type ?? '',
                                    ).replace(/_/g, ' ')}{' '}
                                    · {m.status}
                                </p>
                                {m.description && (
                                    <p className="text-muted-foreground">
                                        {m.description}
                                    </p>
                                )}
                            </div>
                        ))}
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle>Activity ({logs.length})</CardTitle>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        {logs.length === 0 && (
                            <p className="text-muted-foreground">
                                No activity yet.
                            </p>
                        )}
                        {logs.map((l: TruckLogRow) => (
                            <div
                                key={l.id}
                                className="rounded-md border px-3 py-2"
                            >
                                <p className="font-medium">
                                    {String(l.action ?? '').replace(/_/g, ' ')}
                                </p>
                                {l.description && (
                                    <p className="text-muted-foreground">
                                        {l.description}
                                    </p>
                                )}
                            </div>
                        ))}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
