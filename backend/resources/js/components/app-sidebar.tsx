// resources/js/components/app-sidebar.tsx
import { Link, usePage } from '@inertiajs/react';
import { ChevronDown } from 'lucide-react';
import { useMemo } from 'react';
import { NavFooter } from '@/components/nav-footer';
import { NavUser } from '@/components/nav-user';
import {
    Collapsible,
    CollapsibleContent,
    CollapsibleTrigger,
} from '@/components/ui/collapsible';
import {
    Sidebar,
    SidebarContent,
    SidebarFooter,
    SidebarGroup,
    SidebarGroupLabel,
    SidebarHeader,
    SidebarMenu,
    SidebarMenuButton,
    SidebarMenuItem,
    SidebarMenuSub,
    SidebarMenuSubButton,
    SidebarMenuSubItem,
} from '@/components/ui/sidebar';
import { usePermissions } from '@/hooks/usePermissions';
import { useRoleArea } from '@/hooks/use-role-area';
import {
    getFooterNavForArea,
    getNavSectionsForArea,
    type NavLink,
    type NavSection,
} from '@/lib/role-nav';
import { cn } from '@/lib/utils';
import type { NavItem } from '@/types';
import AppLogo from './app-logo';

function sectionHasActive(
    isActive: (href: string, exact?: boolean) => boolean,
    items: NavLink[],
): boolean {
    return items.some((item) => isActive(item.href, item.exact));
}

export function AppSidebar() {
    const page = usePage();
    const { canAny } = usePermissions();
    const { area, base, isActive } = useRoleArea();

    const visibleSections = useMemo(() => {
        const sections = getNavSectionsForArea(area);

        /** Admin area: gate by permissions. Other roles: show all area links. */
        if (area !== 'admin') {
            return sections;
        }

        const canSeeItem = (item: NavLink): boolean => {
            if (!item.permissions || item.permissions.length === 0) {
                return true;
            }
            return canAny(...item.permissions);
        };

        return sections
            .map((section: NavSection) => ({
                ...section,
                items: section.items.filter(canSeeItem),
            }))
            .filter((section) => section.items.length > 0);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [area, page.props]);

    const footerNavItems: NavItem[] = useMemo(
        () =>
            getFooterNavForArea(area).map((item) => ({
                title: item.title,
                href: item.href,
                icon: item.icon,
            })),
        [area],
    );

    return (
        <Sidebar collapsible="icon" variant="inset">
            <SidebarHeader>
                <SidebarMenu>
                    <SidebarMenuItem>
                        <SidebarMenuButton size="lg" asChild>
                            <Link
                                href={base}
                                prefetch
                                className="flex cursor-pointer items-center"
                            >
                                <AppLogo />
                                <span className="ml-2 font-semibold tracking-tight text-sidebar-foreground">
                                    SiteDrop
                                </span>
                            </Link>
                        </SidebarMenuButton>
                    </SidebarMenuItem>
                </SidebarMenu>
            </SidebarHeader>

            <SidebarContent>
                {visibleSections.map((section) => {
                    const open = sectionHasActive(isActive, section.items);

                    if (!section.collapsible) {
                        return (
                            <SidebarGroup key={section.title}>
                                <SidebarGroupLabel>
                                    {section.title}
                                </SidebarGroupLabel>
                                <SidebarMenu>
                                    {section.items.map((item) => {
                                        const active = isActive(
                                            item.href,
                                            item.exact,
                                        );
                                        const Icon = item.icon;
                                        return (
                                            <SidebarMenuItem key={item.href}>
                                                <SidebarMenuButton
                                                    asChild
                                                    isActive={active}
                                                    tooltip={item.title}
                                                    className={cn(
                                                        'cursor-pointer',
                                                        active &&
                                                            'bg-sidebar-accent text-sidebar-accent-foreground font-semibold',
                                                    )}
                                                >
                                                    <Link
                                                        href={item.href}
                                                        className="flex cursor-pointer items-center space-x-2"
                                                        preserveState={false}
                                                    >
                                                        <Icon
                                                            className={cn(
                                                                'h-5 w-5',
                                                                active &&
                                                                    'text-sidebar-primary',
                                                            )}
                                                        />
                                                        <span>
                                                            {item.title}
                                                        </span>
                                                    </Link>
                                                </SidebarMenuButton>
                                            </SidebarMenuItem>
                                        );
                                    })}
                                </SidebarMenu>
                            </SidebarGroup>
                        );
                    }

                    return (
                        <Collapsible
                            key={`${section.title}-${open ? 'on' : 'off'}-${area}`}
                            defaultOpen={
                                open ||
                                section.title === 'Operations' ||
                                section.title === 'Business' ||
                                section.title === 'Shopping' ||
                                section.title === 'Routes'
                            }
                            className={cn(
                                'group/collapsible',
                                section.title === 'System' &&
                                    'mt-4 border-t border-sidebar-border pt-3',
                            )}
                        >
                            <SidebarGroup>
                                <SidebarGroupLabel asChild>
                                    <CollapsibleTrigger
                                        className={cn(
                                            'flex w-full cursor-pointer items-center justify-between',
                                            open
                                                ? 'text-sidebar-accent-foreground'
                                                : 'text-muted-foreground hover:text-foreground',
                                        )}
                                    >
                                        {section.title}
                                        <ChevronDown className="h-4 w-4 transition-transform group-data-[state=open]/collapsible:rotate-180" />
                                    </CollapsibleTrigger>
                                </SidebarGroupLabel>
                                <CollapsibleContent>
                                    <SidebarMenu>
                                        <SidebarMenuSub>
                                            {section.items.map((item) => {
                                                const active = isActive(
                                                    item.href,
                                                    item.exact,
                                                );
                                                const Icon = item.icon;
                                                return (
                                                    <SidebarMenuSubItem
                                                        key={item.href}
                                                    >
                                                        <SidebarMenuSubButton
                                                            asChild
                                                            isActive={active}
                                                            className={cn(
                                                                'cursor-pointer',
                                                                active &&
                                                                    'bg-sidebar-accent text-sidebar-accent-foreground font-semibold',
                                                            )}
                                                        >
                                                            <Link
                                                                href={item.href}
                                                                className="flex cursor-pointer items-center space-x-2"
                                                                preserveState={
                                                                    false
                                                                }
                                                            >
                                                                <Icon
                                                                    className={cn(
                                                                        'h-4 w-4',
                                                                        active &&
                                                                            'text-sidebar-primary',
                                                                    )}
                                                                />
                                                                <span>
                                                                    {item.title}
                                                                </span>
                                                            </Link>
                                                        </SidebarMenuSubButton>
                                                    </SidebarMenuSubItem>
                                                );
                                            })}
                                        </SidebarMenuSub>
                                    </SidebarMenu>
                                </CollapsibleContent>
                            </SidebarGroup>
                        </Collapsible>
                    );
                })}
            </SidebarContent>

            <SidebarFooter>
                <NavFooter items={footerNavItems} className="mt-auto" />
                <NavUser />
            </SidebarFooter>
        </Sidebar>
    );
}
