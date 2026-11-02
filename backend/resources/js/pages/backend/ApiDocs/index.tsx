// resources/js/pages/backend/ApiDocs/index.tsx
import { Head, Link } from '@inertiajs/react';
import { BookOpen, ExternalLink, Code2 } from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import AppLayout from '@/layouts/app-layout';
import type { BreadcrumbItem } from '@/types';

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: '/admin' },
    { title: 'API Docs', href: '/admin/api-docs' },
];

const apiEndpoints = [
    { method: 'GET', path: '/api/v1/health', desc: 'Service health check' },
    { method: 'POST', path: '/api/v1/auth/login', desc: 'User login (email/phone + password)' },
    { method: 'POST', path: '/api/v1/auth/login-otp', desc: 'Request OTP login' },
    { method: 'POST', path: '/api/v1/auth/register', desc: 'Register new user' },
    { method: 'GET', path: '/api/v1/products/listings', desc: 'Public product listings' },
    { method: 'GET', path: '/api/v1/orders', desc: 'List orders (auth required)' },
    { method: 'POST', path: '/api/v1/orders', desc: 'Create order / checkout' },
    { method: 'GET', path: '/api/v1/deliveries', desc: 'List deliveries' },
    { method: 'POST', path: '/api/v1/deliveries/{id}/accept', desc: 'Driver accepts delivery' },
    { method: 'POST', path: '/api/v1/trucks/{id}/location', desc: 'Update truck/driver location' },
    { method: 'GET', path: '/api/v1/seller/onboarding', desc: 'Seller onboarding status' },
];

export default function ApiDocs() {
    return (
        <AppLayout breadcrumbs={breadcrumbs}>
            <Head title="API Documentation">
                <meta name="description" content="Reference for the SiteDrop REST API used by the mobile application and integrations." />
            </Head>

            <div className="space-y-6 p-4 md:p-6 lg:p-8">
                <div>
                    <h1 className="flex items-center gap-2 text-2xl font-bold tracking-tight">
                        <BookOpen className="h-6 w-6" />
                        API Documentation
                    </h1>
                    <p className="text-sm text-muted-foreground">
                        Internal reference for the SiteDrop REST API (v1)
                    </p>
                </div>

                <Card>
                    <CardHeader>
                        <CardTitle>Base Information</CardTitle>
                        <CardDescription>
                            All authenticated endpoints require a Sanctum bearer token.
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="space-y-2 text-sm">
                        <div>
                            <strong>Base URL:</strong> <code className="rounded bg-muted px-1.5 py-0.5">/api/v1</code>
                        </div>
                        <div>
                            <strong>Auth header:</strong> <code className="rounded bg-muted px-1.5 py-0.5">Authorization: Bearer {'{token}'}</code>
                        </div>
                        <div className="pt-2">
                            <Link href="/admin/system-settings" className="text-primary underline inline-flex items-center gap-1">
                                View / edit public config &amp; keys <ExternalLink className="h-3.5 w-3.5" />
                            </Link>
                        </div>
                    </CardContent>
                </Card>

                <Card>
                    <CardHeader>
                        <CardTitle className="flex items-center gap-2">
                            <Code2 className="h-5 w-5" />
                            Key Endpoints
                        </CardTitle>
                        <CardDescription>
                            Commonly used endpoints by the mobile app and integrations.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="overflow-x-auto">
                            <table className="w-full text-sm">
                                <thead>
                                    <tr className="border-b text-left text-muted-foreground">
                                        <th className="py-2 pr-4 font-medium">Method</th>
                                        <th className="py-2 pr-4 font-medium">Endpoint</th>
                                        <th className="py-2 font-medium">Description</th>
                                    </tr>
                                </thead>
                                <tbody className="divide-y">
                                    {apiEndpoints.map((ep, idx) => (
                                        <tr key={idx}>
                                            <td className="py-2 pr-4">
                                                <Badge variant={ep.method === 'GET' ? 'secondary' : 'default'} className="font-mono text-xs">
                                                    {ep.method}
                                                </Badge>
                                            </td>
                                            <td className="py-2 pr-4 font-mono text-xs text-foreground/90">
                                                {ep.path}
                                            </td>
                                            <td className="py-2 text-muted-foreground">{ep.desc}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                        </div>
                    </CardContent>
                </Card>

                <div className="text-sm text-muted-foreground">
                    For full details see the API source in <code>routes/api.php</code> or the mobile app's <code>ApiService</code>.
                </div>
            </div>
        </AppLayout>
    );
}
