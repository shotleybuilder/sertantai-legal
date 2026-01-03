/**
 * ElectricSQL Sync for UK LRT
 *
 * Connects ElectricSQL's HTTP Shape API with TanStack DB collection
 * to provide real-time sync from PostgreSQL to the client.
 *
 * Supports dynamic WHERE clauses for query-based shape syncing.
 */

import { ShapeStream } from '@electric-sql/client';
import { getUkLrtCollection } from '$lib/db/index.client';
import { type UkLrtRecord, transformUkLrtRecord } from './uk-lrt-schema';
import { writable, get } from 'svelte/store';

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

/**
 * Start syncing UK LRT collection with optional WHERE clause
 *
 * @param whereClause - SQL WHERE clause for filtering (e.g., "year >= 2024")
 */
export async function syncUkLrt(whereClause?: string, isReconnect = false) {
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

		// Clear existing data when WHERE clause changes
		const existingKeys = Array.from(ukLrtCollection.keys());
		for (const key of existingKeys) {
			ukLrtCollection.delete(key);
		}

		console.log(`[Electric Sync] Starting UK LRT sync with WHERE: ${where}`);

		// Create shape stream
		currentStream = new ShapeStream<Record<string, unknown>>({
			url: `${ELECTRIC_URL}/v1/shape`,
			params: {
				table: 'uk_lrt',
				where
			}
		});

		// Subscribe to shape changes
		activeSubscription = currentStream.subscribe((messages) => {
			console.log(`[Electric Sync] Received ${messages.length} UK LRT updates`);

			let insertCount = 0;
			let updateCount = 0;
			let deleteCount = 0;

			messages.forEach((msg: any) => {
				// Skip control messages
				if (msg.headers?.control) {
					console.log('[Electric Sync] Control message:', msg.headers.control);
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
							ukLrtCollection.insert(data);
							insertCount++;
							break;

						case 'update':
							ukLrtCollection.update(data.id, (draft) => {
								Object.assign(draft, data);
							});
							updateCount++;
							break;

						case 'delete':
							ukLrtCollection.delete(data.id);
							deleteCount++;
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
 * Update the WHERE clause and re-sync
 *
 * @param whereClause - New SQL WHERE clause
 */
export async function updateUkLrtWhere(whereClause: string) {
	console.log(`[Electric Sync] Updating WHERE clause to: ${whereClause}`);
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
