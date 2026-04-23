// Vitest test setup file
import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/svelte';

// Node 25+ ships a built-in localStorage global that is a stub without
// .clear() when --localstorage-file is not set. This overrides jsdom's
// full localStorage implementation, breaking tests. Force jsdom's version.
if (typeof globalThis.localStorage?.clear !== 'function') {
	const store = new Map<string, string>();
	const storage: Storage = {
		getItem: (key: string) => store.get(key) ?? null,
		setItem: (key: string, value: string) => store.set(key, String(value)),
		removeItem: (key: string) => store.delete(key),
		clear: () => store.clear(),
		key: (index: number) => [...store.keys()][index] ?? null,
		get length() {
			return store.size;
		}
	};
	Object.defineProperty(globalThis, 'localStorage', { value: storage, writable: true });
}

// Cleanup after each test
afterEach(() => {
	cleanup();
});

// Add custom matchers if needed
expect.extend({});
