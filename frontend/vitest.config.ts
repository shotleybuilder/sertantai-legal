import { defineConfig } from 'vitest/config';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import path from 'path';

export default defineConfig({
	plugins: [svelte({ hot: !process.env.VITEST })],
	resolve: {
		alias: {
			$lib: path.resolve(__dirname, './src/lib'),
			$app: path.resolve(__dirname, './src/test/mocks/app')
		}
	},
	test: {
		globals: true,
		environment: 'jsdom',
		setupFiles: ['./src/test/setup.ts'],
		include: ['src/**/*.{test,spec}.{js,ts}'],
		coverage: {
			reporter: ['text', 'html'],
			exclude: ['node_modules/', 'src/test/', '**/*.d.ts', '**/*.config.*', '**/dist/**']
		}
	}
});
