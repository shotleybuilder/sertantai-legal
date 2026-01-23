/**
 * IndexedDB Storage Adapter for TanStack DB
 *
 * Provides an IndexedDB-backed storage that implements the same interface
 * as localStorage but with much larger capacity (~50% of available disk space).
 *
 * Uses idb-keyval for simple key-value storage in IndexedDB.
 */

import { get, set, del, createStore } from 'idb-keyval';

/**
 * Storage interface expected by TanStack DB's localStorageCollectionOptions
 */
export interface StorageInterface {
	getItem(key: string): string | null;
	setItem(key: string, value: string): void;
	removeItem(key: string): void;
}

/**
 * Async storage interface for IndexedDB
 */
export interface AsyncStorageInterface {
	getItem(key: string): Promise<string | null>;
	setItem(key: string, value: string): Promise<void>;
	removeItem(key: string): Promise<void>;
}

// Create a dedicated store for sertantai-legal
const customStore = createStore('sertantai-legal-db', 'collections');

/**
 * IndexedDB-backed async storage
 *
 * Note: This is async, but TanStack DB's localStorageCollectionOptions
 * expects sync storage. We use a memory cache to make it appear sync,
 * with async persistence in the background.
 */
class IndexedDBStorage implements StorageInterface {
	private cache: Map<string, string> = new Map();
	private initialized: boolean = false;
	private initPromise: Promise<void> | null = null;
	private pendingWrites: Map<string, Promise<void>> = new Map();

	// Debounce settings - only persist to IndexedDB after writes settle
	private writeDebounceTimers: Map<string, ReturnType<typeof setTimeout>> = new Map();
	private static WRITE_DEBOUNCE_MS = 1000; // Wait 1s after last write before persisting

	/**
	 * Initialize by loading all data from IndexedDB into memory cache
	 */
	async initialize(keys: string[]): Promise<void> {
		if (this.initialized) return;
		if (this.initPromise) return this.initPromise;

		this.initPromise = (async () => {
			for (const key of keys) {
				try {
					const value = await get<string>(key, customStore);
					if (value !== undefined) {
						this.cache.set(key, value);
					}
				} catch (error) {
					console.error(`[IDB Storage] Error loading key "${key}":`, error);
				}
			}
			this.initialized = true;
			console.log(`[IDB Storage] Initialized with ${this.cache.size} cached keys`);
		})();

		return this.initPromise;
	}

	getItem(key: string): string | null {
		return this.cache.get(key) ?? null;
	}

	setItem(key: string, value: string): void {
		// Update cache immediately (sync) - this is what TanStack DB reads from
		this.cache.set(key, value);

		// Cancel any pending write for this key
		const existingTimer = this.writeDebounceTimers.get(key);
		if (existingTimer) {
			clearTimeout(existingTimer);
		}

		// Debounce IndexedDB writes - only persist after writes settle
		// This prevents 600+ IndexedDB writes during bulk sync
		const timer = setTimeout(() => {
			this.writeDebounceTimers.delete(key);
			const currentValue = this.cache.get(key);
			if (currentValue !== undefined) {
				const writePromise = set(key, currentValue, customStore).catch((error) => {
					console.error(`[IDB Storage] Error persisting key "${key}":`, error);
				});
				this.pendingWrites.set(key, writePromise);
				writePromise.finally(() => {
					this.pendingWrites.delete(key);
				});
			}
		}, IndexedDBStorage.WRITE_DEBOUNCE_MS);

		this.writeDebounceTimers.set(key, timer);
	}

	removeItem(key: string): void {
		// Update cache immediately (sync)
		this.cache.delete(key);

		// Cancel any pending write for this key
		const existingTimer = this.writeDebounceTimers.get(key);
		if (existingTimer) {
			clearTimeout(existingTimer);
			this.writeDebounceTimers.delete(key);
		}

		// Persist deletion to IndexedDB in background (async)
		del(key, customStore).catch((error) => {
			console.error(`[IDB Storage] Error deleting key "${key}":`, error);
		});
	}

	/**
	 * Wait for all pending writes to complete
	 */
	async flush(): Promise<void> {
		// First, flush any debounced writes immediately
		for (const [key, timer] of this.writeDebounceTimers.entries()) {
			clearTimeout(timer);
			const currentValue = this.cache.get(key);
			if (currentValue !== undefined) {
				const writePromise = set(key, currentValue, customStore).catch((error) => {
					console.error(`[IDB Storage] Error persisting key "${key}":`, error);
				});
				this.pendingWrites.set(key, writePromise);
			}
		}
		this.writeDebounceTimers.clear();

		// Then wait for all writes to complete
		await Promise.all(this.pendingWrites.values());
	}

	/**
	 * Get approximate size of stored data in bytes
	 */
	getApproximateSize(): number {
		let size = 0;
		for (const value of this.cache.values()) {
			size += new Blob([value]).size;
		}
		return size;
	}
}

// Singleton instance
let idbStorage: IndexedDBStorage | null = null;

/**
 * Get the IndexedDB storage instance
 *
 * Must call initialize() before using getItem/setItem/removeItem
 */
export function getIDBStorage(): IndexedDBStorage {
	if (!idbStorage) {
		idbStorage = new IndexedDBStorage();
	}
	return idbStorage;
}

/**
 * Initialize the IndexedDB storage with specified keys
 *
 * @param keys - Storage keys to preload from IndexedDB
 */
export async function initializeIDBStorage(keys: string[]): Promise<StorageInterface> {
	const storage = getIDBStorage();
	await storage.initialize(keys);
	return storage;
}

// ============================================================================
// Electric Sync State Persistence
// ============================================================================

// Dedicated store for Electric sync metadata (separate from collection data)
// Use a SEPARATE database for sync metadata (idb-keyval can only have one store per DB)
const syncMetaStore = createStore('sertantai-legal-sync-meta', 'sync-state');

/**
 * Electric sync state that needs to persist across page reloads
 */
export interface ElectricSyncState {
	offset: string;
	handle?: string;
	lastSyncTime: string;
	recordCount: number;
}

/**
 * Save Electric sync state to IndexedDB
 *
 * Call this after each successful sync batch to enable resumable sync.
 */
export async function saveElectricSyncState(
	shapeKey: string,
	state: ElectricSyncState
): Promise<void> {
	try {
		await set(shapeKey, state, syncMetaStore);
		console.log(`[IDB Storage] Saved Electric sync state for "${shapeKey}":`, {
			offset: state.offset,
			recordCount: state.recordCount
		});
	} catch (error) {
		console.error(`[IDB Storage] Error saving Electric sync state:`, error);
	}
}

/**
 * Load Electric sync state from IndexedDB
 *
 * Call this on startup to get the offset for resumable sync.
 * Returns null if no previous sync state exists.
 */
export async function loadElectricSyncState(shapeKey: string): Promise<ElectricSyncState | null> {
	try {
		const state = await get<ElectricSyncState>(shapeKey, syncMetaStore);
		if (state) {
			console.log(`[IDB Storage] Loaded Electric sync state for "${shapeKey}":`, {
				offset: state.offset,
				recordCount: state.recordCount,
				lastSyncTime: state.lastSyncTime
			});
		}
		return state ?? null;
	} catch (error) {
		console.error(`[IDB Storage] Error loading Electric sync state:`, error);
		return null;
	}
}

/**
 * Clear Electric sync state (forces full re-sync on next load)
 */
export async function clearElectricSyncState(shapeKey: string): Promise<void> {
	try {
		await del(shapeKey, syncMetaStore);
		console.log(`[IDB Storage] Cleared Electric sync state for "${shapeKey}"`);
	} catch (error) {
		console.error(`[IDB Storage] Error clearing Electric sync state:`, error);
	}
}
