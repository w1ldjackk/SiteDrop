// resources/js/pages/backend/Notifications/Index.tsx
import { Head, Link, router } from '@inertiajs/react';
import { Bell, Check, Trash2 } from 'lucide-react';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import type { BreadcrumbItem } from '@/types';

interface Notification {
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

interface Props {
    notifications: {
        data: Notification[];
        links: any;
        meta: any;
    };
    unreadCount: number;
    area?: string;
}

export default function NotificationsIndex({
    notifications,
    unreadCount,
    area,
}: Props) {
    const { path, base } = useRoleArea(area);
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Notifications', href: path('notifications') },
    ];

    const markAsRead = (id: number) => {
        router.post(path("notifications", id, "read"), {}, { preserveScroll: true });
    };

    const markAllAsRead = () => {
        router.post(path("notifications", "mark-all-read"), {}, { preserveScroll: true });
    };

    const deleteNotification = (id: number) => {
        if (confirm('Delete this notification?')) {
            router.delete(path("notifications", id), { preserveScroll: true });
        }
    };

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Notifications | SiteDrop Admin">
                <meta name="description" content="View and manage your admin notifications." />
            </Head>

            <div className="p-4 md:p-6 lg:p-8 space-y-6">
                <div className="flex items-center justify-between">
                    <div>
                        <h1 className="text-2xl font-bold tracking-tight flex items-center gap-2">
                            <Bell className="h-6 w-6" /> Notifications
                        </h1>
                        <p className="text-muted-foreground">
                            {unreadCount} unread notification{unreadCount !== 1 ? 's' : ''}
                        </p>
                    </div>

                    {unreadCount > 0 && (
                        <Button onClick={markAllAsRead} variant="outline">
                            <Check className="mr-2 h-4 w-4" />
                            Mark all as read
                        </Button>
                    )}
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>All Notifications</CardTitle>
                    </CardHeader>
                    <CardContent>
                        {notifications.data.length > 0 ? (
                            <div className="divide-y">
                                {notifications.data.map((notification) => (
                                    <div
                                        key={notification.id}
                                        className={`flex items-start justify-between gap-4 py-4 ${!notification.is_read ? 'bg-muted/30' : ''}`}
                                    >
                                        <div className="flex-1 space-y-1">
                                            <div className="flex items-center gap-2">
                                                <span className="font-medium">{notification.title}</span>
                                                {!notification.is_read && (
                                                    <Badge variant="destructive" className="text-xs">New</Badge>
                                                )}
                                                <Badge variant="outline" className="text-xs capitalize">
                                                    {notification.type}
                                                </Badge>
                                            </div>
                                            <p className="text-sm text-muted-foreground">
                                                {notification.body}
                                            </p>
                                            <div className="text-xs text-muted-foreground">
                                                {notification.time_ago}
                                            </div>
                                        </div>

                                        <div className="flex items-center gap-1">
                                            {!notification.is_read && (
                                                <Button
                                                    size="sm"
                                                    variant="ghost"
                                                    onClick={() => markAsRead(notification.id)}
                                                >
                                                    <Check className="h-4 w-4" />
                                                </Button>
                                            )}

                                            {notification.action_url && (
                                                <Button size="sm" variant="outline" asChild>
                                                    <Link href={notification.action_url}>View</Link>
                                                </Button>
                                            )}

                                            <Button
                                                size="sm"
                                                variant="ghost"
                                                onClick={() => deleteNotification(notification.id)}
                                            >
                                                <Trash2 className="h-4 w-4 text-destructive" />
                                            </Button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        ) : (
                            <div className="py-12 text-center text-muted-foreground">
                                No notifications yet.
                            </div>
                        )}
                    </CardContent>
                </Card>
            </div>
        </AppLayout>
    );
}
