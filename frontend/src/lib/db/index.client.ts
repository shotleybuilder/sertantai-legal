/**
 * TanStack DB Collections (Client-Only)
 *
 * Creates reactive collections for UK LRT data.
 * Collections provide:
 * - IndexedDB persistence (handles 19k+ records without quota issues)
 * - Reactive queries that auto-update
 * - Optimistic mutations
 *
 * NOTE: This module uses dynamic imports to ensure it only runs in the browser.
 * DO NOT import collections directly - use the exported functions instead.
 */

import { browser } from '$app/environment';
import type { UkLrtRecord } from '$lib/electric/uk-lrt-schema';
import type { Collection } from '@tanstack/db';
import { initializeIDBStorage } from './idb-storage';

// Storage key for UK LRT collection
const UK_LRT_STORAGE_KEY = 'sertantai-legal-uk-lrt';

// Collection singleton (initialized lazily in browser)
let ukLrtCol: Collection<UkLrtRecord, string> | null = null;

/**
 * Initialize collections (browser only)
 *
 * Uses IndexedDB via a custom storage adapter to handle large datasets
 * that exceed localStorage's ~5MB limit.
 */
async function ensureCollections() {
	if (!browser) {
		throw new Error('TanStack DB collections can only be initialized in the browser');
	}

	if (ukLrtCol) {
		return; // Already initialized
	}

	// Initialize IndexedDB storage first
	const idbStorage = await initializeIDBStorage([UK_LRT_STORAGE_KEY]);

	const { createCollection, localStorageCollectionOptions } = await import('@tanstack/db');

	ukLrtCol = createCollection(
		localStorageCollectionOptions<UkLrtRecord, string>({
			storageKey: UK_LRT_STORAGE_KEY,
			getKey: (item) => item.id,
			// Use IndexedDB-backed storage instead of localStorage
			storage: idbStorage
		})
	);

	console.log('[TanStack DB] UK LRT collection initialized with IndexedDB storage');
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
		storage: 'IndexedDB'
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
