// resources/js/pages/backend/Dashboard/Admin.tsx
import { Head, Link } from '@inertiajs/react';
import {
    Users,
    Store,
    ShoppingBag,
    Package,
    Truck,
    MapPin,
    DollarSign,
    BarChart3,
    Settings,
    ArrowUpRight,
    TrendingUp,
    TrendingDown,
    Activity,
} from 'lucide-react';
import { useState, useEffect, useMemo } from 'react';
import {
    Area,
    AreaChart,
    CartesianGrid,
    Legend,
    ResponsiveContainer,
    Tooltip,
    XAxis,
    YAxis,
} from 'recharts';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

interface DashboardProps {
    stats: {
        total_orders: number;
        total_users: number;
        total_sellers: number;
        total_products: number;
        total_sites: number;
        total_trucks: number;
    };
    recent_activity:
        | Array<{
              id?: string | number;
              type: string;
              title: string;
              subtitle: string;
              time: string;
              icon: string;
              color: string;
              user?: string | null;
          }>
        | {
              data: Array<{
                  id?: string | number;
                  type: string;
                  title: string;
                  subtitle: string;
                  time: string;
                  icon: string;
                  color: string;
                  user?: string | null;
              }>;
              current_page: number;
              last_page: number;
              per_page: number;
              total: number;
          };
    revenue_data: {
        total_revenue: number;
        platform_fee: number;
        seller_earnings: number;
        monthly_revenue: number;
        today_revenue: number;
    };
    order_stats: {
        pending: number;
        processing: number;
        in_transit: number;
        completed: number;
        cancelled: number;
    };
    seller_stats: {
        pending_approval: number;
        approved: number;
        suspended: number;
    };
    delivery_stats: {
        pending: number;
        assigned: number;
        in_transit: number;
        completed: number;
        failed: number;
    };
    chart_data: Array<{
        date: string;
        label: string;
        orders: number;
        revenue: number;
        users: number;
    }>;
    quick_actions: Array<{
        icon: string;
        label: string;
        href: string;
        color: string;
    }>;
    platform_health: {
        active_users: { value: number; total: number; percentage: number };
        active_sellers: { value: number; total: number; percentage: number };
        order_completion_rate: {
            value: number;
            total: number;
            percentage: number;
        };
        system_uptime: string;
        last_backup: string;
        total_revenue: number;
    };
}

const breadcrumbs: BreadcrumbItem[] = [{ title: 'Dashboard', href: '/admin' }];

type TimeRange = 'today' | 'week' | 'month' | 'quarter' | 'year';

type ActivityItem = {
    id?: string | number;
    type: string;
    title: string;
    subtitle: string;
    time: string;
    icon: string;
    color: string;
    user?: string | null;
};

type ActivityPage = {
    data: ActivityItem[];
    current_page: number;
    last_page: number;
    per_page: number;
    total: number;
};

function normalizeActivity(
    input: DashboardProps['recent_activity'],
): ActivityPage {
    if (Array.isArray(input)) {
        return {
            data: input,
            current_page: 1,
            last_page: 1,
            per_page: Math.max(4, input.length),
            total: input.length,
        };
    }
    return {
        data: input?.data ?? [],
        current_page: input?.current_page ?? 1,
        last_page: Math.max(1, input?.last_page ?? 1),
        per_page: Math.max(4, input?.per_page ?? 4),
        total: input?.total ?? 0,
    };
}

const ACTIVITY_DOT: Record<string, string> = {
    teal: 'bg-teal-500',
    indigo: 'bg-indigo-500',
    emerald: 'bg-emerald-500',
    amber: 'bg-amber-500',
    red: 'bg-red-500',
    purple: 'bg-purple-500',
    blue: 'bg-blue-500',
    slate: 'bg-slate-500',
};

export default function AdminDashboard({
    stats,
    recent_activity,
    revenue_data,
    order_stats,
    seller_stats,
    chart_data,
    quick_actions,
    platform_health,
}: DashboardProps) {
    const [chartData, setChartData] = useState(chart_data ?? []);
    const [timeRange, setTimeRange] = useState<TimeRange>('month');
    const [chartLoading, setChartLoading] = useState(false);

    const initialActivity = useMemo(
        () => normalizeActivity(recent_activity),
        [recent_activity],
    );
    const [activityPage, setActivityPage] =
        useState<ActivityPage>(initialActivity);
    const [activityLoading, setActivityLoading] = useState(false);

    useEffect(() => {
        setActivityPage(normalizeActivity(recent_activity));
    }, [recent_activity]);

    const loadActivityPage = (page: number) => {
        if (page < 1 || page > activityPage.last_page || activityLoading) {
            return;
        }
        setActivityLoading(true);
        fetch(
            `/admin/activity?page=${page}&per_page=${activityPage.per_page || 4}`,
            {
                headers: {
                    Accept: 'application/json',
                    'X-Requested-With': 'XMLHttpRequest',
                },
            },
        )
            .then((r) => (r.ok ? r.json() : null))
            .then((json) => {
                if (!json) return;
                setActivityPage({
                    data: json.data ?? [],
                    current_page: json.meta?.current_page ?? page,
                    last_page: Math.max(1, json.meta?.last_page ?? 1),
                    per_page: json.meta?.per_page ?? 4,
                    total: json.meta?.total ?? 0,
                });
            })
            .catch(() => {
                /* keep current page */
            })
            .finally(() => setActivityLoading(false));
    };

    useEffect(() => {
        setChartData(chart_data ?? []);
    }, [chart_data]);

    useEffect(() => {
        // Initial prop data already matches "month" (30 days)
        if (timeRange === 'month' && (chart_data?.length ?? 0) > 0) {
            setChartData(chart_data);
            return;
        }

        let cancelled = false;
        setChartLoading(true);

        fetch(`/admin/charts?period=${encodeURIComponent(timeRange)}`, {
            headers: {
                Accept: 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
            },
        })
            .then((r) => (r.ok ? r.json() : null))
            .then((json) => {
                if (cancelled || !json?.data?.chart_data) return;
                setChartData(json.data.chart_data);
            })
            .catch(() => {
                /* keep previous series */
            })
            .finally(() => {
                if (!cancelled) setChartLoading(false);
            });

        return () => {
            cancelled = true;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [timeRange]);

    const chartSummary = useMemo(() => {
        const orders = chartData.reduce((s, d) => s + (d.orders || 0), 0);
        const revenue = chartData.reduce((s, d) => s + (d.revenue || 0), 0);
        const users = chartData.reduce((s, d) => s + (d.users || 0), 0);
        return { orders, revenue, users };
    }, [chartData]);

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Admin Dashboard | SiteDrop">
                <meta
                    name="description"
                    content="Admin overview and key metrics for managing the SiteDrop marketplace."
                />
            </Head>

            <div className="flex h-full flex-1 flex-col gap-6 p-4 md:p-6 lg:p-8">
                {/* Header */}
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">
                        Admin Overview
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Managing all operations across the SiteDrop marketplace
                        in Ghana & Africa
                    </p>
                </div>

                {/* Quick Stats Cards */}
                <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
                    <StatCard
                        title="Total Orders"
                        value={stats.total_orders.toLocaleString()}
                        change={`${order_stats.completed} completed`}
                        icon={ShoppingBag}
                        color="teal"
                    />
                    <StatCard
                        title="Total Users"
                        value={stats.total_users.toLocaleString()}
                        change={`${stats.total_sellers} sellers`}
                        icon={Users}
                        color="indigo"
                    />
                    <StatCard
                        title="Total Revenue"
                        value={`₵${Number(revenue_data.total_revenue || 0).toLocaleString()}`}
                        change={`₵${Number(revenue_data.today_revenue || 0).toLocaleString()} today`}
                        icon={DollarSign}
                        color="emerald"
                    />
                    <StatCard
                        title="Active Sellers"
                        value={seller_stats.approved.toString()}
                        change={`${seller_stats.pending_approval} pending approval`}
                        icon={Store}
                        color="amber"
                    />
                </div>

                {/* Main Content Grid */}
                <div className="grid gap-6 lg:grid-cols-12">
                    {/* Left Column */}
                    <div className="space-y-6 lg:col-span-8">
                        {/* Chart with Range Selector */}
                        <div className="rounded-2xl border bg-card p-6 shadow-sm">
                            <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                                <div>
                                    <h2 className="text-lg font-semibold">
                                        Platform Activity
                                    </h2>
                                    <p className="text-xs text-muted-foreground">
                                        {chartSummary.orders} orders · ₵
                                        {chartSummary.revenue.toLocaleString()}{' '}
                                        revenue · {chartSummary.users} new users
                                    </p>
                                </div>
                                <div className="flex flex-wrap gap-2">
                                    {(
                                        [
                                            'today',
                                            'week',
                                            'month',
                                            'quarter',
                                            'year',
                                        ] as const
                                    ).map((range) => (
                                        <button
                                            key={range}
                                            type="button"
                                            onClick={() => setTimeRange(range)}
                                            className={`rounded-xl px-3 py-1.5 text-sm font-medium transition-colors ${
                                                timeRange === range
                                                    ? 'bg-teal-600 text-white'
                                                    : 'bg-muted text-muted-foreground hover:bg-muted-foreground/10'
                                            }`}
                                        >
                                            {range.charAt(0).toUpperCase() +
                                                range.slice(1)}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div className="relative h-80 w-full">
                                {chartLoading && (
                                    <div className="absolute inset-0 z-10 flex items-center justify-center rounded-xl bg-background/50 text-sm text-muted-foreground">
                                        Loading chart…
                                    </div>
                                )}
                                {chartData.length === 0 ? (
                                    <div className="flex h-full items-center justify-center rounded-xl bg-muted/30 text-muted-foreground">
                                        <div className="text-center">
                                            <BarChart3 className="mx-auto mb-3 h-12 w-12 text-muted-foreground/50" />
                                            <p className="text-sm font-medium">
                                                No activity data yet
                                            </p>
                                        </div>
                                    </div>
                                ) : (
                                    <ResponsiveContainer
                                        width="100%"
                                        height="100%"
                                    >
                                        <AreaChart
                                            data={chartData}
                                            margin={{
                                                top: 10,
                                                right: 12,
                                                left: 0,
                                                bottom: 0,
                                            }}
                                        >
                                            <defs>
                                                <linearGradient
                                                    id="fillOrders"
                                                    x1="0"
                                                    y1="0"
                                                    x2="0"
                                                    y2="1"
                                                >
                                                    <stop
                                                        offset="5%"
                                                        stopColor="#0d9488"
                                                        stopOpacity={0.35}
                                                    />
                                                    <stop
                                                        offset="95%"
                                                        stopColor="#0d9488"
                                                        stopOpacity={0}
                                                    />
                                                </linearGradient>
                                                <linearGradient
                                                    id="fillRevenue"
                                                    x1="0"
                                                    y1="0"
                                                    x2="0"
                                                    y2="1"
                                                >
                                                    <stop
                                                        offset="5%"
                                                        stopColor="#6366f1"
                                                        stopOpacity={0.3}
                                                    />
                                                    <stop
                                                        offset="95%"
                                                        stopColor="#6366f1"
                                                        stopOpacity={0}
                                                    />
                                                </linearGradient>
                                            </defs>
                                            <CartesianGrid
                                                strokeDasharray="3 3"
                                                className="stroke-border/60"
                                                vertical={false}
                                            />
                                            <XAxis
                                                dataKey="label"
                                                tickLine={false}
                                                axisLine={false}
                                                tickMargin={8}
                                                minTickGap={24}
                                                className="fill-muted-foreground text-xs"
                                            />
                                            <YAxis
                                                yAxisId="left"
                                                tickLine={false}
                                                axisLine={false}
                                                width={40}
                                                className="fill-muted-foreground text-xs"
                                            />
                                            <YAxis
                                                yAxisId="right"
                                                orientation="right"
                                                tickLine={false}
                                                axisLine={false}
                                                width={48}
                                                className="fill-muted-foreground text-xs"
                                                tickFormatter={(v) =>
                                                    typeof v === 'number' &&
                                                    v >= 1000
                                                        ? `${(v / 1000).toFixed(1)}k`
                                                        : String(v)
                                                }
                                            />
                                            <Tooltip
                                                contentStyle={{
                                                    borderRadius: 12,
                                                    border: '1px solid hsl(var(--border))',
                                                    background:
                                                        'hsl(var(--card))',
                                                    color: 'hsl(var(--card-foreground))',
                                                    fontSize: 12,
                                                }}
                                                formatter={(value, name) => {
                                                    const n =
                                                        typeof value ===
                                                        'number'
                                                            ? value
                                                            : Number(
                                                                  value ?? 0,
                                                              );
                                                    if (name === 'revenue') {
                                                        return [
                                                            `₵${n.toLocaleString()}`,
                                                            'Revenue',
                                                        ];
                                                    }
                                                    if (name === 'orders') {
                                                        return [n, 'Orders'];
                                                    }
                                                    if (name === 'users') {
                                                        return [n, 'New users'];
                                                    }
                                                    return [n, String(name)];
                                                }}
                                                labelFormatter={(label) =>
                                                    String(label)
                                                }
                                            />
                                            <Legend />
                                            <Area
                                                yAxisId="left"
                                                type="monotone"
                                                dataKey="orders"
                                                name="Orders"
                                                stroke="#0d9488"
                                                fill="url(#fillOrders)"
                                                strokeWidth={2}
                                            />
                                            <Area
                                                yAxisId="right"
                                                type="monotone"
                                                dataKey="revenue"
                                                name="Revenue"
                                                stroke="#6366f1"
                                                fill="url(#fillRevenue)"
                                                strokeWidth={2}
                                            />
                                            <Area
                                                yAxisId="left"
                                                type="monotone"
                                                dataKey="users"
                                                name="Users"
                                                stroke="#f59e0b"
                                                fill="transparent"
                                                strokeWidth={2}
                                                strokeDasharray="4 4"
                                            />
                                        </AreaChart>
                                    </ResponsiveContainer>
                                )}
                            </div>
                        </div>

                        {/* Recent Activity — 4 per page with pagination */}
                        <div className="rounded-2xl border bg-card shadow-sm">
                            <div className="flex items-center justify-between border-b px-6 py-4">
                                <div>
                                    <h2 className="text-lg font-semibold">
                                        Recent Platform Activity
                                    </h2>
                                    <p className="text-xs text-muted-foreground">
                                        {activityPage.total} total ·{' '}
                                        {activityPage.per_page} per page
                                    </p>
                                </div>
                                <Link
                                    href="/admin/activity-logs"
                                    className="flex items-center gap-1 text-sm font-medium text-teal-600 hover:text-teal-700"
                                >
                                    View all{' '}
                                    <ArrowUpRight className="h-4 w-4" />
                                </Link>
                            </div>
                            <div
                                className={`relative divide-y ${activityLoading ? 'opacity-60' : ''}`}
                            >
                                {activityPage.data.length === 0 ? (
                                    <div className="px-6 py-10 text-center text-sm text-muted-foreground">
                                        No recent activity yet.
                                    </div>
                                ) : (
                                    activityPage.data.map((item, idx) => (
                                        <div
                                            key={
                                                item.id ??
                                                `${item.title}-${idx}`
                                            }
                                            className="flex items-start gap-4 px-6 py-4"
                                        >
                                            <div
                                                className={`mt-0.5 h-2 w-2 shrink-0 rounded-full ${
                                                    ACTIVITY_DOT[item.color] ??
                                                    ACTIVITY_DOT.teal
                                                }`}
                                            />
                                            <div className="min-w-0 flex-1">
                                                <p className="font-medium">
                                                    {item.title}
                                                </p>
                                                <p className="line-clamp-2 text-sm text-muted-foreground">
                                                    {item.subtitle}
                                                </p>
                                                {item.user && (
                                                    <p className="mt-0.5 text-xs text-muted-foreground">
                                                        by {item.user}
                                                    </p>
                                                )}
                                            </div>
                                            <p className="shrink-0 text-xs whitespace-nowrap text-muted-foreground">
                                                {item.time}
                                            </p>
                                        </div>
                                    ))
                                )}
                            </div>
                            {activityPage.last_page > 1 && (
                                <div className="flex items-center justify-between border-t px-6 py-3">
                                    <p className="text-xs text-muted-foreground">
                                        Page {activityPage.current_page} of{' '}
                                        {activityPage.last_page}
                                    </p>
                                    <div className="flex gap-2">
                                        <button
                                            type="button"
                                            disabled={
                                                activityPage.current_page <=
                                                    1 || activityLoading
                                            }
                                            onClick={() =>
                                                loadActivityPage(
                                                    activityPage.current_page -
                                                        1,
                                                )
                                            }
                                            className="rounded-lg border bg-background px-3 py-1.5 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-40"
                                        >
                                            Previous
                                        </button>
                                        <button
                                            type="button"
                                            disabled={
                                                activityPage.current_page >=
                                                    activityPage.last_page ||
                                                activityLoading
                                            }
                                            onClick={() =>
                                                loadActivityPage(
                                                    activityPage.current_page +
                                                        1,
                                                )
                                            }
                                            className="rounded-lg border bg-background px-3 py-1.5 text-sm font-medium transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-40"
                                        >
                                            Next
                                        </button>
                                    </div>
                                </div>
                            )}
                            {activityPage.last_page <= 1 &&
                                activityPage.total > 0 && (
                                    <div className="border-t px-6 py-2 text-center text-xs text-muted-foreground">
                                        Showing all {activityPage.total} recent
                                        items
                                    </div>
                                )}
                        </div>
                    </div>

                    {/* Right Column */}
                    <div className="space-y-6 lg:col-span-4">
                        {/* Quick Actions (area routes) */}
                        <div className="rounded-2xl border bg-card p-6 shadow-sm">
                            <h2 className="mb-4 text-lg font-semibold">
                                Quick Actions
                            </h2>
                            <div className="grid grid-cols-2 gap-4">
                                {quick_actions.map((action, idx) => {
                                    const IconComponent = getIcon(action.icon);
                                    return (
                                        <Link
                                            key={idx}
                                            href={action.href}
                                            prefetch
                                            className="flex flex-col items-center gap-2 rounded-xl border bg-background p-4 text-center transition-colors hover:border-primary/30 hover:bg-muted"
                                        >
                                            {IconComponent && (
                                                <IconComponent className="h-6 w-6 text-primary" />
                                            )}
                                            <span className="text-sm font-medium">
                                                {action.label}
                                            </span>
                                        </Link>
                                    );
                                })}
                            </div>
                        </div>

                        {/* Platform Health */}
                        <div className="rounded-2xl border bg-card p-6 shadow-sm">
                            <h2 className="mb-4 text-lg font-semibold">
                                Platform Health
                            </h2>
                            <div className="space-y-4">
                                <HealthItem
                                    label="Active Users"
                                    value={`${platform_health.active_users.value} / ${platform_health.active_users.total}`}
                                    status="good"
                                />
                                <HealthItem
                                    label="Active Sellers"
                                    value={`${platform_health.active_sellers.value} / ${platform_health.active_sellers.total}`}
                                    status={
                                        platform_health.active_sellers
                                            .percentage > 50
                                            ? 'good'
                                            : 'warning'
                                    }
                                />
                                <HealthItem
                                    label="Order Completion Rate"
                                    value={`${platform_health.order_completion_rate.percentage}%`}
                                    status={
                                        platform_health.order_completion_rate
                                            .percentage > 70
                                            ? 'good'
                                            : 'warning'
                                    }
                                />
                                <HealthItem
                                    label="System Uptime"
                                    value={platform_health.system_uptime}
                                    status="good"
                                />
                                <HealthItem
                                    label="Last Backup"
                                    value={platform_health.last_backup}
                                    status="info"
                                />
                            </div>
                        </div>

                        {/* Order Status Summary */}
                        <div className="rounded-2xl border bg-card p-6 shadow-sm">
                            <h2 className="mb-4 text-lg font-semibold">
                                Order Status
                            </h2>
                            <div className="space-y-3">
                                <StatusItem
                                    label="Pending"
                                    value={order_stats.pending}
                                    color="amber"
                                />
                                <StatusItem
                                    label="Processing"
                                    value={order_stats.processing}
                                    color="indigo"
                                />
                                <StatusItem
                                    label="In Transit"
                                    value={order_stats.in_transit}
                                    color="teal"
                                />
                                <StatusItem
                                    label="Completed"
                                    value={order_stats.completed}
                                    color="emerald"
                                />
                                <StatusItem
                                    label="Cancelled"
                                    value={order_stats.cancelled}
                                    color="red"
                                />
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </AppLayout>
    );
}

// ====================== Reusable Components (identical to SuperAdmin.tsx) ======================
function StatCard({
    title,
    value,
    change,
    icon: Icon,
    color,
}: {
    title: string;
    value: string;
    change: string;
    icon: React.ComponentType<React.SVGProps<SVGSVGElement>>;
    color: 'teal' | 'indigo' | 'emerald' | 'amber' | 'purple' | 'blue' | 'red';
}) {
    const colorMap = {
        teal: 'text-teal-600 bg-teal-50 dark:bg-teal-950/30',
        indigo: 'text-indigo-600 bg-indigo-50 dark:bg-indigo-950/30',
        emerald: 'text-emerald-600 bg-emerald-50 dark:bg-emerald-950/30',
        amber: 'text-amber-600 bg-amber-50 dark:bg-amber-950/30',
        purple: 'text-purple-600 bg-purple-50 dark:bg-purple-950/30',
        blue: 'text-blue-600 bg-blue-50 dark:bg-blue-950/30',
        red: 'text-red-600 bg-red-50 dark:bg-red-950/30',
    };
    return (
        <div className="rounded-2xl border bg-card p-6 shadow-sm">
            <div className="flex items-center justify-between">
                <div>
                    <p className="text-sm text-muted-foreground">{title}</p>
                    <p className="mt-2 text-2xl font-bold">{value}</p>
                </div>
                <div className={`rounded-lg p-3 ${colorMap[color]}`}>
                    <Icon className="h-6 w-6" />
                </div>
            </div>
            <p className="mt-4 text-sm font-medium text-emerald-600">
                {change}
            </p>
        </div>
    );
}

function HealthItem({
    label,
    value,
    status,
}: {
    label: string;
    value: string;
    status: 'good' | 'warning' | 'info' | 'danger';
}) {
    const statusMap = {
        good: 'text-emerald-600',
        warning: 'text-amber-600',
        info: 'text-indigo-600',
        danger: 'text-red-600',
    };
    return (
        <div className="flex justify-between text-sm">
            <span className="text-muted-foreground">{label}</span>
            <span className={`font-medium ${statusMap[status]}`}>{value}</span>
        </div>
    );
}

function StatusItem({
    label,
    value,
    color,
}: {
    label: string;
    value: number;
    color: string;
}) {
    const colorMap = {
        amber: 'bg-amber-500',
        indigo: 'bg-indigo-500',
        teal: 'bg-teal-500',
        emerald: 'bg-emerald-500',
        red: 'bg-red-500',
    };
    return (
        <div className="flex items-center gap-3">
            <div
                className={`h-2 w-2 rounded-full ${colorMap[color as keyof typeof colorMap]}`}
            />
            <span className="flex-1 text-sm">{label}</span>
            <span className="text-sm font-medium">{value}</span>
        </div>
    );
}

function getIcon(
    iconName: string,
): React.ComponentType<React.SVGProps<SVGSVGElement>> | null {
    const icons: Record<
        string,
        React.ComponentType<React.SVGProps<SVGSVGElement>>
    > = {
        Users,
        Store,
        ShoppingBag,
        Package,
        Truck,
        MapPin,
        DollarSign,
        BarChart3,
        Settings,
        Activity,
        ArrowUpRight,
        TrendingUp,
        TrendingDown,
    };
    return icons[iconName] || null;
}
