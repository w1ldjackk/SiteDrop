<?php

namespace App\Console\Commands;

use App\Models\DeliveryOffer;
use App\Models\Delivery;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class DeliveryCleanupExpiredOffers extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'delivery:cleanup-expired-offers {--dry-run : Show what would be cleaned up without actually deleting}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Clean up expired delivery offers and re-dispatch stuck deliveries';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $dryRun = $this->option('dry-run');

        // 1. Delete expired offers
        $expiredOffers = DeliveryOffer::where('status', 'pending')
            ->where('expires_at', '<', now())
            ->get();

        if ($expiredOffers->isNotEmpty()) {
            $this->info("Found {$expiredOffers->count()} expired offer(s)");

            foreach ($expiredOffers as $offer) {
                $this->line("  - Offer #{$offer->id} (delivery #{$offer->delivery_id}) expired at {$offer->expires_at}");

                if (!$dryRun) {
                    $offer->update(['status' => 'expired']);
                }
            }

            if (!$dryRun) {
                $expiredCount = $expiredOffers->count();
                $this->info("Marked {$expiredCount} offer(s) as expired");
            }
        } else {
            $this->info('No expired offers found');
        }

        // 2. Find deliveries stuck in PENDING with no active offers and no driver assigned
        $stuckDeliveries = Delivery::where('status', Delivery::STATUS_PENDING)
            ->whereNull('driver_id')
            ->whereDoesntHave('offers', function ($q) {
                $q->where('status', 'pending')
                    ->where('expires_at', '>', now());
            })
            ->where('created_at', '<', now()->subMinutes(10)) // Give some time for initial dispatch
            ->get();

        if ($stuckDeliveries->isNotEmpty()) {
            $this->info("Found {$stuckDeliveries->count()} stuck delivery(ies) with no active offers");

            foreach ($stuckDeliveries as $delivery) {
                $this->line("  - Delivery #{$delivery->id} (order #{$delivery->order_id}) stuck since {$delivery->created_at}");

                if (!$dryRun) {
                    try {
                        DB::beginTransaction();

                        // Try to re-dispatch
                        $dispatchService = app(\App\Services\Delivery\DeliveryService::class);
                        $result = $dispatchService->dispatch($delivery);

                        if ($result['dispatched']) {
                            $this->line("    ✓ Re-dispatched to {$result['offers']} driver(s)");
                        } else {
                            $this->line("    ✗ Re-dispatch failed: " . ($result['reason'] ?? 'unknown'));
                        }

                        DB::commit();
                    } catch (\Throwable $e) {
                        DB::rollBack();
                        $this->error("    ✗ Re-dispatch error: {$e->getMessage()}");
                        Log::error('Delivery cleanup re-dispatch failed', [
                            'delivery_id' => $delivery->id,
                            'error' => $e->getMessage(),
                        ]);
                    }
                }
            }
        } else {
            $this->info('No stuck deliveries found');
        }

        // 3. Clean up old completed/failed/cancelled offers (older than 30 days)
        $oldOffers = DeliveryOffer::whereIn('status', ['completed', 'declined', 'expired', 'cancelled'])
            ->where('updated_at', '<', now()->subDays(30))
            ->get();

        if ($oldOffers->isNotEmpty()) {
            $this->info("Found {$oldOffers->count()} old offer(s) eligible for cleanup (older than 30 days)");

            if (!$dryRun) {
                $deleted = DeliveryOffer::whereIn('status', ['completed', 'declined', 'expired', 'cancelled'])
                    ->where('updated_at', '<', now()->subDays(30))
                    ->delete();

                $this->info("Deleted {$deleted} old offer(s)");
            }
        } else {
            $this->info('No old offers to clean up');
        }

        if ($dryRun) {
            $this->warn('DRY RUN - No changes made. Run without --dry-run to apply changes.');
        }

        return Command::SUCCESS;
    }
}