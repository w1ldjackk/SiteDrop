// resources/js/pages/backend/SystemSettings/index.tsx
import { Head, useForm } from '@inertiajs/react';
import {
    Bell,
    CheckCircle2,
    Eye,
    EyeOff,
    Flame,
    MapPin,
    Save,
    Settings2,
    Shield,
    Sparkles,
} from 'lucide-react';
import {
    useEffect,
    useMemo,
    useState,
    type FormEvent,
    type ReactNode,
} from 'react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { Switch } from '@/components/ui/switch';
import AppLayout from '@/layouts/app-layout';
import { cn } from '@/lib/utils';
import type { BreadcrumbItem } from '@/types';

type SettingType = 'string' | 'boolean' | 'float' | 'integer' | 'json' | string;

interface SettingRow {
    name: string;
    label: string;
    type: SettingType;
    val: string | number | boolean | null;
    group?: string;
}

interface IntegrationStatus {
    overall: 'ok' | 'partial' | 'missing' | string;
    notes?: string[];
    [key: string]: unknown;
}

interface Props {
    settings: SettingRow[];
    integrations?: {
        firebase?: IntegrationStatus & {
            project_id?: string;
            client_configured?: boolean;
            web_configured?: boolean;
            android_configured?: boolean;
            ios_configured?: boolean;
            vapid_public_set?: boolean;
            server_push_configured?: boolean;
            server_http_v1?: boolean;
            server_legacy?: boolean;
            credentials_readable?: boolean;
            devices_with_token?: number;
        };
        maps?: IntegrationStatus & {
            configured?: boolean;
        };
    };
}

type TabId = 'general' | 'platform' | 'firebase' | 'maps' | 'notifications' | 'other';

interface TabDef {
    id: TabId;
    label: string;
    description: string;
    icon: typeof Settings2;
    match: (s: SettingRow) => boolean;
}

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'System Settings', href: '/admin/system-settings' },
];

const TABS: TabDef[] = [
    {
        id: 'general',
        label: 'General',
        description: 'Branding, support contacts, and commerce defaults',
        icon: Sparkles,
        match: (s) =>
            s.group === 'general' ||
            [
                'app_name',
                'support_email',
                'support_phone',
                'currency',
                'commission_rate',
                'default_theme_mode',
            ].includes(s.name),
    },
    {
        id: 'notifications',
        label: 'Notifications',
        description: 'Default channels (in-app, email, push to app, SMS)',
        icon: Bell,
        match: (s) =>
            s.group === 'notifications' ||
            s.name.startsWith('notification_'),
    },
    {
        id: 'platform',
        label: 'Platform',
        description: 'Access control and channel toggles',
        icon: Shield,
        match: (s) =>
            s.group === 'platform' ||
            [
                'maintenance_mode',
                'allow_registration',
                'sms_enabled',
                'email_enabled',
            ].includes(s.name),
    },
    {
        id: 'firebase',
        label: 'Firebase',
        description: 'Client Firebase / FCM options for mobile apps',
        icon: Flame,
        match: (s) =>
            s.group === 'firebase' ||
            s.group === 'firebase_core' ||
            s.group === 'firebase_android' ||
            s.group === 'firebase_ios' ||
            s.group === 'firebase_web' ||
            s.name.startsWith('firebase_'),
    },
    {
        id: 'maps',
        label: 'Maps',
        description: 'Google Maps keys used by the mobile address map',
        icon: MapPin,
        match: (s) =>
            s.group === 'maps' ||
            s.name === 'google_maps_api_key' ||
            s.name.startsWith('google_maps_'),
    },
    {
        id: 'other',
        label: 'Other',
        description: 'Extra or custom system keys',
        icon: Settings2,
        match: () => false, // filled by leftover keys
    },
];

function inferGroup(s: SettingRow): TabId {
    for (const tab of TABS) {
        if (tab.id === 'other') continue;
        if (tab.match(s)) return tab.id;
    }
    return 'other';
}

function firebaseSubgroup(name: string): string {
    if (name.startsWith('firebase_android_')) return 'Android';
    if (name.startsWith('firebase_ios_')) return 'iOS';
    if (name.startsWith('firebase_web_')) return 'Web';
    return 'Core';
}

function StatusPill({
    ok,
    label,
}: {
    ok: boolean | undefined;
    label: string;
}) {
    return (
        <div className="flex items-center justify-between gap-2 rounded-lg border bg-background/60 px-3 py-2">
            <span className="text-xs text-muted-foreground">{label}</span>
            <Badge
                variant={ok ? 'default' : 'secondary'}
                className={cn(
                    'text-[10px]',
                    ok
                        ? 'bg-emerald-600 hover:bg-emerald-600'
                        : 'text-amber-700 dark:text-amber-400',
                )}
            >
                {ok ? 'OK' : 'Missing'}
            </Badge>
        </div>
    );
}

export default function SystemSettingsIndex({
    settings,
    integrations,
}: Props) {
    const [activeTab, setActiveTab] = useState<TabId>('general');
    const [visiblePasswords, setVisiblePasswords] = useState<Set<string>>(
        new Set(),
    );
    const firebaseHealth = integrations?.firebase;
    const mapsHealth = integrations?.maps;

    const initial: Record<string, string | number | boolean> = {};
    settings.forEach((s) => {
        if (s.type === 'boolean' || typeof s.val === 'boolean') {
            initial[s.name] =
                s.val === true ||
                s.val === 1 ||
                s.val === '1' ||
                s.val === 'true';
            return;
        }
        initial[s.name] =
            s.val === null || s.val === undefined
                ? ''
                : (s.val as string | number | boolean);
    });

    const { data, setData, put, processing, recentlySuccessful } = useForm<{
        settings: Record<string, string | number | boolean>;
    }>({
        settings: initial,
    });

    const isDirty = useMemo(() => {
        return settings.some((s) => {
            const current = data.settings[s.name];
            const original =
                s.val === null || s.val === undefined
                    ? s.type === 'boolean'
                        ? false
                        : ''
                    : s.val;
            return String(current) !== String(original);
        });
    }, [data.settings, settings]);

    const grouped = useMemo(() => {
        const map: Record<TabId, SettingRow[]> = {
            general: [],
            platform: [],
            firebase: [],
            maps: [],
            notifications: [],
            other: [],
        };
        for (const s of settings) {
            map[inferGroup(s)].push(s);
        }
        return map;
    }, [settings]);

    const tabsWithCounts = TABS.map((tab) => ({
        ...tab,
        count: grouped[tab.id]?.length ?? 0,
    })).filter((tab) => tab.id !== 'other' || tab.count > 0);

    const activeSettings = grouped[activeTab] ?? [];
    const ActiveIcon = TABS.find((t) => t.id === activeTab)?.icon ?? Settings2;
    const activeMeta = TABS.find((t) => t.id === activeTab);

    const setValue = (name: string, value: string | number | boolean) => {
        setData('settings', {
            ...data.settings,
            [name]: value,
        });
    };

    // Ensure notification preference keys exist in form data (for the notifications tab).
    // Runs once on mount.
    useEffect(() => {
        const notificationKeys = [
            'notification_in_app_enabled',
            'notification_email_enabled',
            'notification_push_enabled',
            'notification_sms_enabled',
        ];
        let needsUpdate = false;
        const newSettings = { ...data.settings };

        notificationKeys.forEach((key) => {
            if (newSettings[key] === undefined) {
                // Default: in_app and email on
                const defaultVal =
                    key.includes('in_app') || key.includes('email');
                newSettings[key] = defaultVal;
                needsUpdate = true;
            }
        });

        if (needsUpdate) {
            setData('settings', newSettings);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- defaults only on mount
    }, []);


    const togglePasswordVisibility = (name: string) => {
        const newSet = new Set(visiblePasswords);
        if (newSet.has(name)) {
            newSet.delete(name);
        } else {
            newSet.add(name);
        }
        setVisiblePasswords(newSet);
    };

    const submit = (e: FormEvent) => {
        e.preventDefault();
        put('/admin/system-settings', { preserveScroll: true });
    };

    const isBooleanSetting = (setting: SettingRow) => {
        if (setting.type === 'boolean') return true;
        // Fallbacks if type is missing/wrong from DB extras
        if (typeof setting.val === 'boolean') return true;
        if (
            typeof setting.val === 'string' &&
            ['true', 'false', '1', '0', 'yes', 'no'].includes(
                setting.val.toLowerCase(),
            )
        ) {
            return (
                setting.name.endsWith('_mode') ||
                setting.name.endsWith('_enabled') ||
                setting.name.startsWith('allow_') ||
                setting.name.startsWith('is_') ||
                setting.name.includes('maintenance')
            );
        }
        return false;
    };

    const asBool = (value: unknown): boolean => {
        if (typeof value === 'boolean') return value;
        if (typeof value === 'number') return value !== 0;
        if (typeof value === 'string') {
            const v = value.toLowerCase().trim();
            return v === '1' || v === 'true' || v === 'yes' || v === 'on';
        }
        return Boolean(value);
    };

    const renderField = (setting: SettingRow) => {
        const value = data.settings[setting.name];
        const isSecret =
            setting.name.includes('api_key') ||
            setting.name.includes('secret') ||
            setting.name.includes('client_id');

        if (isBooleanSetting(setting)) {
            const on = asBool(value);
            return (
                <div
                    key={setting.name}
                    className="flex items-center justify-between gap-4 rounded-xl border bg-card/40 p-4 transition-colors hover:bg-muted/40"
                >
                    <div className="min-w-0 space-y-1">
                        <div className="text-sm leading-none font-medium">
                            {setting.label}
                        </div>
                        <p className="truncate font-mono text-[11px] text-muted-foreground">
                            {setting.name}
                        </p>
                    </div>
                    <div className="flex shrink-0 items-center gap-3">
                        <span
                            className={cn(
                                'text-xs font-medium tabular-nums',
                                on ? 'text-primary' : 'text-muted-foreground',
                            )}
                        >
                            {on ? 'On' : 'Off'}
                        </span>
                        <Switch
                            id={`switch-${setting.name}`}
                            size="lg"
                            checked={on}
                            onCheckedChange={(checked) =>
                                setValue(setting.name, checked)
                            }
                            aria-label={setting.label}
                        />
                    </div>
                </div>
            );
        }

        return (
            <div
                key={setting.name}
                className="space-y-2 rounded-xl border bg-card/40 p-4 transition-colors hover:bg-muted/30"
            >
                <div className="flex items-start justify-between gap-2">
                    <Label
                        htmlFor={setting.name}
                        className="text-sm font-medium"
                    >
                        {setting.label}
                    </Label>
                    {isSecret && (
                        <Badge variant="secondary" className="text-[10px]">
                            Sensitive
                        </Badge>
                    )}
                </div>
                <div className="relative">
                    <Input
                        id={setting.name}
                        type={
                            isSecret && !visiblePasswords.has(setting.name)
                                ? 'password'
                                : setting.type === 'float' ||
                                    setting.type === 'integer'
                                  ? 'number'
                                  : 'text'
                        }
                        autoComplete="off"
                        spellCheck={false}
                        value={
                            value === null || value === undefined
                                ? ''
                                : String(value)
                        }
                        onChange={(e) => {
                            const raw = e.target.value;
                            if (
                                setting.type === 'float' ||
                                setting.type === 'integer'
                            ) {
                                setValue(setting.name, raw);
                            } else {
                                setValue(setting.name, raw);
                            }
                        }}
                        className={cn('font-mono text-sm', isSecret && 'pr-10')}
                        placeholder={
                            isSecret ? '••••••••' : `Enter ${setting.label}`
                        }
                    />
                    {isSecret && (
                        <button
                            type="button"
                            onClick={() =>
                                togglePasswordVisibility(setting.name)
                            }
                            className="absolute top-1/2 right-3 -translate-y-1/2 text-muted-foreground transition-colors hover:text-foreground"
                            aria-label={
                                visiblePasswords.has(setting.name)
                                    ? 'Hide password'
                                    : 'Show password'
                            }
                        >
                            {visiblePasswords.has(setting.name) ? (
                                <EyeOff className="h-4 w-4" />
                            ) : (
                                <Eye className="h-4 w-4" />
                            )}
                        </button>
                    )}
                </div>
                <p className="font-mono text-[11px] text-muted-foreground">
                    {setting.name}
                </p>
            </div>
        );
    };

    const renderFirebaseHealth = () => {
        if (!firebaseHealth) return null;
        const overall = firebaseHealth.overall ?? 'missing';
        const overallLabel =
            overall === 'ok'
                ? 'Working'
                : overall === 'partial'
                  ? 'Partial'
                  : 'Not ready';
        const overallClass =
            overall === 'ok'
                ? 'bg-emerald-600 hover:bg-emerald-600'
                : overall === 'partial'
                  ? 'bg-amber-500 hover:bg-amber-500'
                  : 'bg-destructive hover:bg-destructive';

        return (
            <Card className="border-primary/20 bg-primary/5">
                <CardHeader className="pb-3">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                        <div>
                            <CardTitle className="text-base">
                                Firebase / FCM health
                            </CardTitle>
                            <CardDescription>
                                Live status for client keys + server push
                                (service account). Secrets are never shown.
                            </CardDescription>
                        </div>
                        <Badge className={cn('text-xs', overallClass)}>
                            {overallLabel}
                        </Badge>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <div className="grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                        <StatusPill
                            ok={firebaseHealth.client_configured}
                            label="Client keys (mobile/web)"
                        />
                        <StatusPill
                            ok={firebaseHealth.web_configured}
                            label="Web client"
                        />
                        <StatusPill
                            ok={firebaseHealth.android_configured}
                            label="Android client"
                        />
                        <StatusPill
                            ok={firebaseHealth.ios_configured}
                            label="iOS client"
                        />
                        <StatusPill
                            ok={firebaseHealth.vapid_public_set}
                            label="VAPID public (web push)"
                        />
                        <StatusPill
                            ok={firebaseHealth.server_push_configured}
                            label="Server push (HTTP v1 / legacy)"
                        />
                        <StatusPill
                            ok={firebaseHealth.server_http_v1}
                            label="HTTP v1 service account"
                        />
                        <StatusPill
                            ok={firebaseHealth.credentials_readable}
                            label="Credentials file readable"
                        />
                        <StatusPill
                            ok={(firebaseHealth.devices_with_token ?? 0) > 0}
                            label={`Devices with token (${firebaseHealth.devices_with_token ?? 0})`}
                        />
                    </div>
                    <div className="rounded-lg border bg-background/70 px-3 py-2 font-mono text-xs text-muted-foreground">
                        project_id:{' '}
                        <span className="text-foreground">
                            {String(firebaseHealth.project_id ?? '—')}
                        </span>
                        {firebaseHealth.server_http_v1
                            ? ' · transport: HTTP v1'
                            : firebaseHealth.server_legacy
                              ? ' · transport: legacy'
                              : ''}
                    </div>
                    {(firebaseHealth.notes?.length ?? 0) > 0 && (
                        <ul className="list-inside list-disc space-y-1 text-xs text-amber-800 dark:text-amber-300">
                            {firebaseHealth.notes!.map((note) => (
                                <li key={note}>{note}</li>
                            ))}
                        </ul>
                    )}
                    <p className="text-[11px] text-muted-foreground">
                        CLI: <code className="rounded bg-muted px-1">php artisan fcm:status</code>
                        {' · '}
                        test:{' '}
                        <code className="rounded bg-muted px-1">
                            php artisan fcm:status --test-user=5
                        </code>
                    </p>
                </CardContent>
            </Card>
        );
    };

    const renderFirebaseSections = () => {
        const sections: Record<string, SettingRow[]> = {
            Core: [],
            Android: [],
            iOS: [],
            Web: [],
        };
        for (const s of activeSettings) {
            sections[firebaseSubgroup(s.name)].push(s);
        }

        return (
            <div className="space-y-6">
                {renderFirebaseHealth()}
                {Object.entries(sections).map(([title, rows]) => {
                    if (rows.length === 0) return null;
                    return (
                        <div key={title} className="space-y-3">
                            <div className="flex items-center gap-2">
                                <h3 className="text-sm font-semibold tracking-tight">
                                    {title}
                                </h3>
                                <Badge
                                    variant="outline"
                                    className="text-[10px]"
                                >
                                    {rows.length}
                                </Badge>
                            </div>
                            <div className="grid gap-3 md:grid-cols-2">
                                {rows.map(renderField)}
                            </div>
                        </div>
                    );
                })}
            </div>
        );
    };

    let body: ReactNode;
    if (activeTab === 'notifications') {
        const channelMeta: Record<
            string,
            { title: string; hint: string; defaultOn: boolean }
        > = {
            in_app: {
                title: 'In-app',
                hint: 'Bell / notifications list inside web & mobile',
                defaultOn: true,
            },
            email: {
                title: 'Email',
                hint: 'Send to the user email address',
                defaultOn: true,
            },
            push: {
                title: 'Push (to app)',
                hint: 'FCM → phone / browser when device token is registered',
                defaultOn: true,
            },
            sms: {
                title: 'SMS',
                hint: 'Text message (provider not wired yet)',
                defaultOn: false,
            },
        };

        body = (
            <div className="space-y-4">
                <Card>
                    <CardHeader>
                        <CardTitle>Default Notification Channels</CardTitle>
                        <CardDescription>
                            These defaults apply when a user has not set their
                            own channels. <strong>Push</strong> delivers to the
                            installed app / web browser via FCM (needs token +
                            Firebase server credentials).
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="grid gap-4 md:grid-cols-2">
                        {(['in_app', 'email', 'push', 'sms'] as const).map(
                            (channel) => {
                                const key = `notification_${channel}_enabled`;
                                const meta = channelMeta[channel];
                                const checked =
                                    data.settings[key] !== undefined
                                        ? asBool(data.settings[key])
                                        : meta.defaultOn;
                                return (
                                    <div
                                        key={channel}
                                        className="flex items-center justify-between rounded-xl border p-3"
                                    >
                                        <div>
                                            <div className="font-medium">
                                                {meta.title}
                                            </div>
                                            <div className="text-xs text-muted-foreground">
                                                {meta.hint}
                                            </div>
                                            <div className="mt-1 font-mono text-[10px] text-muted-foreground">
                                                {key}
                                            </div>
                                        </div>
                                        <Switch
                                            checked={checked}
                                            onCheckedChange={(on) =>
                                                setValue(key, on)
                                            }
                                        />
                                    </div>
                                );
                            },
                        )}
                    </CardContent>
                </Card>
                <p className="text-xs text-muted-foreground">
                    Users can override channels in profile preferences. CLI test
                    push:{' '}
                    <code className="rounded bg-muted px-1">
                        php artisan fcm:status --test-user=5
                    </code>
                    . Order events also create in-app + push when enabled.
                </p>
                {activeSettings.length > 0 && (
                    <div className="grid gap-3 md:grid-cols-2">
                        {activeSettings
                            .filter(
                                (s) =>
                                    !s.name.startsWith('notification_') ||
                                    !s.name.endsWith('_enabled'),
                            )
                            .map(renderField)}
                    </div>
                )}
            </div>
        );
    } else if (activeTab === 'firebase') {
        body = renderFirebaseSections();
    } else if (activeSettings.length === 0) {
        body = (
            <div className="flex flex-col items-center justify-center gap-2 py-16 text-center text-muted-foreground">
                <Settings2 className="h-10 w-10 opacity-40" />
                <p className="text-sm">No settings in this group.</p>
            </div>
        );
    } else if (activeTab === 'maps') {
        body = (
            <div className="space-y-6">
                {mapsHealth && (
                    <Card className="border-primary/20 bg-primary/5">
                        <CardHeader className="pb-3">
                            <div className="flex items-center justify-between gap-2">
                                <CardTitle className="text-base">
                                    Google Maps health
                                </CardTitle>
                                <Badge
                                    className={cn(
                                        'text-xs',
                                        mapsHealth.configured
                                            ? 'bg-emerald-600 hover:bg-emerald-600'
                                            : 'bg-amber-500 hover:bg-amber-500',
                                    )}
                                >
                                    {mapsHealth.configured
                                        ? 'Working'
                                        : 'Not set'}
                                </Badge>
                            </div>
                            <CardDescription>
                                Used by mobile/web address pin map (
                                <code>GOOGLE_MAPS_API_KEY</code> / this form).
                            </CardDescription>
                        </CardHeader>
                        {(mapsHealth.notes?.length ?? 0) > 0 && (
                            <CardContent>
                                <ul className="list-inside list-disc space-y-1 text-xs text-amber-800 dark:text-amber-300">
                                    {mapsHealth.notes!.map((n) => (
                                        <li key={n}>{n}</li>
                                    ))}
                                </ul>
                            </CardContent>
                        )}
                    </Card>
                )}
                <div className="grid gap-3 md:grid-cols-2">
                    {activeSettings.map(renderField)}
                </div>
            </div>
        );
    } else {
        body = (
            <div className="grid gap-3 md:grid-cols-2">
                {activeSettings.map(renderField)}
            </div>
        );
    }

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="System Settings | SiteDrop Admin">
                <meta name="description" content="Configure platform settings, fees, support contacts and integrations." />
            </Head>
            <form
                onSubmit={submit}
                className="mx-auto max-w-6xl space-y-6 p-4 md:p-6 lg:p-8"
            >
                {/* Header */}
                <div className="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
                    <div className="space-y-1">
                        <div className="flex items-center gap-2">
                            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
                                <Settings2 className="h-5 w-5" />
                            </div>
                            <div>
                                <h1 className="text-2xl font-bold tracking-tight">
                                    System Settings
                                </h1>
                                <p className="text-sm text-muted-foreground">
                                    Platform-wide configuration for web &amp;
                                    mobile clients
                                </p>
                            </div>
                        </div>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                        {isDirty && (
                            <Badge variant="outline" className="text-amber-600">
                                Unsaved changes
                            </Badge>
                        )}
                        {recentlySuccessful && (
                            <span className="inline-flex items-center gap-1 text-sm text-emerald-600">
                                <CheckCircle2 className="h-4 w-4" />
                                Saved
                            </span>
                        )}
                        <Button type="submit" disabled={processing}>
                            <Save className="mr-1.5 h-4 w-4" />
                            {processing ? 'Saving…' : 'Save settings'}
                        </Button>
                    </div>
                </div>

                {/* Tabs */}
                <div className="overflow-x-auto">
                    <div
                        role="tablist"
                        className="inline-flex min-w-full gap-1 rounded-xl border bg-muted/50 p-1 sm:min-w-0"
                    >
                        {tabsWithCounts.map((tab) => {
                            const Icon = tab.icon;
                            const active = activeTab === tab.id;
                            return (
                                <button
                                    key={tab.id}
                                    type="button"
                                    role="tab"
                                    aria-selected={active}
                                    onClick={() => setActiveTab(tab.id)}
                                    className={cn(
                                        'inline-flex shrink-0 items-center gap-2 rounded-lg px-3.5 py-2 text-sm font-medium transition-all',
                                        active
                                            ? 'bg-background text-foreground shadow-sm'
                                            : 'text-muted-foreground hover:bg-background/60 hover:text-foreground',
                                    )}
                                >
                                    <Icon className="h-4 w-4" />
                                    <span>{tab.label}</span>
                                    {tab.id !== 'notifications' && (
                                        <Badge
                                            variant={
                                                active ? 'default' : 'secondary'
                                            }
                                            className="h-5 min-w-5 justify-center px-1.5 text-[10px]"
                                        >
                                            {tab.count}
                                        </Badge>
                                    )}
                                </button>
                            );
                        })}
                    </div>
                </div>

                {/* Content card */}
                <Card className="overflow-hidden border-border/80 shadow-sm">
                    <CardHeader className="border-b bg-muted/20">
                        <div className="flex items-start gap-3">
                            <div className="mt-0.5 flex h-9 w-9 items-center justify-center rounded-lg bg-primary/10 text-primary">
                                <ActiveIcon className="h-4 w-4" />
                            </div>
                            <div className="space-y-1">
                                <CardTitle className="text-lg">
                                    {activeMeta?.label}
                                </CardTitle>
                                <CardDescription>
                                    {activeMeta?.description}
                                </CardDescription>
                            </div>
                        </div>
                    </CardHeader>
                    <CardContent className="p-5 md:p-6">{body}</CardContent>
                    <Separator />
                    <CardFooter className="flex flex-col gap-3 bg-muted/10 py-4 sm:flex-row sm:items-center sm:justify-between">
                        <p className="text-xs text-muted-foreground">
                            Public keys (including Maps &amp; Firebase client
                            options) are served to mobile via{' '}
                            <code className="rounded bg-muted px-1 py-0.5 text-[11px]">
                                GET /api/v1/config
                            </code>
                            . Never store FCM server secrets here.
                        </p>
                        <div className="flex items-center gap-2 self-end sm:self-auto">
                            {activeTab === 'platform' && (
                                <span className="hidden items-center gap-1 text-xs text-muted-foreground sm:inline-flex">
                                    <Bell className="h-3.5 w-3.5" />
                                    Channel flags
                                </span>
                            )}
                            <Button
                                type="submit"
                                size="sm"
                                disabled={processing}
                            >
                                <Save className="mr-1.5 h-3.5 w-3.5" />
                                {processing ? 'Saving…' : 'Save'}
                            </Button>
                        </div>
                    </CardFooter>
                </Card>
            </form>
        </AppLayout>
    );
}
