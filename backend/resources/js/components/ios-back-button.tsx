// resources/js/components/ios-back-button.tsx
import { Link, router } from '@inertiajs/react';
import { ChevronLeft } from 'lucide-react';
import { cn } from '@/lib/utils';

type Props = {
    href?: string;
    label?: string;
    className?: string;
    /** When true, uses browser/Inertia history instead of href */
    history?: boolean;
};

/**
 * iOS-style back control: chevron + label, pointer cursor, tap-friendly.
 */
export function IosBackButton({
    href,
    label = 'Back',
    className,
    history = false,
}: Props) {
    const classes = cn(
        'inline-flex cursor-pointer items-center gap-0.5 rounded-lg px-1.5 py-1.5',
        'text-[17px] font-normal text-primary',
        'transition-opacity hover:opacity-70 active:opacity-50',
        'focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40',
        className,
    );

    if (history) {
        return (
            <button
                type="button"
                onClick={() => {
                    if (typeof window !== 'undefined' && window.history.length > 1) {
                        window.history.back();
                    } else {
                        router.visit(href || '/admin');
                    }
                }}
                className={classes}
            >
                <ChevronLeft className="h-5 w-5 shrink-0" strokeWidth={2.5} />
                <span>{label}</span>
            </button>
        );
    }

    return (
        <Link href={href || '/admin'} className={classes}>
            <ChevronLeft className="h-5 w-5 shrink-0" strokeWidth={2.5} />
            <span>{label}</span>
        </Link>
    );
}

export default IosBackButton;
