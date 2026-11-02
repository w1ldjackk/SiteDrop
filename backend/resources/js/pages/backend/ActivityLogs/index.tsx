// resources/js/pages/backend/ActivityLogs/index.tsx
import { Head, Link, router } from '@inertiajs/react';
import {
    Search,
    Eye,
    Trash2,
    ScrollText,
    Filter,
} from 'lucide-react';
import { useState } from 'react';

import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface ActivityUser {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    role?: string;
}

interface ActivityLogItem {
    id: number;
    action: string;
    action_label: string;
    description: string;
    module: string | null;
    level: string;
    level_color: string;
    user: ActivityUser | null;
    subject_type: string | null;
    subject_id: number | null;
    ip_address: string | null;
    created_at: string | null;
    created_at_human: string | null;
}

interface PaginationLink {
    url: string | null;
    label: string;
    active: boolean;
}

interface Props {
    logs: {
        data: ActivityLogItem[];
        current_page: number;
        last_page: number;
        per_page: number;
        total: number;
        links: PaginationLink[];
    };
    filters: {
        search?: string;
        module?: string;
        action?: string;
        level?: string;
        from?: string;
        to?: string;
    };
    modules: string[];
    actions: string[];
    can: {
        delete: boolean;
    };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Activity Logs', href: '/admin/activity-logs' },
];

function levelBadgeVariant(
    level: string,
): 'default' | 'secondary' | 'destructive' | 'outline' {
    if (level === 'critical') return 'destructive';
    if (level === 'warning') return 'secondary';
    return 'outline';
}

export default function ActivityLogsIndex({
    logs,
    filters,
    modules,
    actions,
    can,
}: Props) {
    const [selected, setSelected] = useState<number[]>([]);

    const applyFilters = (overrides: Record<string, string | undefined> = {}) => {
        router.get(
            '/admin/activity-logs',
            {
                search: filters.search ?? '',
                module: filters.module ?? '',
                action: filters.action ?? '',
                level: filters.level ?? '',
                from: filters.from ?? '',
                to: filters.to ?? '',
                ...overrides,
            },
            { preserveState: true, preserveScroll: true },
        );
    };

    const handleSearch = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        applyFilters({
            search: String(formData.get('search') ?? ''),
            from: String(formData.get('from') ?? ''),
            to: String(formData.get('to') ?? ''),
        });
    };

    const toggleSelect = (id: number) => {
        setSelected((prev) =>
            prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id],
        );
    };

    const bulkDelete = () => {
        if (!can.delete || selected.length === 0) return;
        if (!confirm(`Delete ${selected.length} selected log(s)?`)) return;
        router.post(
            '/admin/activity-logs/bulk-delete',
            { ids: selected },
            {
                onSuccess: () => setSelected([]),
            },
        );
    };

    const deleteOne = (id: number) => {
        if (!can.delete) return;
        if (!confirm('Delete this activity log?')) return;
        router.delete(`/admin/activity-logs/${id}`, {
            preserveScroll: true,
            onSuccess: () =>
                setSelected((prev) => prev.filter((x) => x !== id)),
        });
    };

    const selectAllOnPage = () => {
        if (selected.length === logs.data.length) {
            setSelected([]);
        } else {
            setSelected(logs.data.map((l) => l.id));
        }
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Activity Logs | SiteDrop Admin">
                <meta name="description" content="Audit log of platform activity and admin actions." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                    <div>
                        <h1 className="flex items-center gap-2 text-3xl font-bold tracking-tight">
                            <ScrollText className="h-8 w-8" />
                            Activity Logs
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Audit trail of platform actions. Visible to admins
                            and users with the “view activity logs” permission.
                        </p>
                    </div>

                    {can.delete && (
                        <Button
                            variant="destructive"
                            className="cursor-pointer"
                            disabled={selected.length === 0}
                            onClick={bulkDelete}
                            title={
                                selected.length === 0
                                    ? 'Select one or more logs first'
                                    : `Delete ${selected.length} selected`
                            }
                        >
                            <Trash2 className="mr-2 h-4 w-4" />
                            {selected.length > 0
                                ? `Delete selected (${selected.length})`
                                : 'Delete selected'}
                        </Button>
                    )}
                </div>

                <Card>
                    <CardHeader className="pb-4">
                        <div className="flex flex-col gap-4">
                            <div className="flex items-center gap-2">
                                <Filter className="h-4 w-4 text-muted-foreground" />
                                <CardTitle>Filters</CardTitle>
                            </div>

                            <form
                                onSubmit={handleSearch}
                                className="grid gap-3 md:grid-cols-2 lg:grid-cols-6"
                            >
                                <div className="relative lg:col-span-2">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Search description, action, user…"
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>

                                <Select
                                    value={filters.module || 'all'}
                                    onValueChange={(v) =>
                                        applyFilters({
                                            module: v === 'all' ? '' : v,
                                        })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder="Module" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="all">All modules</SelectItem>
                                        {modules.map((m) => (
                                            <SelectItem key={m} value={m}>
                                                {m}
                                            </SelectItem>
                                        ))}
                                    </SelectContent>
                                </Select>

                                <Select
                                    value={filters.level || 'all'}
                                    onValueChange={(v) =>
                                        applyFilters({
                                            level: v === 'all' ? '' : v,
                                        })
                                    }
                                >
                                    <SelectTrigger>
                                        <SelectValue placeholder="Level" />
                                    </SelectTrigger>
                                    <SelectContent>
                                        <SelectItem value="all">All levels</SelectItem>
                                        <SelectItem value="info">Info</SelectItem>
                                        <SelectItem value="warning">Warning</SelectItem>
                                        <SelectItem value="critical">Critical</SelectItem>
                                    </SelectContent>
                                </Select>

                                <Input
                                    type="date"
                                    name="from"
                                    defaultValue={filters.from ?? ''}
                                    aria-label="From date"
                                />
                                <Input
                                    type="date"
                                    name="to"
                                    defaultValue={filters.to ?? ''}
                                    aria-label="To date"
                                />

                                <div className="flex gap-2 lg:col-span-6">
                                    <Button type="submit">Apply</Button>
                                    <Button
                                        type="button"
                                        variant="outline"
                                        onClick={() =>
                                            router.get('/admin/activity-logs')
                                        }
                                    >
                                        Reset
                                    </Button>
                                </div>
                            </form>
                        </div>
                    </CardHeader>

                    <CardContent className="p-0">
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    {can.delete && (
                                        <TableHead className="w-10">
                                            <input
                                                type="checkbox"
                                                checked={
                                                    logs.data.length > 0 &&
                                                    selected.length ===
                                                        logs.data.length
                                                }
                                                onChange={selectAllOnPage}
                                                className="h-4 w-4 cursor-pointer rounded border"
                                                title="Select all on page"
                                                aria-label="Select all on page"
                                            />
                                        </TableHead>
                                    )}
                                    <TableHead>When</TableHead>
                                    <TableHead>Action</TableHead>
                                    <TableHead>Description</TableHead>
                                    <TableHead>User</TableHead>
                                    <TableHead>Module</TableHead>
                                    <TableHead>Level</TableHead>
                                    <TableHead>IP</TableHead>
                                    <TableHead className="w-24 text-right">
                                        Actions
                                    </TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {logs.data.length === 0 ? (
                                    <TableRow>
                                        <TableCell
                                            colSpan={can.delete ? 9 : 8}
                                            className="py-12 text-center text-muted-foreground"
                                        >
                                            No activity logs found.
                                        </TableCell>
                                    </TableRow>
                                ) : (
                                    logs.data.map((log) => (
                                        <TableRow key={log.id}>
                                            {can.delete && (
                                                <TableCell>
                                                    <input
                                                        type="checkbox"
                                                        checked={selected.includes(
                                                            log.id,
                                                        )}
                                                        onChange={() =>
                                                            toggleSelect(log.id)
                                                        }
                                                        className="h-4 w-4 cursor-pointer rounded border"
                                                    />
                                                </TableCell>
                                            )}
                                            <TableCell className="whitespace-nowrap text-sm">
                                                <div>{log.created_at_human}</div>
                                                <div className="text-xs text-muted-foreground">
                                                    {log.created_at
                                                        ? new Date(
                                                              log.created_at,
                                                          ).toLocaleString()
                                                        : '—'}
                                                </div>
                                            </TableCell>
                                            <TableCell>
                                                <Badge variant="outline">
                                                    {log.action_label}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="max-w-xs truncate text-sm">
                                                {log.description}
                                            </TableCell>
                                            <TableCell className="text-sm">
                                                {log.user ? (
                                                    <div>
                                                        <div className="font-medium">
                                                            {log.user.name}
                                                        </div>
                                                        <div className="text-xs text-muted-foreground">
                                                            {log.user.role}
                                                        </div>
                                                    </div>
                                                ) : (
                                                    <span className="text-muted-foreground">
                                                        System
                                                    </span>
                                                )}
                                            </TableCell>
                                            <TableCell>
                                                {log.module ?? '—'}
                                            </TableCell>
                                            <TableCell>
                                                <Badge
                                                    variant={levelBadgeVariant(
                                                        log.level,
                                                    )}
                                                >
                                                    {log.level}
                                                </Badge>
                                            </TableCell>
                                            <TableCell className="font-mono text-xs">
                                                {log.ip_address ?? '—'}
                                            </TableCell>
                                            <TableCell>
                                                <div className="flex items-center justify-end gap-1">
                                                    <Button
                                                        variant="ghost"
                                                        size="icon"
                                                        className="cursor-pointer"
                                                        asChild
                                                    >
                                                        <Link
                                                            href={`/admin/activity-logs/${log.id}`}
                                                            title="View"
                                                        >
                                                            <Eye className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                View
                                                            </span>
                                                        </Link>
                                                    </Button>
                                                    {can.delete && (
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            type="button"
                                                            className="cursor-pointer text-destructive hover:text-destructive"
                                                            title="Delete"
                                                            onClick={() =>
                                                                deleteOne(
                                                                    log.id,
                                                                )
                                                            }
                                                        >
                                                            <Trash2 className="h-4 w-4" />
                                                            <span className="sr-only">
                                                                Delete
                                                            </span>
                                                        </Button>
                                                    )}
                                                </div>
                                            </TableCell>
                                        </TableRow>
                                    ))
                                )}
                            </TableBody>
                        </Table>

                        {logs.last_page > 1 && (
                            <div className="flex items-center justify-between border-t px-4 py-3 text-sm text-muted-foreground">
                                <span>
                                    Page {logs.current_page} of {logs.last_page}{' '}
                                    · {logs.total} total
                                </span>
                                <div className="flex gap-2">
                                    {logs.links.map((link, i) => (
                                        <Button
                                            key={i}
                                            size="sm"
                                            variant={
                                                link.active
                                                    ? 'default'
                                                    : 'outline'
                                            }
                                            disabled={!link.url}
                                            onClick={() =>
                                                link.url &&
                                                router.get(link.url)
                                            }
                                            dangerouslySetInnerHTML={{
                                                __html: link.label,
                                            }}
                                        />
                                    ))}
                                </div>
                            </div>
                        )}
                    </CardContent>
                </Card>

                {actions.length > 0 && (
                    <p className="text-xs text-muted-foreground">
                        Known actions: {actions.slice(0, 12).join(', ')}
                        {actions.length > 12 ? '…' : ''}
                    </p>
                )}
            </div>
        </AppLayout>
    );
}
