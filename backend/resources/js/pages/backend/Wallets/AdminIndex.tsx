import { Head, Link, router, useForm } from '@inertiajs/react';
import { Check, Search, Wallet, X } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import {
    Table,
    TableBody,
    TableCell,
    TableHead,
    TableHeader,
    TableRow,
} from '@/components/ui/table';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';

interface WalletRow {
    id: number;
    balance: number;
    blocked_balance: number;
    is_active: boolean;
    user?: { id: number; name: string; email?: string; phone?: string; role?: string } | null;
}

interface PendingTx {
    id: number;
    amount: number;
    type: string;
    category?: string;
    description: string;
    reference?: string;
    status: string;
    user?: { id: number; name: string } | null;
    created_at?: string;
}

interface Props {
    wallets: { data: WalletRow[]; total: number; links: { url: string | null; label: string; active: boolean }[] };
    pending: PendingTx[];
    filters: { search?: string };
    summary: {
        wallets: number;
        total_balance: number;
        total_blocked: number;
        pending_count: number;
    };
    area?: string;
}

export default function AdminIndex({ wallets, pending, filters, summary, area }: Props) {
    const { path, base } = useRoleArea(area ?? 'admin');
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Wallets', href: path('wallets') },
    ];

    const approveForm = useForm({ admin_notes: '' });
    const rejectForm = useForm({ admin_notes: '' });

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Wallets | Admin" />
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-wrap items-end justify-between gap-3">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold">
                            <Wallet className="h-6 w-6" />
                            Wallets
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            Manage balances, approve deposits/withdrawals, adjust funds
                        </p>
                    </div>
                    <Button variant="outline" asChild>
                        <Link href={path('wallets/mine')}>My wallet</Link>
                    </Button>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        { label: 'Wallets', value: summary.wallets },
                        {
                            label: 'Total balance',
                            value: `GHS ${Number(summary.total_balance).toFixed(2)}`,
                        },
                        {
                            label: 'Blocked',
                            value: `GHS ${Number(summary.total_blocked).toFixed(2)}`,
                        },
                        { label: 'Pending requests', value: summary.pending_count },
                    ].map((s) => (
                        <Card key={s.label}>
                            <CardHeader className="pb-2">
                                <p className="text-xs text-muted-foreground">{s.label}</p>
                                <CardTitle className="text-xl">{s.value}</CardTitle>
                            </CardHeader>
                        </Card>
                    ))}
                </div>

                {pending.length > 0 && (
                    <Card>
                        <CardHeader>
                            <CardTitle>Pending approvals</CardTitle>
                        </CardHeader>
                        <CardContent className="space-y-3">
                            {pending.map((tx) => (
                                <div
                                    key={tx.id}
                                    className="flex flex-col gap-3 rounded-xl border p-3 sm:flex-row sm:items-center sm:justify-between"
                                >
                                    <div>
                                        <div className="font-medium">
                                            {tx.user?.name ?? 'User'} ·{' '}
                                            <span className="capitalize">{tx.category ?? tx.type}</span>
                                        </div>
                                        <div className="text-sm text-muted-foreground">
                                            GHS {Number(tx.amount).toFixed(2)} · {tx.reference}
                                        </div>
                                        <div className="text-xs text-muted-foreground">
                                            {tx.description}
                                        </div>
                                    </div>
                                    <div className="flex gap-2">
                                        <Button
                                            size="sm"
                                            onClick={() =>
                                                approveForm.post(
                                                    path(`wallets/transactions/${tx.id}/approve`),
                                                    { preserveScroll: true },
                                                )
                                            }
                                        >
                                            <Check className="mr-1 h-4 w-4" />
                                            Approve
                                        </Button>
                                        <Button
                                            size="sm"
                                            variant="destructive"
                                            onClick={() => {
                                                const notes = window.prompt('Rejection reason (optional)') ?? '';
                                                rejectForm.setData('admin_notes', notes);
                                                rejectForm.post(
                                                    path(`wallets/transactions/${tx.id}/reject`),
                                                    { preserveScroll: true },
                                                );
                                            }}
                                        >
                                            <X className="mr-1 h-4 w-4" />
                                            Reject
                                        </Button>
                                    </div>
                                </div>
                            ))}
                        </CardContent>
                    </Card>
                )}

                <Card>
                    <CardHeader className="flex flex-row items-center justify-between gap-3">
                        <CardTitle>All wallets</CardTitle>
                        <form
                            className="flex gap-2"
                            onSubmit={(e) => {
                                e.preventDefault();
                                const fd = new FormData(e.currentTarget);
                                router.get(
                                    path('wallets'),
                                    { search: String(fd.get('search') || '') },
                                    { preserveState: true },
                                );
                            }}
                        >
                            <Input
                                name="search"
                                placeholder="Search user…"
                                defaultValue={filters.search ?? ''}
                                className="w-48"
                            />
                            <Button type="submit" size="icon" variant="secondary">
                                <Search className="h-4 w-4" />
                            </Button>
                        </form>
                    </CardHeader>
                    <CardContent>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>User</TableHead>
                                    <TableHead>Role</TableHead>
                                    <TableHead>Balance</TableHead>
                                    <TableHead>Blocked</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead />
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {wallets.data.map((w) => (
                                    <TableRow key={w.id}>
                                        <TableCell>
                                            <div className="font-medium">{w.user?.name ?? '—'}</div>
                                            <div className="text-xs text-muted-foreground">
                                                {w.user?.email ?? w.user?.phone}
                                            </div>
                                        </TableCell>
                                        <TableCell className="capitalize">
                                            {w.user?.role ?? '—'}
                                        </TableCell>
                                        <TableCell>
                                            GHS {Number(w.balance).toFixed(2)}
                                        </TableCell>
                                        <TableCell>
                                            GHS {Number(w.blocked_balance).toFixed(2)}
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant={w.is_active ? 'default' : 'destructive'}>
                                                {w.is_active ? 'Active' : 'Suspended'}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="text-right">
                                            <Button size="sm" variant="outline" asChild>
                                                <Link href={path(`wallets/${w.id}`)}>Manage</Link>
                                            </Button>
                                        </TableCell>
                                    </TableRow>
                                ))}
                            </TableBody>
                        </Table>
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
