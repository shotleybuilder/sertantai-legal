import js from '@eslint/js';
import tseslint from '@typescript-eslint/eslint-plugin';
import tsparser from '@typescript-eslint/parser';
import svelte from 'eslint-plugin-svelte';
import svelteParser from 'svelte-eslint-parser';

const browserGlobals = {
	// Core
	fetch: 'readonly',
	console: 'readonly',
	window: 'readonly',
	document: 'readonly',
	navigator: 'readonly',
	localStorage: 'readonly',
	sessionStorage: 'readonly',
	// Timers
	setTimeout: 'readonly',
	clearTimeout: 'readonly',
	setInterval: 'readonly',
	clearInterval: 'readonly',
	requestAnimationFrame: 'readonly',
	cancelAnimationFrame: 'readonly',
	// DOM types
	URL: 'readonly',
	URLSearchParams: 'readonly',
	Headers: 'readonly',
	Request: 'readonly',
	RequestInfo: 'readonly',
	RequestInit: 'readonly',
	Response: 'readonly',
	EventSource: 'readonly',
	CustomEvent: 'readonly',
	KeyboardEvent: 'readonly',
	MouseEvent: 'readonly',
	HTMLElement: 'readonly',
	HTMLInputElement: 'readonly',
	HTMLSelectElement: 'readonly',
	Event: 'readonly',
	// Dialogs
	alert: 'readonly',
	confirm: 'readonly',
	prompt: 'readonly',
	// Other
	AbortController: 'readonly',
	FormData: 'readonly',
	Blob: 'readonly',
	File: 'readonly',
	TextEncoder: 'readonly',
	TextDecoder: 'readonly',
	structuredClone: 'readonly',
	crypto: 'readonly',
	performance: 'readonly',
	location: 'readonly',
	history: 'readonly',
	atob: 'readonly',
	btoa: 'readonly'
};

export default [
	js.configs.recommended,
	{
		files: ['**/*.ts', '**/*.svelte'],
		languageOptions: {
			parser: tsparser,
			parserOptions: {
				ecmaVersion: 2022,
				sourceType: 'module',
				extraFileExtensions: ['.svelte']
			},
			globals: browserGlobals
		},
		plugins: {
			'@typescript-eslint': tseslint
		},
		rules: {
			...tseslint.configs.recommended.rules,
			'@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }],
			'@typescript-eslint/no-explicit-any': 'warn',
			'@typescript-eslint/explicit-module-boundary-types': 'off'
		}
	},
	{
		files: ['**/*.svelte'],
		languageOptions: {
			parser: svelteParser,
			parserOptions: {
				parser: tsparser,
				ecmaVersion: 2022,
				sourceType: 'module'
			},
			globals: browserGlobals
		},
		plugins: {
			svelte
		},
		rules: {
			...svelte.configs.recommended.rules,
			'svelte/no-at-html-tags': 'error',
			'svelte/no-target-blank': 'error',
			'svelte/valid-compile': 'error'
		}
	},
	{
		files: ['**/*.config.ts', '**/*.config.js'],
		languageOptions: {
			globals: {
				// Node.js globals for config files
				process: 'readonly',
				__dirname: 'readonly',
				__filename: 'readonly',
				module: 'readonly',
				require: 'readonly'
			}
		}
	},
	{
		files: ['tests/**/*.ts', 'tests/**/*.js'],
		languageOptions: {
			globals: {
				process: 'readonly'
			}
		}
	},
	{
		ignores: ['.svelte-kit/**', 'build/**', 'dist/**', 'node_modules/**', '*.cjs']
	}
];
