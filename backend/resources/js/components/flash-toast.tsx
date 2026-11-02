import { usePage } from '@inertiajs/react';
import { useEffect, useState } from 'react';
import { cn } from '@/lib/utils';
import type { SharedData } from '@/types';

/**
 * Renders session flash messages (success / error) after Inertia redirects.
 * Controllers already flash these; they were never shared to the client before.
 */
export function FlashToast() {
    const { flash } = usePage<SharedData>().props;
    const [visible, setVisible] = useState<{
        type: 'success' | 'error';
        message: string;
    } | null>(null);

    useEffect(() => {
        if (flash?.success) {
            setVisible({ type: 'success', message: String(flash.success) });
        } else if (flash?.error) {
            setVisible({ type: 'error', message: String(flash.error) });
        } else {
            setVisible(null);
            return;
        }

        const timer = window.setTimeout(() => setVisible(null), 4500);
        return () => window.clearTimeout(timer);
    }, [flash?.success, flash?.error]);

    if (!visible) {
        return null;
    }

    return (
        <div
            role="status"
            className={cn(
                'fixed right-4 bottom-4 z-[100] max-w-sm rounded-lg border px-4 py-3 text-sm shadow-lg',
                visible.type === 'success'
                    ? 'border-emerald-200 bg-emerald-50 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950 dark:text-emerald-100'
                    : 'border-red-200 bg-red-50 text-red-900 dark:border-red-800 dark:bg-red-950 dark:text-red-100',
            )}
        >
            <div className="flex items-start justify-between gap-3">
                <p>{visible.message}</p>
                <button
                    type="button"
                    className="cursor-pointer opacity-70 hover:opacity-100"
                    onClick={() => setVisible(null)}
                    aria-label="Dismiss"
                >
                    ×
                </button>
            </div>
        </div>
    );
}
