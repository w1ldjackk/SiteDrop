<?php

namespace App\Http\Controllers\Auth;

use App\Actions\Domain\Auth\SendPhoneOtpAction;
use App\Actions\Domain\Auth\VerifyPhoneOtpAction;
use App\Enums\OtpPurpose;
use App\Http\Controllers\Controller;
use App\Services\Activity\ActivityActions;
use App\Services\Activity\ActivityLogger;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\ValidationException;
use Inertia\Inertia;
use Inertia\Response;

/**
 * Session-based OTP login for the Inertia web app.
 *
 * Mobile uses Sanctum tokens via API (/auth/login-otp + /auth/otp/verify).
 * Web must establish a session cookie so Fortify/auth middleware works.
 */
class OtpLoginController extends Controller
{
    public function __construct(
        protected SendPhoneOtpAction $sendPhoneOtpAction,
        protected VerifyPhoneOtpAction $verifyPhoneOtpAction,
    ) {}

    public function create(Request $request): Response
    {
        return Inertia::render('auth/login-otp', [
            'status' => $request->session()->get('status'),
            'phone' => $request->session()->get('otp_login_phone'),
            'step' => $request->session()->get('otp_login_step', 'phone'),
        ]);
    }

    /**
     * Send a login-scoped OTP to a registered phone.
     */
    public function send(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'regex:/^(\+?233|0)?[0-9]{9,10}$/'],
        ], [
            'phone.required' => 'Phone number is required.',
            'phone.regex' => 'Please enter a valid Ghanaian phone number (e.g. 0555486863).',
        ]);

        try {
            $this->sendPhoneOtpAction->execute(
                $validated['phone'],
                OtpPurpose::Login
            );
        } catch (ValidationException $e) {
            throw $e;
        }

        ActivityLogger::log(
            ActivityActions::AUTH_OTP_SENT,
            'Web login OTP sent to '.$validated['phone'],
            null,
            [
                'method' => 'otp',
                'phone' => $validated['phone'],
                'purpose' => OtpPurpose::Login->value,
                'endpoint' => 'login/otp/send',
            ],
            module: 'auth',
        );

        return redirect()
            ->route('login.otp')
            ->with('status', 'OTP sent successfully. Please check your phone.')
            ->with('otp_login_phone', $validated['phone'])
            ->with('otp_login_step', 'otp');
    }

    /**
     * Verify login OTP, start session, redirect to role home.
     */
    public function verify(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'phone' => ['required', 'string', 'regex:/^(\+?233|0)?[0-9]{9,10}$/'],
            'otp' => ['required', 'string', 'size:6'],
            'remember' => ['sometimes', 'boolean'],
        ], [
            'otp.required' => 'OTP is required.',
            'otp.size' => 'OTP must be exactly 6 digits.',
        ]);

        try {
            $user = $this->verifyPhoneOtpAction->execute(
                $validated['phone'],
                $validated['otp'],
                OtpPurpose::Login
            );
        } catch (ValidationException $e) {
            ActivityLogger::log(
                'auth.login_failed',
                'Web OTP login failed for '.$validated['phone'],
                null,
                [
                    'method' => 'otp',
                    'phone' => $validated['phone'],
                    'errors' => $e->errors(),
                    'endpoint' => 'login/otp/verify',
                ],
                level: \App\Models\ActivityLog::LEVEL_WARNING,
                module: 'auth',
            );

            return redirect()
                ->route('login.otp')
                ->withInput($request->only('phone'))
                ->with('otp_login_phone', $validated['phone'])
                ->with('otp_login_step', 'otp')
                ->withErrors($e->errors());
        }

        Auth::login($user, $request->boolean('remember'));
        $request->session()->regenerate();
        $request->session()->forget(['otp_login_phone', 'otp_login_step']);

        ActivityLogger::log(
            ActivityActions::AUTH_LOGIN,
            "User {$user->name} signed in via OTP (web)",
            $user,
            [
                'method' => 'otp',
                'phone' => $validated['phone'],
                'endpoint' => 'login/otp/verify',
            ],
            module: 'auth',
            userId: (int) $user->id,
        );

        return redirect()->intended($user->homePath());
    }

    /**
     * Resend login OTP (same as send; keeps OTP step).
     */
    public function resend(Request $request): RedirectResponse
    {
        return $this->send($request);
    }
}
