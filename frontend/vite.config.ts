import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		host: '0.0.0.0',
		port: 5175,
		proxy: {
			'/electric': {
				target: 'http://localhost:3002',
				rewrite: (path) => path.replace(/^\/electric/, '')
			}
		}
	},
	ssr: {
		noExternal: ['@tanstack/svelte-query', 'svelte-table-views-sidebar']
	}
});
