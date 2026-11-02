// resources/js/pages/backend/ActivityLogs/show.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Trash2, ScrollText } from 'lucide-react';
import { IosBackButton } from '@/components/ios-back-button';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface ActivityLogDetail {
    id: number;
    action: string;
    action_label: string;
    description: string;
    module: string | null;
    level: string;
    level_color: string;
    user: {
        id: number;
        name: string;
        email?: string;
        phone?: string;
        role?: string;
    } | null;
    subject_type: string | null;
    subject_type_full?: string | null;
    subject_id: number | null;
    properties?: Record<string, unknown> | null;
    ip_address: string | null;
    user_agent?: string | null;
    request_method?: string | null;
    request_url?: string | null;
    created_at: string | null;
    created_at_human: string | null;
}

interface Props {
    log: ActivityLogDetail;
    can: { delete: boolean };
}

export default function ActivityLogShow({ log, can }: Props) {
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: '/admin' },
        { title: 'Activity Logs', href: '/admin/activity-logs' },
        { title: `#${log.id}`, href: '' },
    ];

    const handleDelete = () => {
        if (!can.delete) return;
        if (!confirm('Delete this activity log?')) return;
        router.delete(`/admin/activity-logs/${log.id}`);
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Activity Log #${log.id} | Logs`}>
                <meta name="description" content="Detailed view of platform activity log entry." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                            <ScrollText className="h-6 w-6" />
                            Activity #{log.id}
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            {log.created_at_human} · {log.action_label}
                        </p>
                    </div>
                    <div className="flex gap-2">
                        <IosBackButton href="/admin/activity-logs" />
                        {can.delete && (
                            <Button
                                variant="destructive"
                                type="button"
                                className="cursor-pointer"
                                onClick={handleDelete}
                            >
                                <Trash2 className="mr-2 h-4 w-4" />
                                Delete
                            </Button>
                        )}
                    </div>
                </div>

                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle>Summary</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Row label="Action">
                                <Badge variant="outline">{log.action}</Badge>
                            </Row>
                            <Row label="Description">{log.description}</Row>
                            <Row label="Module">{log.module ?? '—'}</Row>
                            <Row label="Level">
                                <Badge>{log.level}</Badge>
                            </Row>
                            <Row label="When">
                                {log.created_at
                                    ? new Date(log.created_at).toLocaleString()
                                    : '—'}
                            </Row>
                            <Row label="IP">{log.ip_address ?? '—'}</Row>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Actor & Subject</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-3 text-sm">
                            <Row label="User">
                                {log.user
                                    ? `${log.user.name} (${log.user.role ?? 'n/a'})`
                                    : 'System / guest'}
                            </Row>
                            <Row label="Email">{log.user?.email ?? '—'}</Row>
                            <Row label="Phone">{log.user?.phone ?? '—'}</Row>
                            <Row label="Subject">
                                {log.subject_type
                                    ? `${log.subject_type} #${log.subject_id}`
                                    : '—'}
                            </Row>
                            <Row label="Method">{log.request_method ?? '—'}</Row>
                            <Row label="URL">
                                <span className="break-all font-mono text-xs">
                                    {log.request_url ?? '—'}
                                </span>
                            </Row>
                        </CardContent>
                    </Card>

                    <Card className="md:col-span-2">
                        <CardHeader>
                            <CardTitle>Properties</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <pre className="overflow-x-auto rounded-lg bg-muted p-4 text-xs">
                                {log.properties
                                    ? JSON.stringify(log.properties, null, 2)
                                    : '—'}
                            </pre>
                            {log.user_agent && (
                                <p className="mt-3 text-xs text-muted-foreground break-all">
                                    UA: {log.user_agent}
                                </p>
                            )}
                        </CardContent>
                    </Card>
                </div>
            </div>
        </AppLayout>
    );
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
            <span className="w-28 shrink-0 font-medium text-muted-foreground">
                {label}
            </span>
            <span className="flex-1">{children}</span>
        </div>
    );
}
