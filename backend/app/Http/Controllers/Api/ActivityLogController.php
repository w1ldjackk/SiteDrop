<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\ActivityLog;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * API access to activity logs — restricted to admins or
 * users with "view activity logs" permission.
 */
class ActivityLogController extends Controller
{
    use AuthorizesRequests;

    public function index(Request $request): JsonResponse
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

        $perPage = min((int) $request->input('per_page', 20), 100);
        $logs = $query->paginate($perPage);

        return response()->json([
            'status' => 'success',
            'data' => [
                'logs' => $logs->items(),
                'pagination' => [
                    'current_page' => $logs->currentPage(),
                    'last_page' => $logs->lastPage(),
                    'per_page' => $logs->perPage(),
                    'total' => $logs->total(),
                ],
            ],
        ]);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $log = ActivityLog::with(['user:id,name,email,phone,role'])->findOrFail($id);
        $this->authorize('view', $log);

        return response()->json([
            'status' => 'success',
            'data' => $log,
        ]);
    }
}
