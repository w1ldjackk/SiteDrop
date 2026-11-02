<?php

namespace App\Services\Activity;

use App\Models\ActivityLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Central activity logger for SiteDrop.
 *
 * Usage:
 *   ActivityLogger::log('order.created', 'Order #123 placed', $order, ['module' => 'orders']);
 *   ActivityLogger::forUser($user)->log('auth.login', 'User signed in');
 */
class ActivityLogger
{
    protected ?int $userId = null;

    public static function make(): self
    {
        return new self();
    }

    public static function forUser(?User $user): self
    {
        $instance = new self();
        $instance->userId = $user?->id;

        return $instance;
    }

    /**
     * Write an activity log entry (never throws to callers).
     *
     * @param  array<string, mixed>  $properties
     */
    public static function log(
        string $action,
        string $description,
        ?Model $subject = null,
        array $properties = [],
        string $level = ActivityLog::LEVEL_INFO,
        ?string $module = null,
        ?int $userId = null,
    ): ?ActivityLog {
        try {
            $request = request();
            $actorId = $userId
                ?? (new self())->userId
                ?? Auth::id();

            // Normalize actor id (Sanctum / JSON may pass string ids)
            if ($actorId !== null) {
                $actorId = (int) $actorId;
                if ($actorId <= 0) {
                    $actorId = null;
                }
            }

            // Infer module from action prefix: "order.created" → "order"
            $resolvedModule = $module
                ?? (str_contains($action, '.') ? explode('.', $action)[0] : 'general');

            $subjectId = $subject?->getKey();
            if (is_string($subjectId) && is_numeric($subjectId)) {
                $subjectId = (int) $subjectId;
            }

            return ActivityLog::query()->create([
                'user_id' => $actorId,
                'action' => $action,
                'description' => mb_substr($description, 0, 500),
                'subject_type' => $subject ? $subject::class : null,
                'subject_id' => $subjectId,
                'module' => $resolvedModule,
                'level' => $level,
                'properties' => $properties !== [] ? $properties : null,
                'ip_address' => $request?->ip(),
                'user_agent' => $request ? mb_substr((string) $request->userAgent(), 0, 1000) : null,
                'request_method' => $request?->method(),
                'request_url' => $request ? mb_substr($request->fullUrl(), 0, 500) : null,
            ]);
        } catch (Throwable $e) {
            // Never break the main request flow because logging failed
            Log::warning('ActivityLogger failed: '.$e->getMessage(), [
                'action' => $action,
                'description' => $description,
                'exception' => $e::class,
            ]);

            return null;
        }
    }

    public function record(
        string $action,
        string $description,
        ?Model $subject = null,
        array $properties = [],
        string $level = ActivityLog::LEVEL_INFO,
        ?string $module = null,
    ): ?ActivityLog {
        return self::log(
            $action,
            $description,
            $subject,
            $properties,
            $level,
            $module,
            $this->userId,
        );
    }
}
