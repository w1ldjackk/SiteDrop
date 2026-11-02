<?php

namespace App\Http\Controllers\Backend;

use App\Enums\NotificationChannel;
use App\Enums\NotificationPriority;
use App\Enums\NotificationType;
use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;
use Inertia\Inertia;

class NotificationController extends Controller
{
    /**
     * Display a listing of the user's notifications (for admin topbar + full page).
     */
    public function index(Request $request)
    {
        $user = $request->user();

        $notifications = Notification::where('user_id', $user->id)
            ->notExpired()
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        $unreadCount = Notification::where('user_id', $user->id)
            ->unread()
            ->notExpired()
            ->count();

        $segment = explode('/', trim($request->path(), '/'))[0] ?? 'admin';
        $area = in_array($segment, ['admin', 'buyer', 'seller', 'driver'], true)
            ? $segment
            : 'admin';

        return Inertia::render('backend/Notifications/Index', [
            'notifications' => $notifications,
            'unreadCount' => $unreadCount,
            'area' => $area,
        ]);
    }

    /**
     * Get recent alerts + messages for the topbar (JSON poll).
     * Returns latest 3 of each with separate unread counts.
     */
    public function recent(Request $request)
    {
        $user = $request->user();

        $map = function (Notification $notification) {
            return [
                'id' => $notification->id,
                'title' => $notification->title,
                'body' => $notification->body,
                'type' => $notification->type instanceof \BackedEnum
                    ? $notification->type->value
                    : (string) $notification->type,
                'action_url' => $notification->action_url,
                'read_at' => $notification->read_at,
                'created_at' => $notification->created_at,
                'time_ago' => $notification->time_ago,
                'is_read' => $notification->is_read,
                'priority' => $notification->priority instanceof \BackedEnum
                    ? $notification->priority->value
                    : (string) $notification->priority,
            ];
        };

        $forUser = fn () => Notification::query()
            ->where('user_id', $user->id)
            ->notExpired();

        $notifications = $forUser()
            ->alerts()
            ->orderByDesc('created_at')
            ->limit(3)
            ->get()
            ->map($map)
            ->values();

        $messages = $forUser()
            ->messages()
            ->orderByDesc('created_at')
            ->limit(3)
            ->get()
            ->map($map)
            ->values();

        return response()->json([
            'notifications' => $notifications,
            'messages' => $messages,
            'unread_count' => $forUser()->alerts()->unread()->count(),
            'unread_messages_count' => $forUser()->messages()->unread()->count(),
        ]);
    }

    /**
     * Mark a notification as read.
     */
    public function markAsRead(Request $request, Notification $notification)
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(403);
        }

        $notification->markAsRead();

        return back()->with('success', 'Notification marked as read.');
    }

    /**
     * Mark all notifications as read for the current user.
     */
    public function markAllAsRead(Request $request)
    {
        Notification::where('user_id', $request->user()->id)
            ->unread()
            ->update(['read_at' => now()]);

        return back()->with('success', 'All notifications marked as read.');
    }

    /**
     * Delete a notification.
     */
    public function destroy(Request $request, Notification $notification)
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(403);
        }

        $notification->delete();

        return back()->with('success', 'Notification deleted.');
    }

    /**
     * Send an internal message (basic chat-like functionality).
     * recipient_id can be a user id, or 'all' / null to send to all users.
     */
    public function sendMessage(Request $request)
    {
        $validated = $request->validate([
            'recipient_id' => 'nullable',
            'title' => 'required|string|max:255',
            'body' => 'required|string|max:2000',
        ]);

        $senderId = $request->user()->id;
        $title = $validated['title'];
        $body = $validated['body'];

        $recipients = [];

        if ($validated['recipient_id'] === 'all' || empty($validated['recipient_id'])) {
            // Send to all users (or you could filter by role, e.g. admins)
            $recipients = \App\Models\User::pluck('id')->toArray();
        } else {
            $recipientId = (int) $validated['recipient_id'];
            if (\App\Models\User::where('id', $recipientId)->exists()) {
                $recipients = [$recipientId];
            }
        }

        foreach ($recipients as $recipientId) {
            Notification::createNotification(
                $recipientId,
                $title,
                $body,
                NotificationType::Message,
                ['sender_id' => $senderId],
                NotificationChannel::InApp,
                NotificationPriority::Normal,
                null
            );
        }

        return back()->with('success', count($recipients) > 1 ? 'Message sent to all users.' : 'Message sent.');
    }

    /**
     * Update current user's notification channel preferences.
     */
    public function updatePreferences(Request $request)
    {
        $validated = $request->validate([
            'channels' => 'array',
            'channels.*' => 'string|in:in_app,email,push,sms',
        ]);

        $user = $request->user();
        $prefs = $user->preferences ?? [];
        $prefs['notification_channels'] = $validated['channels'] ?? ['in_app', 'email'];

        $user->update(['preferences' => $prefs]);

        return back()->with('success', 'Notification preferences updated.');
    }
}
