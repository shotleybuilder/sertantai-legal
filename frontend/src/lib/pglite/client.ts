/**
 * PGLite Singleton (Client-Only)
 *
 * Lazy-initialized PGLite instance backed by IndexedDB for persistent storage.
 * Uses the `live` extension for reactive queries and `electricSync` for
 * Electric shape-to-table sync.
 *
 * The IndexedDB store is scoped per user (from JWT sub claim) to prevent
 * collisions when multiple users share the same browser origin (#106).
 *
 * NOTE: Must only be called in the browser (SvelteKit client-side code).
 */

import { browser } from '$app/environment';
import { PGlite } from '@electric-sql/pglite';
import { live, type LiveNamespace } from '@electric-sql/pglite/live';
import { electricSync, type SyncNamespaceObj } from '@electric-sql/pglite-sync';
import { getAuthToken } from '$lib/stores/auth';

/** PGLite instance with live + electric extensions typed */
export type PGLiteWithExtensions = PGlite & {
	live: LiveNamespace;
	electric: SyncNamespaceObj;
};

let pgliteInstance: PGLiteWithExtensions | null = null;
let pglitePromise: Promise<PGLiteWithExtensions> | null = null;
let currentDbName: string | null = null;

/**
 * Extract a short user identifier from the JWT for IndexedDB naming.
 * Falls back to 'anon' if no token is available.
 */
function getUserSlug(): string {
	const token = getAuthToken();
	if (!token) return 'anon';
	try {
		const payload = token.split('.')[1];
		const decoded = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
		// Use org_id if available (most meaningful isolation), else user sub
		if (decoded.org_id) return decoded.org_id.slice(0, 8);
		if (decoded.sub) {
			const match = decoded.sub.match(/id=([a-f0-9-]+)/);
			if (match) return match[1].slice(0, 8);
		}
		return 'anon';
	} catch {
		return 'anon';
	}
}

/**
 * Get or create the PGLite singleton.
 * Uses IndexedDB (`idb://`) for persistent storage across sessions.
 * Store name includes user/org slug to isolate per-user (#106).
 * `relaxedDurability` returns query results immediately, flushing to IDB async.
 */
export async function getPglite(): Promise<PGLiteWithExtensions> {
	if (!browser) {
		throw new Error('PGLite can only be used in the browser');
	}

	const slug = getUserSlug();
	const dbName = `idb://sertantai-legal-${slug}`;

	// If user changed (different slug), close old instance and create new
	if (pgliteInstance && currentDbName && currentDbName !== dbName) {
		console.log(`[PGLite] User changed (${currentDbName} → ${dbName}), closing old instance`);
		try {
			await pgliteInstance.close();
		} catch {
			// May already be closed
		}
		pgliteInstance = null;
		pglitePromise = null;
		currentDbName = null;
	}

	if (pgliteInstance) return pgliteInstance;

	// Prevent concurrent initialization
	if (pglitePromise) return pglitePromise;

	pglitePromise = PGlite.create(dbName, {
		extensions: {
			live,
			electric: electricSync()
		},
		relaxedDurability: true
	}).then((pg) => {
		pgliteInstance = pg as unknown as PGLiteWithExtensions;
		currentDbName = dbName;
		console.log(`[PGLite] Initialized: ${dbName}`);
		return pgliteInstance;
	});

	return pglitePromise;
}
