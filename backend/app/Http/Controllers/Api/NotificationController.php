<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Mobile/API notification inbox (in-app list).
 */
class NotificationController extends Controller
{
    /**
     * GET /api/v1/notifications
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();

        $query = Notification::query()
            ->where('user_id', $user->id)
            ->notExpired()
            ->orderByDesc('created_at');

        if ($request->boolean('unread_only')) {
            $query->unread();
        }

        $paginator = $query->paginate(
            min(50, max(1, (int) $request->integer('per_page', 30)))
        );

        $items = collect($paginator->items())->map(
            fn (Notification $n) => $this->transform($n)
        )->values();

        $unreadCount = Notification::query()
            ->where('user_id', $user->id)
            ->unread()
            ->notExpired()
            ->count();

        return $this->success([
            'notifications' => $items,
            'unread_count' => $unreadCount,
            'meta' => $this->paginationMeta($paginator),
        ]);
    }

    /**
     * GET /api/v1/notifications/unread-count
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $count = Notification::query()
            ->where('user_id', $request->user()->id)
            ->unread()
            ->notExpired()
            ->count();

        return $this->success(['unread_count' => $count]);
    }

    /**
     * POST /api/v1/notifications/{id}/read
     */
    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $notification = Notification::query()
            ->where('user_id', $request->user()->id)
            ->whereKey($id)
            ->firstOrFail();

        $notification->markAsRead();

        return $this->success(
            data: ['notification' => $this->transform($notification->fresh())],
            message: 'Notification marked as read',
        );
    }

    /**
     * POST /api/v1/notifications/read-all
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        $updated = Notification::query()
            ->where('user_id', $request->user()->id)
            ->unread()
            ->update(['read_at' => now()]);

        return $this->success(
            data: ['updated' => $updated],
            message: 'All notifications marked as read',
        );
    }

    /**
     * DELETE /api/v1/notifications/{id}
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $notification = Notification::query()
            ->where('user_id', $request->user()->id)
            ->whereKey($id)
            ->firstOrFail();

        $notification->delete();

        return $this->success(message: 'Notification deleted');
    }

    /**
     * @return array<string, mixed>
     */
    protected function transform(Notification $n): array
    {
        $type = $n->type;
        $channel = $n->channel;
        $priority = $n->priority;
        $delivery = $n->delivery_status;

        return [
            'id' => $n->id,
            'user_id' => $n->user_id,
            'type' => $type instanceof \BackedEnum ? $type->value : (string) $type,
            'title' => $n->title,
            'body' => $n->body,
            'data' => $n->data,
            'action_url' => $n->action_url,
            'image_url' => $n->image_url,
            'read_at' => optional($n->read_at)?->toIso8601String(),
            'sent_at' => optional($n->sent_at)?->toIso8601String(),
            'delivery_status' => $delivery instanceof \BackedEnum
                ? $delivery->value
                : (string) $delivery,
            'channel' => $channel instanceof \BackedEnum
                ? $channel->value
                : (string) $channel,
            'priority' => $priority instanceof \BackedEnum
                ? $priority->value
                : (string) $priority,
            'expires_at' => optional($n->expires_at)?->toIso8601String(),
            'created_at' => optional($n->created_at)?->toIso8601String(),
            'updated_at' => optional($n->updated_at)?->toIso8601String(),
            'is_read' => $n->is_read,
            'time_ago' => $n->time_ago,
        ];
    }
}
