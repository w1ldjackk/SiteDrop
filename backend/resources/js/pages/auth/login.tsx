// resources/js/pages/auth/login.tsx
import { Form, Head } from '@inertiajs/react';
import InputError from '@/components/input-error';
import TextLink from '@/components/text-link';
import { Button } from '@/components/ui/button';
import { Checkbox } from '@/components/ui/checkbox';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import AuthLayout from '@/layouts/auth-layout';
import { register } from '@/routes';
import { store } from '@/routes/login';
import { request } from '@/routes/password';

type Props = {
    status?: string;
    canResetPassword: boolean;
    canRegister: boolean;
};

export default function Login({
    status,
    canResetPassword,
    canRegister,
}: Props) {
    return (
        <AuthLayout
            title="Welcome back to Sitedrop"
            description="Sign in to manage your construction materials and deliveries"
        >
            <Head title="Log in" />

            <Form
                {...store.form()}
                resetOnSuccess={['password']}
                className="flex flex-col gap-6"
            >
                {({ processing, errors }) => (
                    <>
                        <div className="grid gap-6">
                            {/* Primary Field: Phone or Email */}
                            <div className="grid gap-2">
                                <Label htmlFor="login">
                                    Phone number or Email
                                </Label>
                                <Input
                                    id="login"
                                    name="email" // Keep name="email" for Fortify compatibility
                                    type="text"
                                    required
                                    autoFocus
                                    tabIndex={1}
                                    autoComplete="username"
                                    placeholder="055 548 6863 or email@example.com"
                                />
                                <InputError message={errors.email} />
                                <p className="text-xs text-muted-foreground">
                                    We'll accept either your phone number or
                                    email
                                </p>
                            </div>

                            {/* Password */}
                            <div className="grid gap-2">
                                <div className="flex items-center justify-between">
                                    <Label htmlFor="password">Password</Label>
                                    {canResetPassword && (
                                        <TextLink
                                            href={request()}
                                            className="text-sm"
                                            tabIndex={5}
                                        >
                                            Forgot password?
                                        </TextLink>
                                    )}
                                </div>
                                <Input
                                    id="password"
                                    type="password"
                                    name="password"
                                    required
                                    tabIndex={2}
                                    autoComplete="current-password"
                                    placeholder="Enter your password"
                                />
                                <InputError message={errors.password} />
                            </div>

                            {/* Remember Me */}
                            <div className="flex items-center space-x-3">
                                <Checkbox
                                    id="remember"
                                    name="remember"
                                    tabIndex={3}
                                />
                                <Label htmlFor="remember" className="text-sm">
                                    Keep me signed in
                                </Label>
                            </div>

                            {/* Login Button */}
                            <Button
                                type="submit"
                                className="mt-2 w-full"
                                tabIndex={4}
                                disabled={processing}
                                size="lg"
                            >
                                {processing && <Spinner className="mr-2" />}
                                Sign in
                            </Button>
                        </div>

                        {/* Register Link */}
                        {canRegister && (
                            <div className="pt-4 text-center text-sm text-muted-foreground">
                                Don't have an account?{' '}
                                <TextLink
                                    href={register()}
                                    className="font-medium"
                                >
                                    Create free account
                                </TextLink>
                            </div>
                        )}

                        {/* Future Phone OTP Option */}
                        <div className="text-center">
                            <TextLink
                                href="/login/otp"
                                className="text-sm text-primary hover:underline"
                            >
                                Login with Phone OTP instead
                            </TextLink>
                        </div>
                    </>
                )}
            </Form>

            {status && (
                <div className="mt-4 text-center text-sm font-medium text-green-600">
                    {status}
                </div>
            )}
        </AuthLayout>
    );
}
