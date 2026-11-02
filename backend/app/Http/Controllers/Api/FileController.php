<?php
// app/Http/Controllers/Api/FileController.php
//
// Public file serving with CORS headers.
//
// Files physically live in backend/public/assets/... (uploaded there by
// PublicAssetUploader), but `php artisan serve` streams static files
// directly WITHOUT Laravel middleware — so no CORS headers. Flutter web
// (CanvasKit) refuses to render such cross-origin images. This endpoint
// serves the same files through the API stack, which does send CORS.

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\BinaryFileResponse;

class FileController extends Controller
{
    public function show(Request $request, string $path): BinaryFileResponse|\Illuminate\Http\JsonResponse
    {
        $relative = ltrim($path, '/');

        if ($relative === '' || str_contains($relative, '..')) {
            return response()->json([
                'status' => 'error',
                'message' => 'File not found',
            ], 404);
        }

        // New uploads live here; legacy storage-disk files as fallback.
        $candidates = [
            public_path('assets/'.$relative),
            storage_path('app/public/'.$relative),
        ];

        foreach ($candidates as $candidate) {
            $real = realpath($candidate);
            if ($real === false || ! is_file($real)) {
                continue;
            }
            $allowed = [
                realpath(public_path('assets')) ?: public_path('assets'),
                realpath(storage_path('app/public')) ?: storage_path('app/public'),
            ];
            foreach ($allowed as $base) {
                if (str_starts_with($real, rtrim($base, DIRECTORY_SEPARATOR).DIRECTORY_SEPARATOR)) {
                    return response()->file($real)->withHeaders([
                        'Access-Control-Allow-Origin' => '*',
                        'Access-Control-Allow-Methods' => 'GET, OPTIONS',
                        'Access-Control-Allow-Headers' => 'Content-Type, Authorization',
                    ]);
                }
            }
        }

        return response()->json([
            'status' => 'error',
            'message' => 'File not found',
        ], 404);
    }
}
