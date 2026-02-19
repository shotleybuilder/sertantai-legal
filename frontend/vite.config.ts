import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		host: '0.0.0.0',
		port: 5175
		// Note: Electric requests now go through Phoenix backend proxy (Gatekeeper pattern)
		// at http://localhost:4003/api/electric — no Vite proxy needed
	},
	ssr: {
		noExternal: ['@tanstack/svelte-query', 'svelte-table-views-sidebar']
	}
});
