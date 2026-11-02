<?php

namespace App\Http\Responses;

use Illuminate\Http\JsonResponse;
use Laravel\Fortify\Contracts\RegisterResponse as RegisterResponseContract;

class RegisterResponse implements RegisterResponseContract
{
    public function toResponse($request)
    {
        $home = $request->user()?->homePath() ?? '/';

        return $request->wantsJson()
            ? new JsonResponse(['redirect' => $home], 201)
            : redirect()->intended($home);
    }
}
