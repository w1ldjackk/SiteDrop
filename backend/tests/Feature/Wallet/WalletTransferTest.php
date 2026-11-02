<?php

use App\Models\User;
use App\Models\Wallet;
use App\Services\Wallet\WalletService;
use Illuminate\Validation\ValidationException;

beforeEach(function () {
    $this->service = app(WalletService::class);
});

function makeWalletUser(float $balance): User
{
    $user = User::factory()->create([
        'role' => 'buyer',
        'preferences' => ['notification_channels' => ['in_app']],
    ]);

    Wallet::forUser($user)->update([
        'balance' => $balance,
        'blocked_balance' => 0,
        'total_earned' => 0,
        'total_spent' => 0,
        'currency' => 'GHS',
        'is_active' => true,
    ]);

    return $user;
}

test('a wallet transfer debits the sender and credits the recipient', function () {
    $sender = makeWalletUser(100);
    $recipient = makeWalletUser(0);

    $result = $this->service->transfer($sender, $recipient, 40, 'Split bill');

    expect(Wallet::forUser($sender)->balance)->toBe(60.0)
        ->and(Wallet::forUser($recipient)->balance)->toBe(40.0)
        ->and($result['debit']->reference)->toBe($result['credit']->reference)
        ->and((float) $result['debit']->amount)->toBe(40.0)
        ->and((float) $result['credit']->amount)->toBe(40.0);
});

test('a transfer fails when the sender has insufficient balance', function () {
    $sender = makeWalletUser(10);
    $recipient = makeWalletUser(0);

    expect(fn () => $this->service->transfer($sender, $recipient, 40))
        ->toThrow(ValidationException::class);

    expect(Wallet::forUser($sender)->balance)->toBe(10.0)
        ->and(Wallet::forUser($recipient)->balance)->toBe(0.0);
});

test('a user cannot transfer to themselves', function () {
    $user = makeWalletUser(100);

    expect(fn () => $this->service->transfer($user, $user, 10))
        ->toThrow(ValidationException::class);

    expect(Wallet::forUser($user)->balance)->toBe(100.0);
});

test('a transfer rejects non-positive amounts', function () {
    $sender = makeWalletUser(100);
    $recipient = makeWalletUser(0);

    expect(fn () => $this->service->transfer($sender, $recipient, 0))
        ->toThrow(ValidationException::class);
});
