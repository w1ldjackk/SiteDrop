import { Head, router, useForm } from '@inertiajs/react';
import { Wallet } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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

interface Props {
    wallet: {
        id: number;
        balance: number;
        blocked_balance: number;
        total_earned: number;
        total_spent: number;
        is_active: boolean;
        currency: string;
        user?: { id: number; name: string; email?: string; phone?: string; role?: string };
    };
    transactions: {
        data: Array<{
            id: number;
            type: string;
            category?: string;
            amount: number;
            status: string;
            description: string;
            reference?: string;
            created_at?: string;
            admin_notes?: string | null;
        }>;
    };
    area?: string;
}

export default function AdminShow({ wallet, transactions, area }: Props) {
    const { path, base } = useRoleArea(area ?? 'admin');
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Wallets', href: path('wallets') },
        { title: wallet.user?.name ?? `Wallet #${wallet.id}`, href: path(`wallets/${wallet.id}`) },
    ];

    const credit = useForm({ amount: '', description: 'Admin credit' });
    const adjust = useForm({ amount: '', description: 'Admin adjustment', admin_notes: '' });

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title={`Wallet · ${wallet.user?.name ?? wallet.id}`} />
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div className="flex flex-wrap items-start justify-between gap-3">
                    <div>
                        <h1 className="flex items-center gap-2 text-2xl font-bold">
                            <Wallet className="h-6 w-6" />
                            {wallet.user?.name ?? 'Wallet'}
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            {wallet.user?.email} · {wallet.user?.phone} ·{' '}
                            <span className="capitalize">{wallet.user?.role}</span>
                        </p>
                    </div>
                    <Button
                        variant={wallet.is_active ? 'destructive' : 'default'}
                        onClick={() =>
                            router.post(path(`wallets/${wallet.id}/toggle`), {}, { preserveScroll: true })
                        }
                    >
                        {wallet.is_active ? 'Suspend wallet' : 'Activate wallet'}
                    </Button>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        { label: 'Balance', value: Number(wallet.balance).toFixed(2) },
                        { label: 'Blocked', value: Number(wallet.blocked_balance).toFixed(2) },
                        { label: 'Earned', value: Number(wallet.total_earned).toFixed(2) },
                        { label: 'Spent', value: Number(wallet.total_spent).toFixed(2) },
                    ].map((s) => (
                        <Card key={s.label}>
                            <CardHeader className="pb-2">
                                <p className="text-xs text-muted-foreground">{s.label}</p>
                                <CardTitle className="text-xl">
                                    {wallet.currency} {s.value}
                                </CardTitle>
                            </CardHeader>
                        </Card>
                    ))}
                </div>

                <div className="grid gap-4 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle className="text-base">Add funds (credit)</CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form
                                className="space-y-3"
                                onSubmit={(e) => {
                                    e.preventDefault();
                                    credit.post(path(`wallets/${wallet.id}/credit`), {
                                        preserveScroll: true,
                                        onSuccess: () => credit.reset('amount'),
                                    });
                                }}
                            >
                                <div className="space-y-1">
                                    <Label>Amount</Label>
                                    <Input
                                        type="number"
                                        min="0.01"
                                        step="0.01"
                                        value={credit.data.amount}
                                        onChange={(e) => credit.setData('amount', e.target.value)}
                                        required
                                    />
                                </div>
                                <div className="space-y-1">
                                    <Label>Description</Label>
                                    <Input
                                        value={credit.data.description}
                                        onChange={(e) =>
                                            credit.setData('description', e.target.value)
                                        }
                                        required
                                    />
                                </div>
                                <Button type="submit" disabled={credit.processing}>
                                    Credit wallet
                                </Button>
                            </form>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle className="text-base">
                                Adjust (positive credit / negative debit)
                            </CardTitle>
                        </CardHeader>
                        <CardContent>
                            <form
                                className="space-y-3"
                                onSubmit={(e) => {
                                    e.preventDefault();
                                    adjust.post(path(`wallets/${wallet.id}/adjust`), {
                                        preserveScroll: true,
                                        onSuccess: () => adjust.reset('amount'),
                                    });
                                }}
                            >
                                <div className="space-y-1">
                                    <Label>Amount (+ / −)</Label>
                                    <Input
                                        type="number"
                                        step="0.01"
                                        value={adjust.data.amount}
                                        onChange={(e) => adjust.setData('amount', e.target.value)}
                                        required
                                    />
                                </div>
                                <div className="space-y-1">
                                    <Label>Description</Label>
                                    <Input
                                        value={adjust.data.description}
                                        onChange={(e) =>
                                            adjust.setData('description', e.target.value)
                                        }
                                        required
                                    />
                                </div>
                                <Button type="submit" disabled={adjust.processing}>
                                    Apply adjustment
                                </Button>
                            </form>
                        </CardContent>
                    </Card>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Transactions</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Date</TableHead>
                                    <TableHead>Type</TableHead>
                                    <TableHead>Amount</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead>Description</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {transactions.data.map((t) => (
                                    <TableRow key={t.id}>
                                        <TableCell className="text-xs whitespace-nowrap">
                                            {t.created_at
                                                ? new Date(t.created_at).toLocaleString()
                                                : '—'}
                                        </TableCell>
                                        <TableCell className="capitalize">
                                            {t.category ?? t.type}
                                        </TableCell>
                                        <TableCell>GHS {Number(t.amount).toFixed(2)}</TableCell>
                                        <TableCell>
                                            <Badge variant="outline">{t.status}</Badge>
                                        </TableCell>
                                        <TableCell className="max-w-xs truncate text-sm">
                                            {t.description}
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
