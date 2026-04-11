/**
 * PGLite Singleton (Client-Only)
 *
 * Lazy-initialized PGLite instance backed by IndexedDB for persistent storage.
 * Uses the `live` extension for reactive queries and `electricSync` for
 * Electric shape-to-table sync.
 *
 * NOTE: Must only be called in the browser (SvelteKit client-side code).
 */

import { browser } from '$app/environment';
import { PGlite } from '@electric-sql/pglite';
import { live, type LiveNamespace } from '@electric-sql/pglite/live';
import { electricSync, type SyncNamespaceObj } from '@electric-sql/pglite-sync';

/** PGLite instance with live + electric extensions typed */
export type PGLiteWithExtensions = PGlite & {
	live: LiveNamespace;
	electric: SyncNamespaceObj;
};

let pgliteInstance: PGLiteWithExtensions | null = null;
let pglitePromise: Promise<PGLiteWithExtensions> | null = null;

/**
 * Get or create the PGLite singleton.
 * Uses IndexedDB (`idb://`) for persistent storage across sessions.
 * `relaxedDurability` returns query results immediately, flushing to IDB async.
 */
export async function getPglite(): Promise<PGLiteWithExtensions> {
	if (!browser) {
		throw new Error('PGLite can only be used in the browser');
	}

	if (pgliteInstance) return pgliteInstance;

	// Prevent concurrent initialization
	if (pglitePromise) return pglitePromise;

	pglitePromise = PGlite.create('idb://sertantai-legal', {
		extensions: {
			live,
			electric: electricSync()
		},
		relaxedDurability: true
	}).then((pg) => {
		pgliteInstance = pg as unknown as PGLiteWithExtensions;
		console.log('[PGLite] Initialized with IndexedDB storage');
		return pgliteInstance;
	});

	return pglitePromise;
}
