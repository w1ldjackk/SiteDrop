import { Link, router, usePage } from '@inertiajs/react';
import { Bell, MessageCircle, Search, X } from 'lucide-react';
import * as React from 'react';
import { Breadcrumbs } from '@/components/breadcrumbs';
import { Button } from '@/components/ui/button';
import {
    DropdownMenu,
    DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Input } from '@/components/ui/input';
import { SidebarTrigger } from '@/components/ui/sidebar';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem as BreadcrumbItemType, SharedData } from '@/types';

interface AppSidebarHeaderProps {
    breadcrumbs?: BreadcrumbItemType[];
}

interface NotificationItem {
    id: number;
    title: string;
    body: string;
    type: string;
    action_url?: string | null;
    read_at?: string | null;
    created_at: string;
    time_ago: string;
    is_read: boolean;
    priority: string;
}

type NotificationsShared = {
    recent?: NotificationItem[];
    recent_messages?: NotificationItem[];
    unread_count?: number;
    unread_messages_count?: number;
};

function isMessageType(type: string | undefined): boolean {
    return (type ?? '').toLowerCase() === 'message';
}

function badgeLabel(count: number): string {
    return count > 99 ? '99+' : String(count);
}

export function AppSidebarHeader({
    breadcrumbs = [],
}: AppSidebarHeaderProps) {
    const page = usePage<SharedData>();
    const notificationsData = page.props.notifications as
        | NotificationsShared
        | undefined;
    const { path, isAdminArea } = useRoleArea();

    const [searchQuery, setSearchQuery] = React.useState('');
    const [showSearch, setShowSearch] = React.useState(false);

    const [localNotifications, setLocalNotifications] = React.useState<
        NotificationItem[]
    >(notificationsData?.recent ?? []);
    const [localMessages, setLocalMessages] = React.useState<NotificationItem[]>(
        notificationsData?.recent_messages ?? [],
    );
    const [unreadAlerts, setUnreadAlerts] = React.useState<number>(
        notificationsData?.unread_count ?? 0,
    );
    const [unreadMessages, setUnreadMessages] = React.useState<number>(
        notificationsData?.unread_messages_count ?? 0,
    );

    React.useEffect(() => {
        if (!notificationsData) return;
        setLocalNotifications(notificationsData.recent ?? []);
        setLocalMessages(notificationsData.recent_messages ?? []);
        setUnreadAlerts(notificationsData.unread_count ?? 0);
        setUnreadMessages(notificationsData.unread_messages_count ?? 0);
    }, [notificationsData]);

    // Poll every 45s for fresh counts + latest 3 of each
    React.useEffect(() => {
        const recentUrl = path('notifications', 'recent');

        const pollNotifications = async () => {
            try {
                const response = await fetch(recentUrl, {
                    headers: {
                        Accept: 'application/json',
                        'X-Requested-With': 'XMLHttpRequest',
                    },
                });
                if (!response.ok) return;
                const data = await response.json();
                if (Array.isArray(data.notifications)) {
                    setLocalNotifications(data.notifications.slice(0, 3));
                }
                if (Array.isArray(data.messages)) {
                    setLocalMessages(data.messages.slice(0, 3));
                }
                if (typeof data.unread_count === 'number') {
                    setUnreadAlerts(data.unread_count);
                }
                if (typeof data.unread_messages_count === 'number') {
                    setUnreadMessages(data.unread_messages_count);
                }
            } catch (error) {
                console.debug('Notification polling failed:', error);
            }
        };

        const interval = setInterval(pollNotifications, 45000);
        return () => clearInterval(interval);
    }, [path]);

    const handleSearch = (e: React.FormEvent) => {
        e.preventDefault();
        if (searchQuery.trim()) {
            setSearchQuery('');
            setShowSearch(false);
        }
    };

    const markAsRead = (item: NotificationItem) => {
        if (item.is_read) return;

        const message = isMessageType(item.type);

        if (message) {
            setLocalMessages((prev) =>
                prev.map((n) =>
                    n.id === item.id ? { ...n, is_read: true } : n,
                ),
            );
            setUnreadMessages((prev) => Math.max(0, prev - 1));
        } else {
            setLocalNotifications((prev) =>
                prev.map((n) =>
                    n.id === item.id ? { ...n, is_read: true } : n,
                ),
            );
            setUnreadAlerts((prev) => Math.max(0, prev - 1));
        }

        router.post(
            path('notifications', item.id, 'read'),
            {},
            { preserveScroll: true, preserveState: true },
        );
    };

    const markAllAlertsRead = () => {
        setLocalNotifications((prev) =>
            prev.map((n) => ({ ...n, is_read: true })),
        );
        setUnreadAlerts(0);
        // Marks all unread for user (messages + alerts). Prefer full clear for simplicity.
        router.post(
            path('notifications', 'mark-all-read'),
            {},
            { preserveScroll: true },
        );
        setLocalMessages((prev) => prev.map((n) => ({ ...n, is_read: true })));
        setUnreadMessages(0);
    };

    const latestAlerts = localNotifications.slice(0, 3);
    const latestMessages = localMessages.slice(0, 3);

    return (
        <header className="flex h-16 shrink-0 items-center gap-2 border-b border-sidebar-border/50 bg-background/95 px-4 backdrop-blur transition-[width,height] ease-linear group-has-data-[collapsible=icon]/sidebar-wrapper:h-12 md:px-6">
            <div className="flex flex-1 items-center gap-2">
                <SidebarTrigger className="-ml-1" />

                {breadcrumbs.length > 0 && (
                    <div className="hidden md:block">
                        <Breadcrumbs breadcrumbs={breadcrumbs} />
                    </div>
                )}
            </div>

            <div className="flex flex-1 items-center justify-center px-2">
                <form
                    onSubmit={handleSearch}
                    className="relative w-full max-w-md"
                >
                    <div className="relative">
                        <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
                        <Input
                            type="search"
                            placeholder="Search orders, sellers, products..."
                            className="h-9 w-full pr-4 pl-9"
                            value={searchQuery}
                            onChange={(e) => setSearchQuery(e.target.value)}
                            onFocus={() => setShowSearch(true)}
                        />
                        {searchQuery && (
                            <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                className="absolute top-1/2 right-1 h-7 w-7 -translate-y-1/2"
                                onClick={() => setSearchQuery('')}
                            >
                                <X className="h-4 w-4" />
                            </Button>
                        )}
                    </div>
                </form>
            </div>

            <div className="flex items-center gap-1">
                {/* Notifications (non-message alerts) */}
                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <Button
                            variant="ghost"
                            size="icon"
                            className="relative h-9 w-9"
                            aria-label="Notifications"
                        >
                            <Bell className="h-4 w-4" />
                            {unreadAlerts > 0 && (
                                <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-destructive px-0.5 text-[10px] font-medium text-destructive-foreground">
                                    {badgeLabel(unreadAlerts)}
                                </span>
                            )}
                        </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-80">
                        <DropdownMenuLabel className="flex items-center justify-between">
                            Notifications
                            {unreadAlerts > 0 && (
                                <span className="text-xs font-normal text-muted-foreground">
                                    {unreadAlerts} unread
                                </span>
                            )}
                        </DropdownMenuLabel>
                        <DropdownMenuSeparator />
                        {latestAlerts.length > 0 ? (
                            latestAlerts.map((notif) => (
                                <DropdownMenuItem
                                    key={notif.id}
                                    className="flex cursor-pointer flex-col items-start gap-1 py-2.5"
                                    onClick={() => {
                                        markAsRead(notif);
                                        if (notif.action_url) {
                                            window.location.href =
                                                notif.action_url;
                                        }
                                    }}
                                >
                                    <div className="flex w-full items-start justify-between gap-2">
                                        <span className="text-sm leading-tight font-medium">
                                            {notif.title}
                                        </span>
                                        {!notif.is_read && (
                                            <span className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                                        )}
                                    </div>
                                    <span className="line-clamp-2 text-xs text-muted-foreground">
                                        {notif.body}
                                    </span>
                                    <div className="flex w-full items-center justify-between">
                                        <span className="text-[10px] text-muted-foreground">
                                            {notif.time_ago}
                                        </span>
                                        <span className="text-[10px] capitalize text-muted-foreground">
                                            {notif.type}
                                        </span>
                                    </div>
                                </DropdownMenuItem>
                            ))
                        ) : (
                            <div className="px-2 py-4 text-center text-sm text-muted-foreground">
                                No notifications
                            </div>
                        )}
                        <DropdownMenuSeparator />
                        {(unreadAlerts > 0 || unreadMessages > 0) && (
                            <DropdownMenuItem
                                onClick={markAllAlertsRead}
                                className="cursor-pointer justify-center text-sm"
                            >
                                Mark all as read
                            </DropdownMenuItem>
                        )}
                        <DropdownMenuItem asChild>
                            <Link
                                href={path('notifications')}
                                className="w-full justify-center text-sm"
                            >
                                View all notifications
                            </Link>
                        </DropdownMenuItem>
                        <DropdownMenuItem asChild>
                            <Link
                                href={path('support')}
                                className="w-full justify-center text-sm"
                            >
                                Go to Support
                            </Link>
                        </DropdownMenuItem>
                        <DropdownMenuSeparator />
                        <div className="px-2 py-1 text-xs font-medium text-muted-foreground">
                            My Channels
                        </div>
                        <form
                            onSubmit={(e) => {
                                e.preventDefault();
                                const channels = [
                                    'in_app',
                                    'email',
                                    'push',
                                    'sms',
                                ].filter((ch) => {
                                    const el = e.currentTarget.elements.namedItem(
                                        `ch_${ch}`,
                                    ) as HTMLInputElement | null;
                                    return el?.checked;
                                });
                                router.post(
                                    path('notifications', 'preferences'),
                                    { channels },
                                    { preserveScroll: true },
                                );
                            }}
                            className="space-y-1 px-2 pb-2"
                        >
                            {['in_app', 'email', 'push', 'sms'].map((ch) => (
                                <label
                                    key={ch}
                                    className="flex cursor-pointer items-center gap-2 text-sm"
                                >
                                    <input
                                        type="checkbox"
                                        name={`ch_${ch}`}
                                        defaultChecked={[
                                            'in_app',
                                            'email',
                                        ].includes(ch)}
                                        className="accent-primary"
                                    />
                                    <span className="capitalize">
                                        {ch.replace('_', ' ')}
                                    </span>
                                </label>
                            ))}
                            <Button
                                type="submit"
                                size="sm"
                                variant="outline"
                                className="mt-1 w-full"
                            >
                                Save Preferences
                            </Button>
                        </form>
                    </DropdownMenuContent>
                </DropdownMenu>

                {/* Messages (type = message) */}
                <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                        <Button
                            variant="ghost"
                            size="icon"
                            className="relative h-9 w-9"
                            aria-label="Messages"
                        >
                            <MessageCircle className="h-4 w-4" />
                            {unreadMessages > 0 && (
                                <span className="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-primary px-0.5 text-[10px] font-medium text-primary-foreground">
                                    {badgeLabel(unreadMessages)}
                                </span>
                            )}
                        </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="end" className="w-96">
                        <DropdownMenuLabel className="flex items-center justify-between">
                            Messages
                            {unreadMessages > 0 && (
                                <span className="text-xs font-normal text-muted-foreground">
                                    {unreadMessages} unread
                                </span>
                            )}
                        </DropdownMenuLabel>
                        <DropdownMenuSeparator />

                        {isAdminArea && (
                            <div className="space-y-2 p-2">
                                <form
                                    onSubmit={(e) => {
                                        e.preventDefault();
                                        const form =
                                            e.currentTarget as HTMLFormElement;
                                        const title = (
                                            form.elements.namedItem(
                                                'title',
                                            ) as HTMLInputElement
                                        )?.value;
                                        const body = (
                                            form.elements.namedItem(
                                                'body',
                                            ) as HTMLTextAreaElement
                                        )?.value;
                                        const recipient = (
                                            form.elements.namedItem(
                                                'recipient_id',
                                            ) as HTMLSelectElement
                                        )?.value;
                                        if (!title || !body) return;

                                        router.post(
                                            path(
                                                'notifications',
                                                'send-message',
                                            ),
                                            {
                                                title,
                                                body,
                                                recipient_id:
                                                    recipient || 'all',
                                            },
                                            {
                                                preserveScroll: true,
                                                onSuccess: () => {
                                                    form.reset();
                                                    fetch(
                                                        path(
                                                            'notifications',
                                                            'recent',
                                                        ),
                                                    )
                                                        .then((r) => r.json())
                                                        .then((data) => {
                                                            if (
                                                                Array.isArray(
                                                                    data.messages,
                                                                )
                                                            ) {
                                                                setLocalMessages(
                                                                    data.messages.slice(
                                                                        0,
                                                                        3,
                                                                    ),
                                                                );
                                                            }
                                                            if (
                                                                typeof data.unread_messages_count ===
                                                                'number'
                                                            ) {
                                                                setUnreadMessages(
                                                                    data.unread_messages_count,
                                                                );
                                                            }
                                                        });
                                                },
                                            },
                                        );
                                    }}
                                    className="space-y-1"
                                >
                                    <select
                                        name="recipient_id"
                                        className="w-full rounded border bg-background px-2 py-1 text-sm"
                                    >
                                        <option value="all">All users</option>
                                        {(
                                            (page.props as { adminUsers?: Array<{ id: number; name: string }> })
                                                .adminUsers || []
                                        ).map((u) => (
                                            <option key={u.id} value={u.id}>
                                                {u.name}
                                            </option>
                                        ))}
                                    </select>
                                    <Input
                                        name="title"
                                        placeholder="Message title"
                                        className="h-8 text-sm"
                                        required
                                    />
                                    <textarea
                                        name="body"
                                        placeholder="Message body..."
                                        className="h-16 w-full resize-y rounded border p-1 text-sm"
                                        required
                                    />
                                    <Button
                                        type="submit"
                                        size="sm"
                                        className="w-full"
                                    >
                                        Send Internal Message
                                    </Button>
                                </form>
                            </div>
                        )}

                        {isAdminArea && <DropdownMenuSeparator />}
                        <DropdownMenuLabel className="text-xs text-muted-foreground">
                            Latest messages
                        </DropdownMenuLabel>

                        {latestMessages.length > 0 ? (
                            latestMessages.map((msg) => (
                                <DropdownMenuItem
                                    key={msg.id}
                                    className="flex cursor-pointer flex-col items-start py-2"
                                    onClick={() => markAsRead(msg)}
                                >
                                    <div className="flex w-full justify-between gap-2">
                                        <span className="text-sm font-medium">
                                            {msg.title}
                                        </span>
                                        {!msg.is_read && (
                                            <span className="mt-1 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                                        )}
                                    </div>
                                    <span className="line-clamp-2 text-xs text-muted-foreground">
                                        {msg.body}
                                    </span>
                                    <span className="text-[10px] text-muted-foreground">
                                        {msg.time_ago}
                                    </span>
                                </DropdownMenuItem>
                            ))
                        ) : (
                            <div className="px-2 py-2 text-xs text-muted-foreground">
                                {isAdminArea
                                    ? 'No messages yet. Send one above.'
                                    : 'No messages yet.'}
                            </div>
                        )}

                        <DropdownMenuSeparator />
                        <DropdownMenuItem asChild>
                            <Link
                                href={path('notifications')}
                                className="w-full justify-center text-sm"
                            >
                                View all
                            </Link>
                        </DropdownMenuItem>
                    </DropdownMenuContent>
                </DropdownMenu>
            </div>
        </header>
    );
}
