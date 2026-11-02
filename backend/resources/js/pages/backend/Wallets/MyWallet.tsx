import { Head, useForm } from '@inertiajs/react';
import { ArrowDownToLine, ArrowUpFromLine, Wallet } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
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

interface Tx {
    id: number;
    type: string;
    category?: string;
    amount: number;
    description: string;
    reference?: string;
    status: string;
    created_at?: string;
    balance_after?: number;
    admin_notes?: string | null;
}

interface WalletRow {
    id: number;
    balance: number;
    blocked_balance: number;
    available_balance?: number;
    total_earned: number;
    total_spent: number;
    currency: string;
    is_active: boolean;
}

interface Props {
    wallet: WalletRow;
    transactions: { data: Tx[]; links?: unknown[]; total?: number };
    area?: string;
    canRequest?: boolean;
}

export default function MyWallet({ wallet, transactions, area, canRequest = true }: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Wallet', href: path('wallet') },
    ];

    const deposit = useForm({ amount: '', note: '' });
    const withdraw = useForm({ amount: '', note: '', destination: '' });

    const available =
        wallet.available_balance ??
        Math.max(0, Number(wallet.balance) - Number(wallet.blocked_balance));

    const statusBadge = (s: string) => {
        const v = s?.toLowerCase();
        if (v === 'completed') return 'default';
        if (v === 'pending') return 'secondary';
        if (v === 'rejected' || v === 'failed') return 'destructive';
        return 'outline';
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Wallet | SiteDrop" />
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <Wallet className="h-6 w-6" />
                        My Wallet
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Balance, deposits, withdrawals, and history
                        {!wallet.is_active && (
                            <span className="ml-2 text-destructive">(Suspended)</span>
                        )}
                    </p>
                </div>

                <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    {[
                        { label: 'Available', value: `GHS ${available.toFixed(2)}` },
                        { label: 'Balance', value: `GHS ${Number(wallet.balance).toFixed(2)}` },
                        {
                            label: 'Blocked',
                            value: `GHS ${Number(wallet.blocked_balance).toFixed(2)}`,
                        },
                        {
                            label: 'Lifetime earned',
                            value: `GHS ${Number(wallet.total_earned).toFixed(2)}`,
                        },
                    ].map((s) => (
                        <Card key={s.label}>
                            <CardHeader className="pb-2">
                                <CardDescription>{s.label}</CardDescription>
                                <CardTitle className="text-xl">{s.value}</CardTitle>
                            </CardHeader>
                        </Card>
                    ))}
                </div>

                {canRequest && wallet.is_active && (
                    <div className="grid gap-4 md:grid-cols-2">
                        <Card>
                            <CardHeader>
                                <CardTitle className="flex items-center gap-2 text-base">
                                    <ArrowDownToLine className="h-4 w-4" />
                                    Request deposit
                                </CardTitle>
                                <CardDescription>
                                    Admin must approve before funds are credited
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <form
                                    className="space-y-3"
                                    onSubmit={(e) => {
                                        e.preventDefault();
                                        deposit.post(path('wallet/deposit'), {
                                            preserveScroll: true,
                                            onSuccess: () => deposit.reset(),
                                        });
                                    }}
                                >
                                    <div className="space-y-1">
                                        <Label htmlFor="dep-amount">Amount (GHS)</Label>
                                        <Input
                                            id="dep-amount"
                                            type="number"
                                            min="1"
                                            step="0.01"
                                            value={deposit.data.amount}
                                            onChange={(e) =>
                                                deposit.setData('amount', e.target.value)
                                            }
                                            required
                                        />
                                    </div>
                                    <div className="space-y-1">
                                        <Label htmlFor="dep-note">Note (optional)</Label>
                                        <Input
                                            id="dep-note"
                                            value={deposit.data.note}
                                            onChange={(e) =>
                                                deposit.setData('note', e.target.value)
                                            }
                                        />
                                    </div>
                                    <Button type="submit" disabled={deposit.processing}>
                                        Submit deposit
                                    </Button>
                                </form>
                            </CardContent>
                        </Card>

                        <Card>
                            <CardHeader>
                                <CardTitle className="flex items-center gap-2 text-base">
                                    <ArrowUpFromLine className="h-4 w-4" />
                                    Request withdrawal
                                </CardTitle>
                                <CardDescription>
                                    Amount is held until admin approves or rejects
                                </CardDescription>
                            </CardHeader>
                            <CardContent>
                                <form
                                    className="space-y-3"
                                    onSubmit={(e) => {
                                        e.preventDefault();
                                        withdraw.post(path('wallet/withdraw'), {
                                            preserveScroll: true,
                                            onSuccess: () => withdraw.reset(),
                                        });
                                    }}
                                >
                                    <div className="space-y-1">
                                        <Label htmlFor="wdr-amount">Amount (GHS)</Label>
                                        <Input
                                            id="wdr-amount"
                                            type="number"
                                            min="1"
                                            step="0.01"
                                            value={withdraw.data.amount}
                                            onChange={(e) =>
                                                withdraw.setData('amount', e.target.value)
                                            }
                                            required
                                        />
                                    </div>
                                    <div className="space-y-1">
                                        <Label htmlFor="wdr-dest">Destination (optional)</Label>
                                        <Input
                                            id="wdr-dest"
                                            placeholder="MoMo / bank details"
                                            value={withdraw.data.destination}
                                            onChange={(e) =>
                                                withdraw.setData('destination', e.target.value)
                                            }
                                        />
                                    </div>
                                    <div className="space-y-1">
                                        <Label htmlFor="wdr-note">Note (optional)</Label>
                                        <Input
                                            id="wdr-note"
                                            value={withdraw.data.note}
                                            onChange={(e) =>
                                                withdraw.setData('note', e.target.value)
                                            }
                                        />
                                    </div>
                                    <Button type="submit" disabled={withdraw.processing}>
                                        Submit withdrawal
                                    </Button>
                                </form>
                            </CardContent>
                        </Card>
                    </div>
                )}

                <Card>
                    <CardHeader>
                        <CardTitle>Transaction history</CardTitle>
                    </CardHeader>
                    <CardContent>
                        <Table>
                            <TableHeader>
                                <TableRow>
                                    <TableHead>Date</TableHead>
                                    <TableHead>Type</TableHead>
                                    <TableHead>Category</TableHead>
                                    <TableHead>Amount</TableHead>
                                    <TableHead>Status</TableHead>
                                    <TableHead>Description</TableHead>
                                </TableRow>
                            </TableHeader>
                            <TableBody>
                                {(transactions.data ?? []).length === 0 && (
                                    <TableRow>
                                        <TableCell colSpan={6} className="text-center text-muted-foreground">
                                            No transactions yet
                                        </TableCell>
                                    </TableRow>
                                )}
                                {(transactions.data ?? []).map((t) => (
                                    <TableRow key={t.id}>
                                        <TableCell className="whitespace-nowrap text-xs">
                                            {t.created_at
                                                ? new Date(t.created_at).toLocaleString()
                                                : '—'}
                                        </TableCell>
                                        <TableCell className="capitalize">{t.type}</TableCell>
                                        <TableCell className="capitalize">
                                            {t.category ?? '—'}
                                        </TableCell>
                                        <TableCell className="font-medium">
                                            GHS {Number(t.amount).toFixed(2)}
                                        </TableCell>
                                        <TableCell>
                                            <Badge variant={statusBadge(t.status) as 'default'}>
                                                {t.status}
                                            </Badge>
                                        </TableCell>
                                        <TableCell className="max-w-[220px] truncate text-sm">
                                            {t.description}
                                            {t.reference && (
                                                <div className="font-mono text-[10px] text-muted-foreground">
                                                    {t.reference}
                                                </div>
                                            )}
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
