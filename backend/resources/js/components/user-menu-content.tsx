import { Link, router, usePage } from '@inertiajs/react';
import { LogOut, Settings } from 'lucide-react';
import {
    DropdownMenuGroup,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
} from '@/components/ui/dropdown-menu';
import { UserInfo } from '@/components/user-info';
import { useMobileNavigation } from '@/hooks/use-mobile-navigation';
import { logout } from '@/routes';
import type { SharedData, User } from '@/types';

type Props = {
    user: User;
};

/**
 * Settings live under the role area:
 * /admin/settings/profile, /buyer/settings/profile, …
 */
function settingsHrefFromAuth(auth: SharedData['auth']): string {
    if (auth.settings_path) {
        return auth.settings_path;
    }

    const path = typeof window !== 'undefined' ? window.location.pathname : '';
    const match = path.match(/^\/(admin|buyer|seller|driver)(?:\/|$)/);
    if (match) {
        return `/${match[1]}/settings/profile`;
    }

    const role = (auth.role ?? auth.user?.role ?? 'buyer')
        .toString()
        .toLowerCase()
        .replace(/[_\s]+/g, '-');

    if (
        role === 'admin' ||
        role === 'super-admin' ||
        role === 'ops-manager'
    ) {
        return '/admin/settings/profile';
    }

    if (role === 'seller' || role === 'driver' || role === 'buyer') {
        return `/${role}/settings/profile`;
    }

    return '/buyer/settings/profile';
}

export function UserMenuContent({ user }: Props) {
    const cleanup = useMobileNavigation();
    const { auth } = usePage<SharedData>().props;
    const settingsHref = settingsHrefFromAuth(auth);

    const handleLogout = () => {
        cleanup();
        router.flushAll();
    };

    return (
        <>
            <DropdownMenuLabel className="p-0 font-normal">
                <div className="flex items-center gap-2 px-1 py-1.5 text-left text-sm">
                    <UserInfo user={user} showEmail={true} />
                </div>
            </DropdownMenuLabel>
            <DropdownMenuSeparator />
            <DropdownMenuGroup>
                <DropdownMenuItem asChild>
                    <Link
                        className="block w-full cursor-pointer"
                        href={settingsHref}
                        prefetch
                        onClick={cleanup}
                    >
                        <Settings className="mr-2" />
                        Settings
                    </Link>
                </DropdownMenuItem>
            </DropdownMenuGroup>
            <DropdownMenuSeparator />
            <DropdownMenuItem asChild>
                <Link
                    className="block w-full cursor-pointer"
                    href={logout()}
                    as="button"
                    onClick={handleLogout}
                    data-test="logout-button"
                >
                    <LogOut className="mr-2" />
                    Log out
                </Link>
            </DropdownMenuItem>
        </>
    );
}
