import { createInertiaApp } from '@inertiajs/react';
import createServer from '@inertiajs/react/server';
import { resolvePageComponent } from 'laravel-vite-plugin/inertia-helpers';
import ReactDOMServer from 'react-dom/server';

const appName = import.meta.env.VITE_APP_NAME || 'Laravel';

createServer((page) =>
    createInertiaApp({
        page,
        render: ReactDOMServer.renderToString,
        title: (title) => (title ? `${title} - ${appName}` : appName),
        resolve: (name) => {
            const pages = import.meta.glob('./pages/**/*.{tsx,jsx}');

            return resolvePageComponent(
                [
                    `./pages/${name}.tsx`,
                    `./pages/${name}.jsx`,
                    `./pages/${name}/index.tsx`,
                    `./pages/${name}/index.jsx`,
                ],
                pages,
            );
        },
        setup: ({ App, props }) => {
            return <App {...props} />;
        },
    }),
);
