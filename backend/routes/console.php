<?php

use App\Console\Commands\DeliveryCleanupExpiredOffers;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Schedule delivery offer cleanup to run every 5 minutes
Schedule::command(DeliveryCleanupExpiredOffers::class)
    ->everyFiveMinutes()
    ->withoutOverlapping()
    ->runInBackground()
    ->appendOutputTo(storage_path('logs/delivery-cleanup.log'));
