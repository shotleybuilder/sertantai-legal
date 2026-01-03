/**
 * TanStack DB Collections (Client-Only)
 *
 * Creates reactive collections for UK LRT data.
 * Collections provide:
 * - Local storage with localStorage persistence
 * - Reactive queries that auto-update
 * - Optimistic mutations
 *
 * NOTE: This module uses dynamic imports to ensure it only runs in the browser.
 * DO NOT import collections directly - use the exported functions instead.
 */

import { browser } from '$app/environment';
import type { UkLrtRecord } from '$lib/electric/uk-lrt-schema';
import type { Collection } from '@tanstack/db';

// Collection singleton (initialized lazily in browser)
let ukLrtCol: Collection<UkLrtRecord, string> | null = null;

/**
 * Initialize collections (browser only)
 */
async function ensureCollections() {
	if (!browser) {
		throw new Error('TanStack DB collections can only be initialized in the browser');
	}

	if (ukLrtCol) {
		return; // Already initialized
	}

	const { createCollection, localStorageCollectionOptions } = await import('@tanstack/db');

	ukLrtCol = createCollection(
		localStorageCollectionOptions<UkLrtRecord, string>({
			storageKey: 'sertantai-legal-uk-lrt',
			getKey: (item) => item.id
		})
	);
}

/**
 * Get UK LRT collection (browser only)
 */
export async function getUkLrtCollection(): Promise<Collection<UkLrtRecord, string>> {
	await ensureCollections();
	return ukLrtCol!;
}

/**
 * Initialize all collections
 */
export async function initDB(): Promise<void> {
	if (!browser) {
		console.warn('[TanStack DB] initDB called on server - skipping');
		return;
	}

	try {
		await ensureCollections();
		console.log('[TanStack DB] Collections initialized successfully');
	} catch (error) {
		console.error('[TanStack DB] Failed to initialize collections:', error);
		throw error;
	}
}

/**
 * Get database status
 */
export function getDBStatus() {
	if (!browser) {
		return {
			initialized: false,
			collections: {},
			storage: 'N/A (SSR)'
		};
	}

	const initialized = ukLrtCol !== null;

	return {
		initialized,
		collections: initialized
			? {
					ukLrt: ukLrtCol!.id
				}
			: {},
		storage: 'localStorage'
	};
}

/**
 * Clear all collections (useful for testing/debugging)
 *
 * WARNING: This will delete all local data!
 */
export async function clearDB(): Promise<void> {
	if (!browser) {
		console.warn('[TanStack DB] clearDB called on server - skipping');
		return;
	}

	try {
		await ensureCollections();

		// Get all keys and delete them
		const keys = Array.from(ukLrtCol!.keys());
		for (const key of keys) {
			ukLrtCol!.delete(key);
		}

		console.log('[TanStack DB] Collections cleared');
	} catch (error) {
		console.error('[TanStack DB] Failed to clear collections:', error);
		throw error;
	}
}
