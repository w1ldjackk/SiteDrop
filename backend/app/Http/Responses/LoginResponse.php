<?php

namespace App\Http\Responses;

use Illuminate\Http\JsonResponse;
use Laravel\Fortify\Contracts\LoginResponse as LoginResponseContract;

class LoginResponse implements LoginResponseContract
{
    public function toResponse($request)
    {
        $home = $request->user()?->homePath() ?? '/';

        return $request->wantsJson()
            ? new JsonResponse(['two_factor' => false, 'redirect' => $home], 200)
            : redirect()->intended($home);
    }
}
