<?php

namespace App\Http\Middleware;

use Illuminate\Http\Request;
use Inertia\Middleware;

class HandleInertiaRequests extends Middleware
{
    /**
     * The root template that's loaded on the first page visit.
     *
     * @see https://inertiajs.com/server-side-setup#root-template
     *
     * @var string
     */
    protected $rootView = 'app';

    /**
     * Determines the current asset version.
     *
     * @see https://inertiajs.com/asset-versioning
     */
    public function version(Request $request): ?string
    {
        return parent::version($request);
    }

    /**
     * Define the props that are shared by default.
     *
     * @see https://inertiajs.com/shared-data
     *
     * @return array<string, mixed>
     */
    public function share(Request $request): array
    {
        $user = $request->user();

        return [
            ...parent::share($request),
            'name' => config('app.name'),
            'auth' => [
                'user' => $user,
                // Spatie roles/permissions via App\Models\Role & Permission
                'roles' => $user
                    ? $user->getRoleNames()->values()->all()
                    : [],
                'permissions' => $user
                    ? $user->getAllPermissions()->pluck('name')->values()->all()
                    : [],
                // Convenience alias of first Spatie role (not a separate system)
                'role' => $user?->primaryRoleName(),
                // Role-area helpers for menus/settings links
                'home_path' => $user?->homePath(),
                'settings_path' => $user?->settingsPath('profile'),
            ],
            'flash' => [
                'success' => fn () => $request->session()->get('success'),
                'error' => fn () => $request->session()->get('error'),
            ],
            'sidebarOpen' => ! $request->hasCookie('sidebar_state') || $request->cookie('sidebar_state') === 'true',

            // Share users for internal messaging in admin
            'adminUsers' => $user && str_starts_with($request->path(), 'admin') ? \App\Models\User::select('id', 'name', 'email')
                ->orderBy('name')
                ->get()
                ->map(fn ($u) => ['id' => $u->id, 'name' => $u->name . ' (' . $u->email . ')'])
                ->toArray() : [],
            // Topbar: alerts (bell) vs messages (chat) — latest 3 + separate unread counts
            'notifications' => $user
                ? $this->shareNotificationsPayload($user->id)
                : null,
        ];
    }

    /**
     * Shared payload for the topbar bell + messages icons.
     *
     * @return array{
     *     recent: list<array<string, mixed>>,
     *     recent_messages: list<array<string, mixed>>,
     *     unread_count: int,
     *     unread_messages_count: int
     * }
     */
    private function shareNotificationsPayload(int $userId): array
    {
        $map = function ($n) {
            return [
                'id' => $n->id,
                'title' => $n->title,
                'body' => $n->body,
                'type' => $n->type instanceof \BackedEnum
                    ? $n->type->value
                    : (string) $n->type,
                'action_url' => $n->action_url,
                'read_at' => $n->read_at,
                'created_at' => $n->created_at,
                'time_ago' => $n->time_ago,
                'is_read' => $n->is_read,
                'priority' => $n->priority instanceof \BackedEnum
                    ? $n->priority->value
                    : (string) $n->priority,
            ];
        };

        $forUser = fn () => \App\Models\Notification::query()
            ->where('user_id', $userId)
            ->notExpired();

        return [
            'recent' => $forUser()
                ->alerts()
                ->orderByDesc('created_at')
                ->limit(3)
                ->get()
                ->map($map)
                ->values()
                ->all(),
            'recent_messages' => $forUser()
                ->messages()
                ->orderByDesc('created_at')
                ->limit(3)
                ->get()
                ->map($map)
                ->values()
                ->all(),
            'unread_count' => $forUser()->alerts()->unread()->count(),
            'unread_messages_count' => $forUser()->messages()->unread()->count(),
        ];
    }
}
