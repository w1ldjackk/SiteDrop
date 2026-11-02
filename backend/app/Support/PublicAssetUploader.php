<?php
// app/Support/PublicAssetUploader.php
//
// Single place for every upload coming from the apps.
// Files land in backend/public/assets/... (served directly, no storage:link
// needed) and the DB stores the public URL path (/assets/...).

namespace App\Support;

use Illuminate\Http\UploadedFile;

class PublicAssetUploader
{
    /**
     * Move an uploaded file into public/assets/{folder} and return its
     * public URL path (e.g. /assets/img/avatars/169..._abc123.jpg).
     */
    public static function put(UploadedFile $file, string $folder): string
    {
        $folder = trim($folder, '/');
        $targetDir = public_path('assets/'.$folder);
        if (! is_dir($targetDir)) {
            mkdir($targetDir, 0755, true);
        }

        $ext = $file->getClientOriginalExtension();
        $filename = time().'_'.uniqid().($ext ? '.'.$ext : '');
        $file->move($targetDir, $filename);

        return '/assets/'.$folder.'/'.$filename;
    }

    /**
     * Delete a previously stored file. Accepts:
     *  - new /assets/... URL paths,
     *  - legacy /storage/... URL paths (storage/app/public),
     *  - legacy storage-relative paths (e.g. avatars/x.jpg).
     */
    public static function delete(?string $urlOrPath): void
    {
        if ($urlOrPath === null || $urlOrPath === '') {
            return;
        }

        // Skip remote URLs (seeded placeholders, ui-avatars, ...).
        if (str_starts_with($urlOrPath, 'http://') || str_starts_with($urlOrPath, 'https://')) {
            return;
        }

        if (str_starts_with($urlOrPath, '/assets/')) {
            $path = public_path(ltrim($urlOrPath, '/'));
            if (is_file($path)) {
                @unlink($path);
            }

            return;
        }

        if (str_starts_with($urlOrPath, '/storage/')) {
            $path = storage_path('app/public/'.substr($urlOrPath, strlen('/storage/')));
            if (is_file($path)) {
                @unlink($path);
            }

            return;
        }

        // Legacy storage-relative path.
        $path = storage_path('app/public/'.ltrim($urlOrPath, '/'));
        if (is_file($path)) {
            @unlink($path);
        }
    }
}
