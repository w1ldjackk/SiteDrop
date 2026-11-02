import { Head, Link, router } from '@inertiajs/react';
import { Eye, Search, Truck } from 'lucide-react';
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
import type { BreadcrumbItem } from '@/types';

interface TruckRow {
    id: number;
    registration_number?: string;
    make?: string;
    model?: string;
    year?: number;
    vehicle_type?: string;
    capacity_tons?: number;
    status?: string;
    is_verified?: boolean;
    owner?: { name: string } | null;
    driver?: { name: string; phone?: string } | null;
}

interface DriverRow {
    id: number;
    name: string;
    email?: string;
    phone?: string;
    status?: string;
}

interface Props {
    trucks: {
        data: TruckRow[];
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    drivers: {
        data: DriverRow[];
        total: number;
        links: { url: string | null; label: string; active: boolean }[];
    };
    tab: string;
    filters: { search?: string; status?: string; tab?: string };
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'Trucks & Drivers', href: '/admin/trucks' },
];

export default function TrucksIndex({ trucks, drivers, tab, filters }: Props) {
    const activeTab = tab === 'drivers' ? 'drivers' : 'trucks';

    const switchTab = (next: string) => {
        router.get(
            '/admin/trucks',
            { ...filters, tab: next },
            { preserveState: true, preserveScroll: true },
        );
    };

    const handleFilter = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const query: Record<string, string> = { tab: activeTab };
        formData.forEach((v, k) => {
            if (v.toString().trim()) query[k] = v.toString().trim();
        });
        router.get('/admin/trucks', query, {
            preserveState: true,
            preserveScroll: true,
        });
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Trucks & Drivers | SiteDrop Admin">
                <meta name="description" content="Manage fleet, drivers, trucks, documents and maintenance." />
            </Head>
            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <Truck className="h-6 w-6" />
                        Trucks &amp; Drivers
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Fleet vehicles and registered drivers
                    </p>
                </div>

                <div className="flex gap-2">
                    <Button
                        size="sm"
                        variant={activeTab === 'trucks' ? 'default' : 'outline'}
                        onClick={() => switchTab('trucks')}
                    >
                        Trucks ({trucks.total})
                    </Button>
                    <Button
                        size="sm"
                        variant={activeTab === 'drivers' ? 'default' : 'outline'}
                        onClick={() => switchTab('drivers')}
                    >
                        Drivers ({drivers.total})
                    </Button>
                </div>

                <Card>
                    <CardHeader className="pb-3">
                        <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                            <CardTitle>
                                {activeTab === 'trucks' ? 'Trucks' : 'Drivers'}
                            </CardTitle>
                            <form
                                onSubmit={handleFilter}
                                className="flex flex-1 gap-3 sm:justify-end"
                            >
                                <div className="relative min-w-[220px] flex-1 sm:max-w-sm">
                                    <Search className="absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                                    <Input
                                        name="search"
                                        placeholder="Search..."
                                        className="pl-9"
                                        defaultValue={filters.search ?? ''}
                                    />
                                </div>
                                <Button type="submit" size="sm">
                                    Filter
                                </Button>
                            </form>
                        </div>
                    </CardHeader>
                    <CardContent>
                        {activeTab === 'trucks' ? (
                            <div className="overflow-x-auto rounded-md border">
                                <Table>
                                    <TableHeader>
                                        <TableRow>
                                            <TableHead>Registration</TableHead>
                                            <TableHead>Vehicle</TableHead>
                                            <TableHead>Owner</TableHead>
                                            <TableHead>Driver</TableHead>
                                            <TableHead>Status</TableHead>
                                            <TableHead className="text-right">
                                                Actions
                                            </TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {trucks.data.length === 0 ? (
                                            <TableRow>
                                                <TableCell
                                                    colSpan={6}
                                                    className="py-10 text-center text-muted-foreground"
                                                >
                                                    No trucks found
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            trucks.data.map((t) => (
                                                <TableRow key={t.id}>
                                                    <TableCell className="font-medium">
                                                        {t.registration_number ||
                                                            `#${t.id}`}
                                                    </TableCell>
                                                    <TableCell>
                                                        {[t.make, t.model, t.year]
                                                            .filter(Boolean)
                                                            .join(' ') || '—'}
                                                        <div className="text-xs text-muted-foreground">
                                                            {t.vehicle_type ||
                                                                '—'}
                                                        </div>
                                                    </TableCell>
                                                    <TableCell>
                                                        {t.owner?.name || '—'}
                                                    </TableCell>
                                                    <TableCell>
                                                        {t.driver?.name ||
                                                            'Unassigned'}
                                                    </TableCell>
                                                    <TableCell>
                                                        <Badge variant="secondary">
                                                            {t.status || '—'}
                                                        </Badge>
                                                    </TableCell>
                                                    <TableCell className="text-right">
                                                        <Button
                                                            variant="ghost"
                                                            size="icon"
                                                            asChild
                                                        >
                                                            <Link
                                                                href={`/admin/trucks/${t.id}`}
                                                            >
                                                                <Eye className="h-4 w-4" />
                                                            </Link>
                                                        </Button>
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </div>
                        ) : (
                            <div className="overflow-x-auto rounded-md border">
                                <Table>
                                    <TableHeader>
                                        <TableRow>
                                            <TableHead>Name</TableHead>
                                            <TableHead>Email</TableHead>
                                            <TableHead>Phone</TableHead>
                                            <TableHead>Status</TableHead>
                                        </TableRow>
                                    </TableHeader>
                                    <TableBody>
                                        {drivers.data.length === 0 ? (
                                            <TableRow>
                                                <TableCell
                                                    colSpan={4}
                                                    className="py-10 text-center text-muted-foreground"
                                                >
                                                    No drivers found
                                                </TableCell>
                                            </TableRow>
                                        ) : (
                                            drivers.data.map((d) => (
                                                <TableRow key={d.id}>
                                                    <TableCell className="font-medium">
                                                        {d.name}
                                                    </TableCell>
                                                    <TableCell>
                                                        {d.email || '—'}
                                                    </TableCell>
                                                    <TableCell>
                                                        {d.phone || '—'}
                                                    </TableCell>
                                                    <TableCell>
                                                        <Badge variant="outline">
                                                            {d.status ||
                                                                'active'}
                                                        </Badge>
                                                    </TableCell>
                                                </TableRow>
                                            ))
                                        )}
                                    </TableBody>
                                </Table>
                            </div>
                        )}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
