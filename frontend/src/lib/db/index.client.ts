/**
 * TanStack DB Collections (Client-Only)
 *
 * Creates reactive collections for UK LRT data using the official
 * @tanstack/electric-db-collection integration.
 *
 * This uses electricCollectionOptions which handles:
 * - ShapeStream subscription and management
 * - Efficient batched updates to the collection
 * - Reactive queries that auto-update
 *
 * NOTE: This module uses dynamic imports to ensure it only runs in the browser.
 */

import { browser } from '$app/environment';
import type { Collection } from '@tanstack/db';
import { writable } from 'svelte/store';
import type { UkLrtRecord } from '$lib/electric/uk-lrt-schema';

// Re-export UkLrtRecord for external use
export type { UkLrtRecord } from '$lib/electric/uk-lrt-schema';

// Type that satisfies Electric's Row constraint (requires index signature)
type ElectricUkLrtRecord = UkLrtRecord & Record<string, unknown>;

// Electric service configuration
const ELECTRIC_URL =
	import.meta.env.VITE_ELECTRIC_URL ||
	import.meta.env.PUBLIC_ELECTRIC_URL ||
	'http://localhost:3002';

/**
 * Columns to sync from uk_lrt table.
 * Excludes PostgreSQL generated columns (leg_gov_uk_url, number_int) which Electric cannot sync.
 */
const UK_LRT_COLUMNS: string[] = [
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
	'latest_amend_date_year',
	'latest_amend_date_month',
	'latest_rescind_date',
	'latest_rescind_date_year',
	'latest_rescind_date_month',
	'duty_holder',
	'power_holder',
	'rights_holder',
	'responsibility_holder',
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
	// Consolidated JSONB holder fields (Phase 3)
	'duties',
	'rights',
	'responsibilities',
	'powers',
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

// Collection singleton using Electric-compatible type
let ukLrtCol: Collection<ElectricUkLrtRecord, string> | null = null;
let currentWhereClause: string = '';

// Shape recovery: track whether we've already attempted a shape reset
let shapeResetAttempted = false;

// Sync status store
export interface SyncStatus {
	connected: boolean;
	syncing: boolean;
	offline: boolean;
	recordCount: number;
	lastSyncTime: Date | null;
	error: string | null;
	whereClause: string;
}

export const syncStatus = writable<SyncStatus>({
	connected: false,
	syncing: true,
	offline: false,
	recordCount: 0,
	lastSyncTime: null,
	error: null,
	whereClause: ''
});

/**
 * Initialize UK LRT collection with Electric sync
 */
async function createUkLrtCollection(
	whereClause: string
): Promise<Collection<ElectricUkLrtRecord, string>> {
	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	currentWhereClause = whereClause;

	syncStatus.update((s) => ({
		...s,
		syncing: true,
		whereClause,
		error: null
	}));

	const collection = createCollection(
		electricCollectionOptions<ElectricUkLrtRecord>({
			id: 'uk-lrt',
			syncMode: 'progressive', // Use progressive mode for large datasets - provides incremental snapshots
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				params: {
					table: 'uk_lrt',
					where: whereClause,
					columns: UK_LRT_COLUMNS
				},
				onError: async (error: unknown) => {
					// After an Electric restart, restored shapes can be permanently broken
					// (400 "offset out of bounds"). Delete the broken shape via the HTTP API
					// so the next request creates a fresh one, then retry.
					if (
						error instanceof Error &&
						'status' in error &&
						(error as { status: number }).status === 400 &&
						!shapeResetAttempted
					) {
						shapeResetAttempted = true;
						console.warn('[TanStack DB] Broken shape detected (400), deleting and retrying');
						try {
							await fetch(`${ELECTRIC_URL}/v1/shape?table=uk_lrt`, { method: 'DELETE' });
						} catch (e) {
							console.warn('[TanStack DB] Shape deletion failed:', e);
						}
						// Brief delay for Electric to clean up, then retry fresh
						await new Promise((resolve) => setTimeout(resolve, 1000));
						return {};
					}
					if (
						error instanceof Error &&
						'status' in error &&
						(error as { status: number }).status === 400
					) {
						// Already tried reset, give up
						console.error('[TanStack DB] Shape recovery failed after reset');
						syncStatus.update((s) => ({
							...s,
							error: 'Electric sync unavailable — try refreshing the page',
							syncing: false
						}));
						return;
					}
					console.error('[TanStack DB] Electric sync error:', error);
					return;
				}
			},
			getKey: (item) => item.id as string
		})
	);

	// Monitor collection state for sync status (debounced to prevent excessive updates)
	let statusDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	const checkSyncStatus = () => {
		// Debounce status updates to prevent UI thrashing
		if (statusDebounceTimer) {
			clearTimeout(statusDebounceTimer);
		}
		statusDebounceTimer = setTimeout(() => {
			const isReady = collection.isReady();
			const recordCount = collection.size;

			// Data is flowing — reset shape recovery flag
			if (recordCount > 0) {
				shapeResetAttempted = false;
			}

			syncStatus.update((s) => ({
				...s,
				connected: true,
				syncing: !isReady,
				recordCount,
				lastSyncTime: isReady ? new Date() : s.lastSyncTime
			}));
		}, 100);
	};

	// Subscribe to collection changes to update sync status
	collection.subscribeChanges(() => {
		checkSyncStatus();
	});

	// Initial status check (immediate)
	syncStatus.update((s) => ({
		...s,
		connected: true,
		syncing: true,
		recordCount: collection.size
	}));

	console.log(
		`[TanStack DB] UK LRT collection initialized with Electric sync, WHERE: ${whereClause}`
	);

	return collection as unknown as Collection<ElectricUkLrtRecord, string>;
}

/**
 * Get UK LRT collection (browser only)
 * Creates the collection on first call with default WHERE clause
 */
export async function getUkLrtCollection(
	whereClause?: string
): Promise<Collection<ElectricUkLrtRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	const where = whereClause || getDefaultWhere();

	// If collection exists with same WHERE, return it
	if (ukLrtCol && currentWhereClause === where) {
		return ukLrtCol;
	}

	// Create new collection (or recreate with new WHERE)
	ukLrtCol = await createUkLrtCollection(where);
	return ukLrtCol;
}

/**
 * Update the WHERE clause and recreate the collection
 */
export async function updateUkLrtWhere(whereClause: string): Promise<void> {
	if (!browser) return;

	// Recreate collection with new WHERE
	ukLrtCol = await createUkLrtCollection(whereClause);
}

/**
 * Initialize the database
 */
export async function initDB(): Promise<void> {
	if (!browser) {
		console.warn('[TanStack DB] initDB called on server - skipping');
		return;
	}

	try {
		await getUkLrtCollection();
		console.log('[TanStack DB] Database initialized successfully');
	} catch (error) {
		console.error('[TanStack DB] Failed to initialize:', error);
		syncStatus.update((s) => ({
			...s,
			error: error instanceof Error ? error.message : 'Failed to initialize',
			syncing: false,
			offline: true
		}));
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

	return {
		initialized: ukLrtCol !== null,
		collections: ukLrtCol ? { ukLrt: 'uk-lrt' } : {},
		storage: 'Electric (memory)',
		whereClause: currentWhereClause
	};
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

	const escapeValue = (value: string): string => value.replace(/'/g, "''");

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
				case 'is_before':
					return `${field} < '${escapeValue(String(value))}'`;
				case 'is_after':
					return `${field} > '${escapeValue(String(value))}'`;
				case 'is_empty':
					return `(${field} IS NULL OR ${field} = '')`;
				case 'is_not_empty':
					return `(${field} IS NOT NULL AND ${field} != '')`;
				case 'in': {
					const values = Array.isArray(value) ? value : [value];
					const escaped = values.map((v: unknown) => `'${escapeValue(String(v))}'`).join(', ');
					return `${field} IN (${escaped})`;
				}
				default:
					console.warn(`[buildWhereFromFilters] Unknown operator: ${operator}`);
					return null;
			}
		})
		.filter(Boolean);

	if (clauses.length === 0) {
		return getDefaultWhere();
	}

	return clauses.join(' AND ');
}
