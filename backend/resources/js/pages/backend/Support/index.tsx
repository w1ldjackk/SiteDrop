// resources/js/pages/backend/Support/index.tsx
import { Head, Link } from '@inertiajs/react';
import { HelpCircle, Mail, Phone, MessageSquare } from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import AppLayout from '@/layouts/app-layout';
import { useRoleArea } from '@/hooks/use-role-area';
import type { BreadcrumbItem } from '@/types';


export default function Support() {
    const { path, base, isAdminArea } = useRoleArea();
    const breadcrumbs: BreadcrumbItem[] = [
        { title: 'Dashboard', href: base },
        { title: 'Support', href: path('support') },
    ];

    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="Support">
                <meta
                    name="description"
                    content="Get help and contact support for SiteDrop."
                />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <HelpCircle className="h-6 w-6" />
                        Support
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Need help with the platform? Contact our support team.
                    </p>
                </div>

                <div className="grid gap-6 md:grid-cols-2">
                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <Mail className="h-5 w-5" /> Email Support
                            </CardTitle>
                            <CardDescription>
                                Reach out to the platform support team
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <p className="text-sm text-muted-foreground">
                                For urgent issues with orders, deliveries, or seller approvals.
                            </p>
                            <Button asChild variant="outline">
                                <a href="mailto:support@sitedrop.com">support@sitedrop.com</a>
                            </Button>
                            <p className="text-xs text-muted-foreground">
                                Typical response time: 1-4 business hours
                            </p>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <Phone className="h-5 w-5" /> Phone Support
                            </CardTitle>
                            <CardDescription>
                                Direct line for critical issues
                            </CardDescription>
                        </CardHeader>
                        <CardContent className="space-y-4">
                            <p className="text-sm text-muted-foreground">
                                Available during business hours (GMT)
                            </p>
                            <Button asChild variant="outline">
                                <a href="tel:+233123456789">+233 123 456 789</a>
                            </Button>
                        </CardContent>
                    </Card>

                    <Card className="md:col-span-2">
                        <CardHeader>
                            <CardTitle className="flex items-center gap-2">
                                <MessageSquare className="h-5 w-5" /> Resources
                            </CardTitle>
                            <CardDescription>
                                Quick links for common tasks
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <div className="grid gap-3 sm:grid-cols-2">
                                {isAdminArea && (
                                    <>
                                        <Button variant="secondary" asChild>
                                            <Link href={path('system-settings')}>
                                                Manage Support Contacts
                                            </Link>
                                        </Button>
                                        <Button variant="secondary" asChild>
                                            <Link href={path('api-docs')}>
                                                View API Documentation
                                            </Link>
                                        </Button>
                                        <Button variant="secondary" asChild>
                                            <Link href={path('activity-logs')}>
                                                Review Recent Activity
                                            </Link>
                                        </Button>
                                    </>
                                )}
                                <Button variant="secondary" asChild>
                                    <Link href={path('notifications')}>
                                        View Notifications
                                    </Link>
                                </Button>
                            </div>
                        </CardContent>
                    </Card>
                </div>
            </div>
        </AppLayout>
    );
}
