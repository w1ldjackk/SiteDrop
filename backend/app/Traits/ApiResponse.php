<?php

namespace App\Traits;

use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;
use Illuminate\Pagination\AbstractPaginator;

/**
 * Standard JSON envelope used by mobile / API controllers.
 *
 * Shape:
 *   success → { status: "success", message?, data?, … }
 *   error   → { status: "error", message, … }
 */
trait ApiResponse
{
    /**
     * @param  array<string, mixed>|null  $data
     * @param  array<string, mixed>  $extra  Extra top-level keys (e.g. requires_verification)
     */
    protected function success(
        mixed $data = null,
        ?string $message = null,
        int $status = 200,
        array $extra = [],
    ): JsonResponse {
        $payload = array_merge(['status' => 'success'], $extra);

        if ($message !== null) {
            $payload['message'] = $message;
        }

        if ($data !== null) {
            $payload['data'] = $data;
        }

        return response()->json($payload, $status);
    }

    /**
     * @param  array<string, mixed>  $extra
     */
    protected function error(
        string $message,
        int $status = 400,
        array $extra = [],
    ): JsonResponse {
        return response()->json(array_merge([
            'status' => 'error',
            'message' => $message,
        ], $extra), $status);
    }

    /**
     * Pagination block shared by list endpoints (`pagination` or nested in `meta`).
     *
     * @return array{current_page: int, last_page: int, per_page: int, total: int}
     */
    protected function paginationMeta(LengthAwarePaginator|AbstractPaginator $paginator): array
    {
        return [
            'current_page' => $paginator->currentPage(),
            'last_page' => $paginator->lastPage(),
            'per_page' => $paginator->perPage(),
            'total' => $paginator->total(),
        ];
    }
}
