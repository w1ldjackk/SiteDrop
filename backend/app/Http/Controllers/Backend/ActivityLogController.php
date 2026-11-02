<?php

namespace App\Http\Controllers\Backend;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Inertia\Inertia;
use Inertia\Response;

class ActivityLogController extends Controller
{
    use AuthorizesRequests;

    /**
     * List activity logs (admin / permission only).
     */
    public function index(Request $request): Response
    {
        $this->authorize('viewAny', ActivityLog::class);

        $query = ActivityLog::query()
            ->with(['user:id,name,email,phone,role'])
            ->latest('id');

        if ($search = $request->input('search')) {
            $query->search($search);
        }

        if ($module = $request->input('module')) {
            $query->forModule($module);
        }

        if ($action = $request->input('action')) {
            $query->forAction($action);
        }

        if ($userId = $request->input('user_id')) {
            $query->forUser($userId);
        }

        if ($level = $request->input('level')) {
            $query->where('level', $level);
        }

        if ($from = $request->input('from')) {
            $query->whereDate('created_at', '>=', $from);
        }

        if ($to = $request->input('to')) {
            $query->whereDate('created_at', '<=', $to);
        }

        $logs = $query->paginate((int) $request->input('per_page', 20))
            ->withQueryString()
            ->through(fn (ActivityLog $log) => $this->transform($log));

        $modules = ActivityLog::query()
            ->whereNotNull('module')
            ->distinct()
            ->orderBy('module')
            ->pluck('module');

        $actions = ActivityLog::query()
            ->distinct()
            ->orderBy('action')
            ->limit(100)
            ->pluck('action');

        $user = $request->user();

        return Inertia::render('backend/ActivityLogs/index', [
            'logs' => $logs,
            'filters' => $request->only([
                'search',
                'module',
                'action',
                'user_id',
                'level',
                'from',
                'to',
            ]),
            'modules' => $modules,
            'actions' => $actions,
            'can' => [
                'delete' => $user
                    ? ($user->can('deleteAny', ActivityLog::class)
                        || $this->userHasDeletePermission($user))
                    : false,
            ],
        ]);
    }

    /**
     * Show a single activity log entry.
     */
    public function show(Request $request, ActivityLog $activityLog): Response
    {
        $this->authorize('view', $activityLog);

        $activityLog->load(['user:id,name,email,phone,role']);

        $user = $request->user();

        return Inertia::render('backend/ActivityLogs/show', [
            'log' => $this->transform($activityLog, detailed: true),
            'can' => [
                'delete' => $user
                    ? ($user->can('delete', $activityLog)
                        || $this->userHasDeletePermission($user))
                    : false,
            ],
        ]);
    }

    /**
     * Explicit Spatie check — mirrors ActivityLogPolicy::canDelete.
     */
    private function userHasDeletePermission($user): bool
    {
        if ($user->isSuperAdmin()) {
            return true;
        }

        try {
            return $user->hasPermissionTo('delete activity logs', 'web')
                || $user->hasPermissionTo('delete activity logs');
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * Delete a single log (permission gated).
     */
    public function destroy(ActivityLog $activityLog): RedirectResponse
    {
        $this->authorize('delete', $activityLog);

        $activityLog->delete();

        return redirect()
            ->route('admin.activity-logs.index')
            ->with('success', 'Activity log deleted.');
    }

    /**
     * Bulk delete selected logs.
     */
    public function bulkDelete(Request $request): RedirectResponse
    {
        $this->authorize('deleteAny', ActivityLog::class);

        $request->validate([
            'ids' => 'required|array|min:1',
            'ids.*' => 'integer|exists:activity_logs,id',
        ]);

        ActivityLog::whereIn('id', $request->input('ids'))->delete();

        return back()->with('success', 'Selected activity logs deleted.');
    }

    /**
     * @return array<string, mixed>
     */
    private function transform(ActivityLog $log, bool $detailed = false): array
    {
        $data = [
            'id' => $log->id,
            'action' => $log->action,
            'action_label' => $log->action_label,
            'description' => $log->description,
            'module' => $log->module,
            'level' => $log->level,
            'level_color' => $log->level_color,
            'user' => $log->user ? [
                'id' => $log->user->id,
                'name' => $log->user->name,
                'email' => $log->user->email,
                'phone' => $log->user->phone,
                'role' => $log->user->role,
            ] : null,
            'subject_type' => $log->subject_type
                ? class_basename($log->subject_type)
                : null,
            'subject_id' => $log->subject_id,
            'ip_address' => $log->ip_address,
            'created_at' => $log->created_at?->toIso8601String(),
            'created_at_human' => $log->created_at?->diffForHumans(),
        ];

        if ($detailed) {
            $data['properties'] = $log->properties;
            $data['user_agent'] = $log->user_agent;
            $data['request_method'] = $log->request_method;
            $data['request_url'] = $log->request_url;
            $data['subject_type_full'] = $log->subject_type;
        }

        return $data;
    }
}
