<?php

namespace App\Services\Notification;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Facades\Lang;

/**
 * Password reset email containing both a web reset link and a 6-digit code
 * (for use in the mobile app without opening the browser).
 */
class PasswordResetWithCode extends Notification
{
    use Queueable;

    public function __construct(
        public string $token,
        public string $code,
    ) {}

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        $url = $this->resetUrl($notifiable);
        $expire = (int) config(
            'auth.passwords.'.config('auth.defaults.passwords').'.expire',
            60
        );

        return (new MailMessage)
            ->subject(Lang::get('Reset Password Notification'))
            ->greeting(Lang::get('Hello :name!', [
                'name' => $notifiable->name ?? 'there',
            ]))
            ->line(Lang::get('You are receiving this email because we received a password reset request for your account.'))
            ->line(Lang::get('You can reset your password in either of these ways:'))
            ->line(Lang::get('**Option 1 — Use the link** (web browser):'))
            ->action(Lang::get('Reset Password'), $url)
            ->line(Lang::get('**Option 2 — Enter this code** in the SiteDrop app:'))
            ->line(Lang::get('Your reset code is: **:code**', ['code' => $this->code]))
            ->line(Lang::get('This link and code will expire in :count minutes.', ['count' => $expire]))
            ->line(Lang::get('If you did not request a password reset, no further action is required.'));
    }

    protected function resetUrl(object $notifiable): string
    {
        return url(route('password.reset', [
            'token' => $this->token,
            'email' => $notifiable->getEmailForPasswordReset(),
        ], false));
    }
}
