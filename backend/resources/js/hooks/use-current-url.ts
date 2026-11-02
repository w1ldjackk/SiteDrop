import type { InertiaLinkProps } from '@inertiajs/react';
import { usePage } from '@inertiajs/react';
import { toUrl } from '@/lib/utils';

export type IsCurrentUrlFn = (
    urlToCheck: NonNullable<InertiaLinkProps['href']>,
    currentUrl?: string,
) => boolean;

export type WhenCurrentUrlFn = <TIfTrue, TIfFalse = null>(
    urlToCheck: NonNullable<InertiaLinkProps['href']>,
    ifTrue: TIfTrue,
    ifFalse?: TIfFalse,
) => TIfTrue | TIfFalse;

export type UseCurrentUrlReturn = {
    currentUrl: string;
    isCurrentUrl: IsCurrentUrlFn;
    whenCurrentUrl: WhenCurrentUrlFn;
};

function pathnameOf(url: string): string {
    try {
        if (url.startsWith('http://') || url.startsWith('https://')) {
            return new URL(url).pathname.replace(/\/+$/, '') || '/';
        }
        return (url.split('?')[0].split('#')[0] || '/').replace(/\/+$/, '') || '/';
    } catch {
        return url.split('?')[0] || '/';
    }
}

export function useCurrentUrl(): UseCurrentUrlReturn {
    const page = usePage();
    const currentUrlPath = pathnameOf(
        typeof window !== 'undefined'
            ? window.location.pathname
            : page.url || '/',
    );

    const isCurrentUrl: IsCurrentUrlFn = (
        urlToCheck: NonNullable<InertiaLinkProps['href']>,
        currentUrl?: string,
    ) => {
        const urlToCompare = pathnameOf(currentUrl ?? currentUrlPath);
        const urlString = toUrl(urlToCheck);
        const target = pathnameOf(urlString);

        // Exact path, or nested child (e.g. /admin/users/1 under /admin/users)
        return (
            target === urlToCompare ||
            (target !== '/' && urlToCompare.startsWith(`${target}/`))
        );
    };

    const whenCurrentUrl: WhenCurrentUrlFn = <TIfTrue, TIfFalse = null>(
        urlToCheck: NonNullable<InertiaLinkProps['href']>,
        ifTrue: TIfTrue,
        ifFalse: TIfFalse = null as TIfFalse,
    ): TIfTrue | TIfFalse => {
        return isCurrentUrl(urlToCheck) ? ifTrue : ifFalse;
    };

    return {
        currentUrl: currentUrlPath,
        isCurrentUrl,
        whenCurrentUrl,
    };
}
