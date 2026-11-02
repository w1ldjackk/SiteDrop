// resources/js/pages/auth/login-otp.tsx
import { Head, useForm } from '@inertiajs/react';
import { useEffect, useState, type FormEvent } from 'react';
import InputError from '@/components/input-error';
import TextLink from '@/components/text-link';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Spinner } from '@/components/ui/spinner';
import AuthLayout from '@/layouts/auth-layout';
import { login } from '@/routes';

type Props = {
    status?: string;
    phone?: string;
    step?: 'phone' | 'otp';
};

export default function LoginOtp({
    status,
    phone: initialPhone = '',
    step: initialStep = 'phone',
}: Props) {
    const [step, setStep] = useState<'phone' | 'otp'>(initialStep);
    const [resendTimer, setResendTimer] = useState(0);

    const sendForm = useForm({
        phone: initialPhone,
    });

    const verifyForm = useForm({
        phone: initialPhone,
        otp: '',
        remember: false as boolean,
    });

    // Keep phone in sync between steps / server flash
    useEffect(() => {
        if (initialPhone) {
            sendForm.setData('phone', initialPhone);
            verifyForm.setData('phone', initialPhone);
        }
        if (initialStep === 'otp') {
            setStep('otp');
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps -- hydrate once from props
    }, [initialPhone, initialStep]);

    useEffect(() => {
        if (resendTimer <= 0) return;
        const timer = setTimeout(() => setResendTimer((t) => t - 1), 1000);
        return () => clearTimeout(timer);
    }, [resendTimer]);

    const onSend = (e: FormEvent) => {
        e.preventDefault();
        sendForm.post('/login/otp/send', {
            preserveScroll: true,
            onSuccess: () => {
                setStep('otp');
                setResendTimer(60);
                verifyForm.setData('phone', sendForm.data.phone);
            },
        });
    };

    const onVerify = (e: FormEvent) => {
        e.preventDefault();
        verifyForm.setData('phone', sendForm.data.phone || verifyForm.data.phone);
        verifyForm.post('/login/otp/verify', {
            preserveScroll: true,
        });
    };

    const onResend = () => {
        if (resendTimer > 0) return;
        sendForm.post('/login/otp/resend', {
            preserveScroll: true,
            onSuccess: () => setResendTimer(60),
        });
    };

    const phoneValue = sendForm.data.phone || verifyForm.data.phone;
    const processing = sendForm.processing || verifyForm.processing;

    return (
        <AuthLayout
            title="Login with OTP"
            description="Enter your phone number to receive a verification code"
        >
            <Head title="Login with OTP" />

            <div className="mx-auto max-w-md">
                {status && (
                    <div className="mb-4 rounded-md border border-green-200 bg-green-50 px-3 py-2 text-center text-sm font-medium text-green-700 dark:border-green-900 dark:bg-green-950 dark:text-green-300">
                        {status}
                    </div>
                )}

                {step === 'phone' ? (
                    <form onSubmit={onSend} className="flex flex-col gap-6">
                        <div className="grid gap-2">
                            <Label htmlFor="phone">Phone Number</Label>
                            <Input
                                id="phone"
                                type="tel"
                                name="phone"
                                value={sendForm.data.phone}
                                onChange={(e) =>
                                    sendForm.setData('phone', e.target.value)
                                }
                                placeholder="055 548 6863"
                                required
                                autoFocus
                                autoComplete="tel"
                            />
                            <InputError message={sendForm.errors.phone} />
                            <p className="text-xs text-muted-foreground">
                                Use the Ghana number linked to your account
                            </p>
                        </div>

                        <Button
                            type="submit"
                            className="w-full"
                            size="lg"
                            disabled={processing}
                        >
                            {processing && <Spinner className="mr-2" />}
                            Send OTP
                        </Button>
                    </form>
                ) : (
                    <form onSubmit={onVerify} className="flex flex-col gap-6">
                        <div className="text-center">
                            <p className="text-sm text-muted-foreground">
                                We sent a 6-digit code to
                            </p>
                            <p className="mt-1 text-lg font-medium">
                                {phoneValue}
                            </p>
                            <button
                                type="button"
                                className="mt-1 text-xs text-primary hover:underline"
                                onClick={() => setStep('phone')}
                            >
                                Change number
                            </button>
                        </div>

                        <div className="grid gap-2">
                            <Label htmlFor="otp">Enter OTP</Label>
                            <Input
                                id="otp"
                                type="text"
                                name="otp"
                                inputMode="numeric"
                                pattern="[0-9]*"
                                value={verifyForm.data.otp}
                                onChange={(e) =>
                                    verifyForm.setData(
                                        'otp',
                                        e.target.value.replace(/\D/g, '').slice(0, 6),
                                    )
                                }
                                placeholder="123456"
                                maxLength={6}
                                className="text-center text-2xl tracking-widest"
                                required
                                autoFocus
                                autoComplete="one-time-code"
                            />
                            <InputError
                                message={
                                    verifyForm.errors.otp ||
                                    verifyForm.errors.phone ||
                                    verifyForm.errors.user
                                }
                            />
                        </div>

                        <Button
                            type="submit"
                            className="w-full"
                            size="lg"
                            disabled={processing || verifyForm.data.otp.length < 6}
                        >
                            {processing && <Spinner className="mr-2" />}
                            Verify OTP
                        </Button>

                        <div className="text-center">
                            {resendTimer > 0 ? (
                                <p className="text-sm text-muted-foreground">
                                    Resend in {resendTimer}s
                                </p>
                            ) : (
                                <Button
                                    type="button"
                                    variant="link"
                                    onClick={onResend}
                                    disabled={processing}
                                >
                                    Resend OTP
                                </Button>
                            )}
                        </div>
                    </form>
                )}

                <div className="pt-6 text-center">
                    <TextLink href={login()} className="text-sm">
                        Login with Password instead
                    </TextLink>
                </div>
            </div>
        </AuthLayout>
    );
}
