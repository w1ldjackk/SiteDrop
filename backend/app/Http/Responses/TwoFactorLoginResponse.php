<?php

namespace App\Http\Responses;

use Illuminate\Http\JsonResponse;
use Laravel\Fortify\Contracts\TwoFactorLoginResponse as TwoFactorLoginResponseContract;

class TwoFactorLoginResponse implements TwoFactorLoginResponseContract
{
    public function toResponse($request)
    {
        $home = $request->user()?->homePath() ?? '/';

        return $request->wantsJson()
            ? new JsonResponse(['redirect' => $home], 204)
            : redirect()->intended($home);
    }
}
