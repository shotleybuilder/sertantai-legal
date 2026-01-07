/**
 * ElectricSQL Sync for UK LRT
 *
 * Connects ElectricSQL's HTTP Shape API with TanStack DB collection
 * to provide real-time sync from PostgreSQL to the client.
 *
 * Supports dynamic WHERE clauses for query-based shape syncing.
 */

import { ShapeStream, type Offset } from '@electric-sql/client';
import { getUkLrtCollection } from '$lib/db/index.client';
import {
	saveElectricSyncState,
	loadElectricSyncState,
	clearElectricSyncState,
	type ElectricSyncState
} from '$lib/db/idb-storage';
import { type UkLrtRecord, transformUkLrtRecord } from './uk-lrt-schema';
import { writable, get } from 'svelte/store';

// Shape key for sync state persistence
const UK_LRT_SHAPE_KEY = 'uk-lrt-shape';

/**
 * Electric service configuration
 */
const ELECTRIC_URL =
	import.meta.env.VITE_ELECTRIC_URL ||
	import.meta.env.PUBLIC_ELECTRIC_URL ||
	'http://localhost:3002';

/**
 * Get default WHERE clause (last 3 years)
 */
function getDefaultWhere(): string {
	const currentYear = new Date().getFullYear();
	return `year >= ${currentYear - 2}`;
}

/**
 * Sync status
 */
export interface SyncStatus {
	connected: boolean;
	syncing: boolean;
	offline: boolean;
	recordCount: number;
	lastSyncTime: Date | null;
	error: string | null;
	whereClause: string;
	reconnectAttempts: number;
}

// Reactive sync status store
export const syncStatus = writable<SyncStatus>({
	connected: false,
	syncing: false,
	offline: false,
	recordCount: 0,
	lastSyncTime: null,
	error: null,
	whereClause: '',
	reconnectAttempts: 0
});

// Active subscription
let activeSubscription: (() => void) | null = null;
let currentStream: ShapeStream<Record<string, unknown>> | null = null;
let reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
let currentWhereClause: string = '';

// Reconnection settings
const MAX_RECONNECT_ATTEMPTS = 5;
const RECONNECT_DELAY_MS = 3000;

// Debounce settings for WHERE clause updates
const WHERE_DEBOUNCE_MS = 500;
let whereDebounceTimeout: ReturnType<typeof setTimeout> | null = null;

/**
 * Generate a shape key that includes the WHERE clause
 * Different WHERE clauses need separate sync states
 */
function getShapeKey(whereClause: string): string {
	// Create a simple hash of the WHERE clause
	const hash = whereClause.split('').reduce((acc, char) => {
		return ((acc << 5) - acc + char.charCodeAt(0)) | 0;
	}, 0);
	return `${UK_LRT_SHAPE_KEY}-${hash}`;
}

/**
 * Start syncing UK LRT collection with optional WHERE clause
 *
 * Uses persisted Electric offset to enable delta sync - only downloads
 * changes since last sync rather than full dataset every time.
 *
 * @param whereClause - SQL WHERE clause for filtering (e.g., "year >= 2024")
 * @param isReconnect - Whether this is a reconnection attempt
 * @param clearData - Whether to clear existing data (default: false for performance)
 */
export async function syncUkLrt(whereClause?: string, isReconnect = false, clearData = false) {
	const where = whereClause || getDefaultWhere();
	currentWhereClause = where;

	// Stop existing sync if running (but preserve reconnect state)
	stopUkLrtSync(isReconnect);

	try {
		syncStatus.update((s) => ({
			...s,
			syncing: true,
			offline: false,
			error: null,
			whereClause: where,
			reconnectAttempts: isReconnect ? s.reconnectAttempts : 0
		}));

		// Get the UK LRT collection (browser only)
		const ukLrtCollection = await getUkLrtCollection();

		// Only clear existing data if explicitly requested
		// This allows the new shape to merge with existing data for better UX
		if (clearData) {
			const existingKeys = Array.from(ukLrtCollection.keys());
			for (const key of existingKeys) {
				ukLrtCollection.delete(key);
			}
			// Also clear the sync state since we're starting fresh
			await clearElectricSyncState(getShapeKey(where));
		}

		// Load saved sync state for resumable delta sync
		const shapeKey = getShapeKey(where);
		const savedState = await loadElectricSyncState(shapeKey);

		// Build ShapeStream options with offset if we have prior sync state
		const streamOptions: {
			url: string;
			params: { table: string; where: string };
			offset?: Offset;
			handle?: string;
		} = {
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'uk_lrt',
				where
			}
		};

		// Safety check: if we have a saved offset but the collection is empty,
		// the data was likely cleared (browser storage reset). Do a fresh sync.
		const currentCollectionSize = ukLrtCollection.size;
		const shouldUseOffset = savedState?.offset && currentCollectionSize > 0;

		if (shouldUseOffset) {
			// Cast the stored offset string to the Offset type
			// Electric's Offset is a branded string type: `-1` | `now` | `${number}_${number}`
			streamOptions.offset = savedState!.offset as Offset;
			if (savedState!.handle) {
				streamOptions.handle = savedState!.handle;
			}
			console.log(
				`[Electric Sync] Resuming UK LRT sync from offset ${savedState!.offset} (${currentCollectionSize} local records)`
			);
		} else {
			// Clear stale offset if collection is empty but offset exists
			if (savedState?.offset && currentCollectionSize === 0) {
				console.log(
					`[Electric Sync] Clearing stale offset - collection is empty but offset ${savedState.offset} exists`
				);
				await clearElectricSyncState(shapeKey);
			}
			console.log(`[Electric Sync] Starting fresh UK LRT sync with WHERE: ${where}`);
		}

		// Create shape stream with optional offset for delta sync
		currentStream = new ShapeStream<Record<string, unknown>>(streamOptions);

		// Track latest offset for persistence
		let latestOffset: string | undefined;
		let latestHandle: string | undefined;

		// Subscribe to shape changes
		activeSubscription = currentStream.subscribe((messages) => {
			console.log(`[Electric Sync] Received ${messages.length} UK LRT updates`);

			let insertCount = 0;
			let updateCount = 0;
			let deleteCount = 0;

			messages.forEach((msg: any) => {
				// Track offset from each message for persistence
				if (msg.offset) {
					latestOffset = msg.offset;
				}
				if (msg.headers?.handle) {
					latestHandle = msg.headers.handle;
				}

				// Skip control messages
				if (msg.headers?.control) {
					console.log('[Electric Sync] Control message:', msg.headers.control);

					// On "up-to-date" control message, persist the sync state
					if (msg.headers.control === 'up-to-date' && latestOffset) {
						const recordCount = ukLrtCollection.size;
						saveElectricSyncState(shapeKey, {
							offset: latestOffset,
							handle: latestHandle,
							lastSyncTime: new Date().toISOString(),
							recordCount
						});
					}
					return;
				}

				const operation = msg.headers?.operation;
				const rawData = msg.value;

				if (!operation || !rawData) {
					return;
				}

				try {
					const data = transformUkLrtRecord(rawData);

					switch (operation) {
						case 'insert':
							// Use upsert logic: if record exists (from cached IndexedDB), update it
							if (ukLrtCollection.has(data.id)) {
								ukLrtCollection.update(data.id, (draft) => {
									Object.assign(draft, data);
								});
								updateCount++;
							} else {
								ukLrtCollection.insert(data);
								insertCount++;
							}
							break;

						case 'update':
							// Handle case where update arrives for non-existent record (insert it)
							if (ukLrtCollection.has(data.id)) {
								ukLrtCollection.update(data.id, (draft) => {
									Object.assign(draft, data);
								});
								updateCount++;
							} else {
								ukLrtCollection.insert(data);
								insertCount++;
							}
							break;

						case 'delete':
							if (ukLrtCollection.has(data.id)) {
								ukLrtCollection.delete(data.id);
								deleteCount++;
							}
							break;
					}
				} catch (error) {
					console.error('[Electric Sync] Error processing UK LRT message:', error, msg);
				}
			});

			if (insertCount > 0 || updateCount > 0 || deleteCount > 0) {
				console.log(
					`[Electric Sync] Processed: ${insertCount} inserts, ${updateCount} updates, ${deleteCount} deletes`
				);
			}

			// Update sync status
			const recordCount = ukLrtCollection.size;
			syncStatus.update((s) => ({
				...s,
				connected: true,
				syncing: false,
				offline: false,
				recordCount,
				lastSyncTime: new Date(),
				reconnectAttempts: 0
			}));
		});

		console.log('[Electric Sync] UK LRT sync started');
	} catch (error) {
		console.error('[Electric Sync] Failed to start UK LRT sync:', error);
		handleSyncError(error);
	}
}

/**
 * Handle sync errors and attempt reconnection
 */
function handleSyncError(error: unknown) {
	const errorMessage = error instanceof Error ? error.message : 'Unknown error';
	const currentStatus = get(syncStatus);

	// Check if we should attempt reconnection
	if (currentStatus.reconnectAttempts < MAX_RECONNECT_ATTEMPTS) {
		const nextAttempt = currentStatus.reconnectAttempts + 1;
		console.log(
			`[Electric Sync] Connection failed, attempting reconnect ${nextAttempt}/${MAX_RECONNECT_ATTEMPTS} in ${RECONNECT_DELAY_MS}ms`
		);

		syncStatus.update((s) => ({
			...s,
			syncing: false,
			offline: true,
			error: `Connection lost. Reconnecting (${nextAttempt}/${MAX_RECONNECT_ATTEMPTS})...`,
			reconnectAttempts: nextAttempt
		}));

		// Schedule reconnection
		reconnectTimeout = setTimeout(() => {
			syncUkLrt(currentWhereClause, true);
		}, RECONNECT_DELAY_MS);
	} else {
		// Max reconnect attempts reached
		console.error('[Electric Sync] Max reconnection attempts reached');
		syncStatus.update((s) => ({
			...s,
			syncing: false,
			offline: true,
			connected: false,
			error: `Connection failed: ${errorMessage}. Click retry to reconnect.`
		}));
	}
}

/**
 * Stop UK LRT sync
 * @param preserveReconnectState - If true, don't reset reconnect attempts (used during reconnection)
 */
export function stopUkLrtSync(preserveReconnectState = false) {
	// Clear reconnect timeout if pending
	if (reconnectTimeout) {
		clearTimeout(reconnectTimeout);
		reconnectTimeout = null;
	}

	// Clear debounce timeout if pending
	if (whereDebounceTimeout) {
		clearTimeout(whereDebounceTimeout);
		whereDebounceTimeout = null;
	}

	if (activeSubscription) {
		activeSubscription();
		activeSubscription = null;
		console.log('[Electric Sync] UK LRT sync stopped');
	}
	currentStream = null;

	if (!preserveReconnectState) {
		syncStatus.update((s) => ({
			...s,
			connected: false,
			syncing: false,
			reconnectAttempts: 0
		}));
	}
}

/**
 * Manually retry connection (resets reconnect attempts)
 */
export async function retryUkLrtSync() {
	syncStatus.update((s) => ({
		...s,
		reconnectAttempts: 0,
		error: null
	}));
	await syncUkLrt(currentWhereClause || undefined);
}

/**
 * Force a full re-sync by clearing saved offset and data
 *
 * Use this when you want to completely refresh data from the server,
 * ignoring any cached data or sync state.
 */
export async function forceFullResync() {
	const where = currentWhereClause || getDefaultWhere();
	const shapeKey = getShapeKey(where);

	// Clear persisted sync state
	await clearElectricSyncState(shapeKey);

	console.log('[Electric Sync] Forcing full re-sync - cleared saved offset');

	// Re-sync with clearData=true to also clear local collection
	await syncUkLrt(where, false, true);
}

/**
 * Update the WHERE clause and re-sync (debounced)
 *
 * Debounces updates to prevent excessive re-syncs during rapid filter changes.
 * The sync will only occur after the user stops typing for WHERE_DEBOUNCE_MS.
 *
 * @param whereClause - New SQL WHERE clause
 */
export async function updateUkLrtWhere(whereClause: string) {
	// Clear any pending debounce
	if (whereDebounceTimeout) {
		clearTimeout(whereDebounceTimeout);
		whereDebounceTimeout = null;
	}

	// Debounce the WHERE clause update
	whereDebounceTimeout = setTimeout(async () => {
		console.log(`[Electric Sync] Updating WHERE clause to: ${whereClause}`);
		await syncUkLrt(whereClause);
		whereDebounceTimeout = null;
	}, WHERE_DEBOUNCE_MS);
}

/**
 * Update the WHERE clause immediately (no debounce)
 *
 * Use this when you need immediate sync, e.g., when applying a saved view.
 *
 * @param whereClause - New SQL WHERE clause
 */
export async function updateUkLrtWhereImmediate(whereClause: string) {
	// Clear any pending debounce
	if (whereDebounceTimeout) {
		clearTimeout(whereDebounceTimeout);
		whereDebounceTimeout = null;
	}

	console.log(`[Electric Sync] Immediately updating WHERE clause to: ${whereClause}`);
	await syncUkLrt(whereClause);
}

/**
 * Get current sync status
 */
export function getUkLrtSyncStatus(): SyncStatus {
	return get(syncStatus);
}

/**
 * Check if Electric service is available
 */
export async function checkElectricHealth(): Promise<boolean> {
	try {
		const response = await fetch(`${ELECTRIC_URL}/v1/shape?table=uk_lrt&offset=-1&where=year=2025`);
		return response.ok;
	} catch (error) {
		console.error('[Electric Sync] Health check failed:', error);
		return false;
	}
}

/**
 * Build WHERE clause from filter conditions
 */
export function buildWhereFromFilters(
	filters: Array<{ field: string; operator: string; value: unknown }>
): string {
	if (!filters || filters.length === 0) {
		return getDefaultWhere();
	}

	const clauses = filters
		.map((filter) => {
			const { field, operator, value } = filter;

			switch (operator) {
				case 'equals':
					return typeof value === 'string'
						? `${field} = '${escapeValue(String(value))}'`
						: `${field} = ${value}`;
				case 'not_equals':
					return typeof value === 'string'
						? `${field} != '${escapeValue(String(value))}'`
						: `${field} != ${value}`;
				case 'contains':
					return `${field} ILIKE '%${escapeValue(String(value))}%'`;
				case 'not_contains':
					return `${field} NOT ILIKE '%${escapeValue(String(value))}%'`;
				case 'starts_with':
					return `${field} ILIKE '${escapeValue(String(value))}%'`;
				case 'ends_with':
					return `${field} ILIKE '%${escapeValue(String(value))}'`;
				case 'greater_than':
					return `${field} > ${value}`;
				case 'less_than':
					return `${field} < ${value}`;
				case 'greater_or_equal':
					return `${field} >= ${value}`;
				case 'less_or_equal':
					return `${field} <= ${value}`;
				case 'is_empty':
					return `(${field} IS NULL OR ${field} = '')`;
				case 'is_not_empty':
					return `(${field} IS NOT NULL AND ${field} != '')`;
				case 'is_before':
					return `${field} < '${escapeValue(String(value))}'`;
				case 'is_after':
					return `${field} > '${escapeValue(String(value))}'`;
				default:
					return null;
			}
		})
		.filter(Boolean);

	if (clauses.length === 0) {
		return getDefaultWhere();
	}

	return clauses.join(' AND ');
}

function escapeValue(value: string): string {
	return value.replace(/'/g, "''");
}
