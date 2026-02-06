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
 * Columns to sync from uk_lrt table.
 * Excludes PostgreSQL generated columns (leg_gov_uk_url, number_int) which Electric cannot sync.
 */
const UK_LRT_COLUMNS = [
	'id',
	'family',
	'family_ii',
	'name',
	'md_description',
	'year',
	'number',
	'live',
	'type_desc',
	'role',
	'tags',
	'created_at',
	'title_en',
	'acronym',
	'old_style_number',
	'type_code',
	'type_class',
	'domain',
	'md_date',
	'md_date_year',
	'md_date_month',
	'md_made_date',
	'md_enactment_date',
	'md_coming_into_force_date',
	'md_dct_valid_date',
	'md_restrict_start_date',
	'live_description',
	'latest_amend_date',
	'latest_rescind_date',
	'duty_holder',
	'power_holder',
	'rights_holder',
	'responsibility_holder',
	'duties',
	'rights',
	'responsibilities',
	'powers',
	'role_gvt',
	'geo_extent',
	'geo_region',
	'md_restrict_extent',
	'md_subjects',
	'purpose',
	'function',
	'popimar',
	'si_code',
	'md_total_paras',
	'md_body_paras',
	'md_schedule_paras',
	'md_attachment_paras',
	'md_images',
	'amending',
	'amended_by',
	'linked_amending',
	'linked_amended_by',
	'is_amending',
	'rescinding',
	'rescinded_by',
	'linked_rescinding',
	'linked_rescinded_by',
	'is_rescinding',
	'enacted_by',
	'linked_enacted_by',
	'is_enacting',
	'is_making',
	'is_commencing',
	'geo_detail',
	'duty_type',
	'duty_type_article',
	'article_duty_type',
	'popimar_details',
	'updated_at',
	'md_modified',
	'enacted_by_meta',
	'role_details',
	'role_gvt_details',
	'live_source',
	'live_conflict',
	'live_from_changes',
	'live_from_metadata',
	'live_conflict_detail'
];

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

		// Get the UK LRT collection (browser only) with the correct WHERE clause
		const ukLrtCollection = await getUkLrtCollection(where);

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
			params: { table: string; where: string; columns: string[] };
			offset?: Offset;
			handle?: string;
		} = {
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'uk_lrt',
				where,
				columns: UK_LRT_COLUMNS
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

		// Subscribe to shape changes - process asynchronously to prevent blocking
		activeSubscription = currentStream.subscribe((messages) => {
			// Process messages asynchronously to prevent browser freeze
			processMessages(messages, ukLrtCollection, shapeKey, latestOffset, latestHandle).then(
				({ newOffset, newHandle }) => {
					if (newOffset) latestOffset = newOffset;
					if (newHandle) latestHandle = newHandle;
				}
			);
		});

		// Async message processor with batching and yielding
		async function processMessages(
			messages: any[],
			collection: typeof ukLrtCollection,
			shapeKey: string,
			prevOffset: string | undefined,
			prevHandle: string | undefined
		): Promise<{ newOffset?: string; newHandle?: string }> {
			console.log(
				`[Electric Sync] Processing ${messages.length} UK LRT updates, isUpToDate: ${currentStream?.isUpToDate}`
			);

			let latestOffset = prevOffset;
			let latestHandle = prevHandle;
			let insertCount = 0;
			let updateCount = 0;
			let deleteCount = 0;

			// Process in batches to prevent blocking
			const BATCH_SIZE = 100;

			for (let i = 0; i < messages.length; i++) {
				const msg = messages[i];

				// Track offset
				if (msg.offset) latestOffset = msg.offset;
				if (msg.headers?.handle) latestHandle = msg.headers.handle;

				// Handle control messages
				if (msg.headers?.control) {
					console.log('[Electric Sync] Control message:', msg.headers.control);

					if (msg.headers.control === 'up-to-date') {
						if (latestOffset) {
							saveElectricSyncState(shapeKey, {
								offset: latestOffset,
								handle: latestHandle,
								lastSyncTime: new Date().toISOString(),
								recordCount: collection.size
							});
						}

						syncStatus.update((s) => ({
							...s,
							connected: true,
							syncing: false,
							offline: false,
							recordCount: collection.size,
							lastSyncTime: new Date(),
							reconnectAttempts: 0
						}));
					}
					continue;
				}

				const operation = msg.headers?.operation;
				const rawData = msg.value;

				if (!operation || !rawData) continue;

				try {
					const data = transformUkLrtRecord(rawData);

					switch (operation) {
						case 'insert':
							if (collection.has(data.id)) {
								collection.update(data.id, (draft) => Object.assign(draft, data));
								updateCount++;
							} else {
								collection.insert(data);
								insertCount++;
							}
							break;
						case 'update':
							if (collection.has(data.id)) {
								collection.update(data.id, (draft) => Object.assign(draft, data));
								updateCount++;
							} else {
								collection.insert(data);
								insertCount++;
							}
							break;
						case 'delete':
							if (collection.has(data.id)) {
								collection.delete(data.id);
								deleteCount++;
							}
							break;
					}
				} catch (error) {
					console.error('[Electric Sync] Error processing message:', error);
				}

				// Yield to event loop every BATCH_SIZE messages
				if ((i + 1) % BATCH_SIZE === 0) {
					await new Promise((resolve) => setTimeout(resolve, 0));
				}
			}

			if (insertCount > 0 || updateCount > 0 || deleteCount > 0) {
				console.log(
					`[Electric Sync] Processed: ${insertCount} inserts, ${updateCount} updates, ${deleteCount} deletes`
				);
			}

			// Update sync status
			const isFullySynced = currentStream?.isUpToDate ?? false;
			syncStatus.update((s) => ({
				...s,
				connected: true,
				syncing: !isFullySynced,
				offline: false,
				recordCount: collection.size,
				lastSyncTime: isFullySynced ? new Date() : s.lastSyncTime,
				reconnectAttempts: 0
			}));

			return { newOffset: latestOffset, newHandle: latestHandle };
		}

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
		const response = await fetch(
			`${ELECTRIC_URL}/v1/shape?table=uk_lrt&offset=-1&where=year=2025&columns=${UK_LRT_COLUMNS.join(',')}`
		);
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
