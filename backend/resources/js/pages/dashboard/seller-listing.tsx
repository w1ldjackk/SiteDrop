import { Form, Head, useForm } from '@inertiajs/react';
import InputError from '@/components/input-error';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import AuthLayout from '@/layouts/app-layout';
import { dashboard } from '@/routes';
import type { BreadcrumbItem } from '@/types';
import { Switch } from '@/components/ui/switch';
import { Textarea } from '@/components/ui/textarea';

const breadcrumbs: BreadcrumbItem[] = [
    { title: 'Dashboard', href: dashboard().url },
    { title: 'New Listing', href: '/dashboard/seller-listing' },
];

export default function SellerListing() {
    const { data, setData, post, errors, processing } = useForm({
        material: '',
        quantity: '',
        unit: 'ton',
        price: '',
        description: '',
        is_available: true,
        location: '',
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();
        post('/dashboard/seller-listing', {
            onSuccess: () => {
                // Optional: Reset form or show success
            },
        });
    };

    return (
        <AuthLayout breadcrumbs={breadcrumbs}>
            <Head title="New Listing" />

            <div className="mx-auto max-w-2xl space-y-8">
                <div>
                    <h1 className="text-3xl font-bold tracking-tight">
                        New Listing
                    </h1>
                    <p className="mt-1 text-muted-foreground">
                        Post a new material or truck for sale
                    </p>
                </div>

                <Form onSubmit={handleSubmit} className="space-y-8">
                    <div className="grid gap-6">
                        {/* Material / Truck */}
                        <div>
                            <Label>Material or Truck</Label>
                            <Input
                                value={data.material}
                                onChange={(
                                    e: React.ChangeEvent<HTMLInputElement>,
                                ) => setData('material', e.target.value)}
                                placeholder="e.g. Gravel, Sand, 10 Ton Truck"
                                required
                            />
                            <InputError message={errors.material} />
                        </div>

                        {/* Quantity */}
                        <div className="grid grid-cols-2 gap-4">
                            <div>
                                <Label>Quantity</Label>
                                <Input
                                    type="number"
                                    value={data.quantity}
                                    onChange={(
                                        e: React.ChangeEvent<HTMLInputElement>,
                                    ) => setData('quantity', e.target.value)}
                                    placeholder="10"
                                    required
                                />
                                <InputError message={errors.quantity} />
                            </div>

                            <div>
                                <Label>Unit</Label>
                                <select
                                    value={data.unit}
                                    onChange={(
                                        e: React.ChangeEvent<HTMLSelectElement>,
                                    ) => setData('unit', e.target.value)}
                                    className="w-full rounded-md border border-input bg-background px-3 py-2"
                                >
                                    <option value="ton">Ton</option>
                                    <option value="bag">Bag (50kg)</option>
                                    <option value="truck">Truck</option>
                                </select>
                            </div>
                        </div>

                        {/* Price */}
                        <div>
                            <Label>Price (GHS)</Label>
                            <Input
                                type="number"
                                value={data.price}
                                onChange={(
                                    e: React.ChangeEvent<HTMLInputElement>,
                                ) => setData('price', e.target.value)}
                                placeholder="650"
                                required
                            />
                            <InputError message={errors.price} />
                        </div>

                        {/* Description */}
                        <div>
                            <Label>Description</Label>
                            <Textarea
                                value={data.description}
                                onChange={(
                                    e: React.ChangeEvent<HTMLTextAreaElement>,
                                ) => setData('description', e.target.value)}
                                placeholder="Describe the material or truck condition..."
                                rows={4}
                            />
                            <InputError message={errors.description} />
                        </div>

                        {/* Location */}
                        <div>
                            <Label>Location</Label>
                            <Input
                                value={data.location}
                                onChange={(
                                    e: React.ChangeEvent<HTMLInputElement>,
                                ) => setData('location', e.target.value)}
                                placeholder="Accra, Tema, Kumasi..."
                                required
                            />
                            <InputError message={errors.location} />
                        </div>

                        {/* Available Toggle */}
                        <div className="flex items-center justify-between">
                            <div>
                                <Label
                                    htmlFor="is_available"
                                    className="font-medium"
                                >
                                    Is Available Now?
                                </Label>
                                <p className="text-sm text-muted-foreground">
                                    Make this listing visible to buyers
                                </p>
                            </div>
                            <Switch
                                id="is_available"
                                checked={data.is_available}
                                onCheckedChange={(checked: boolean) =>
                                    setData('is_available', checked)
                                }
                            />
                        </div>

                        <Button type="submit" size="lg" disabled={processing}>
                            {processing ? 'Posting...' : 'Post Listing'}
                        </Button>
                    </div>
                </Form>
            </div>
        </AuthLayout>
    );
}
