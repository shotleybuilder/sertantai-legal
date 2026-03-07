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
import type { LatRecord } from '$lib/electric/lat-schema';
import type { AnnotationRecord } from '$lib/electric/annotation-schema';
import { LAT_COLUMNS } from '$lib/electric/lat-schema';
import { ANNOTATION_COLUMNS } from '$lib/electric/annotation-schema';
import { electricFetchClient } from '$lib/electric/fetch-client';

// Re-export types for external use
export type { UkLrtRecord } from '$lib/electric/uk-lrt-schema';
export type { LatRecord } from '$lib/electric/lat-schema';
export type { AnnotationRecord } from '$lib/electric/annotation-schema';

// Types that satisfy Electric's Row constraint (requires index signature)
type ElectricUkLrtRecord = UkLrtRecord & Record<string, unknown>;
type ElectricLatRecord = LatRecord & Record<string, unknown>;
type ElectricAnnotationRecord = AnnotationRecord & Record<string, unknown>;

// Electric service configuration — import resolved absolute URL from shared client
import { ELECTRIC_URL } from '$lib/electric/client';

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
	'live_conflict_detail',
	'lat_count',
	'latest_lat_updated_at',
	// Fitness/applicability columns (Issue #39)
	'fitness_person',
	'fitness_process',
	'fitness_place',
	'fitness_plant',
	'fitness_property',
	'fitness_sector',
	'fitness'
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

// Shape recovery: track whether we've already attempted a shape reset.
// Uses a timestamp so the flag auto-expires after 30 seconds — prevents
// permanent lockout if the first retry fails but conditions change.
let shapeResetAttemptedAt = 0;

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
	// Clean up the previous collection's ShapeStream before creating a new one.
	// Without this, rapid view switches leave multiple ShapeStreams active,
	// causing MissingHeadersError when responses arrive for stale streams.
	if (ukLrtCol) {
		ukLrtCol.cleanup();
		ukLrtCol = null;
	}

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
			syncMode: 'eager', // Eager mode: sync all data immediately. Safe because WHERE clause limits to ~800 records.
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'uk_lrt',
					where: whereClause,
					columns: UK_LRT_COLUMNS
				},
				onError: async (error: unknown) => {
					const status =
						error instanceof Error && 'status' in error
							? (error as { status: number }).status
							: null;

					// 401 Unauthorized — no valid JWT token
					if (status === 401) {
						syncStatus.update((s) => ({
							...s,
							error: 'Authentication required',
							syncing: false
						}));
						console.warn('[TanStack DB] Unauthorized (401) — sign in required');
						return;
					}

					// 400 "offset out of bounds" — stale shape from Electric restart or
					// prior errors. The Electric client retains internal offset/handle state
					// across retries, so returning {} doesn't help (it retries with the same
					// stale offset). Instead, destroy the collection and recreate it fresh.
					if (status === 400) {
						const now = Date.now();
						if (now - shapeResetAttemptedAt < 30_000) {
							console.error('[TanStack DB] Shape recovery already attempted recently, waiting');
							syncStatus.update((s) => ({
								...s,
								error: 'Electric sync unavailable — try refreshing the page',
								syncing: false
							}));
							return;
						}
						shapeResetAttemptedAt = now;
						console.warn('[TanStack DB] Broken shape detected (400), recreating collection');

						// Try to delete the broken shape via the proxy (works if
						// ELECTRIC_ENABLE_INTEGRATION_TESTING is set on the Electric container)
						try {
							await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=uk_lrt`, {
								method: 'DELETE'
							});
						} catch {
							// DELETE may not be available — that's OK
						}

						// Schedule collection recreation after a brief delay.
						// This creates a brand-new ShapeStream with offset=-1.
						setTimeout(async () => {
							try {
								ukLrtCol = null;
								ukLrtCol = await createUkLrtCollection(currentWhereClause);
							} catch (e) {
								console.error('[TanStack DB] Collection recreation failed:', e);
							}
						}, 1500);
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
				shapeResetAttemptedAt = 0;
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

// ── LAT Collection ──────────────────────────────────────────────────────────

let latCol: Collection<ElectricLatRecord, string> | null = null;
let latShapeResetAttemptedAt = 0;

/**
 * Create LAT collection with Electric sync.
 * Filtered by law_name — LAT is per-law, so a WHERE clause is required.
 */
async function createLatCollection(
	lawName: string
): Promise<Collection<ElectricLatRecord, string>> {
	if (latCol) {
		latCol.cleanup();
		latCol = null;
	}

	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	const whereClause = `law_name = '${lawName.replace(/'/g, "''")}'`;

	const collection = createCollection(
		electricCollectionOptions<ElectricLatRecord>({
			id: `lat-${lawName}`,
			syncMode: 'eager',
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'lat',
					where: whereClause,
					columns: LAT_COLUMNS
				},
				onError: async (error: unknown) => {
					const status =
						error instanceof Error && 'status' in error
							? (error as { status: number }).status
							: null;

					if (status === 401) {
						console.warn('[TanStack DB] LAT: Unauthorized (401) — sign in required');
						return;
					}

					if (status === 400) {
						const now = Date.now();
						if (now - latShapeResetAttemptedAt < 30_000) {
							console.error('[TanStack DB] LAT: Shape recovery already attempted recently');
							return;
						}
						latShapeResetAttemptedAt = now;
						console.warn('[TanStack DB] LAT: Broken shape (400), recreating collection');
						try {
							await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=lat`, {
								method: 'DELETE'
							});
						} catch {
							// DELETE may not be available
						}
						setTimeout(async () => {
							try {
								latCol = null;
								latCol = await createLatCollection(currentLatLawName);
							} catch (e) {
								console.error('[TanStack DB] LAT: Collection recreation failed:', e);
							}
						}, 1500);
						return;
					}

					console.error('[TanStack DB] LAT: Electric sync error:', error);
					return;
				}
			},
			getKey: (item) => item.section_id as string
		})
	);

	console.log(`[TanStack DB] LAT collection initialized for law: ${lawName}`);
	return collection as unknown as Collection<ElectricLatRecord, string>;
}

/**
 * Get LAT collection for a specific law (browser only).
 * Creates the collection on first call; recreates if law changes.
 */
let currentLatLawName = '';
export async function getLatCollection(
	lawName: string
): Promise<Collection<ElectricLatRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	if (latCol && currentLatLawName === lawName) {
		return latCol;
	}

	currentLatLawName = lawName;
	latCol = await createLatCollection(lawName);
	return latCol;
}

// ── Amendment Annotations Collection ────────────────────────────────────────

let annotationCol: Collection<ElectricAnnotationRecord, string> | null = null;
let annotationShapeResetAttemptedAt = 0;

/**
 * Create annotations collection with Electric sync.
 * Filtered by law_name — annotations are per-law.
 */
async function createAnnotationCollection(
	lawName: string
): Promise<Collection<ElectricAnnotationRecord, string>> {
	if (annotationCol) {
		annotationCol.cleanup();
		annotationCol = null;
	}

	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	const whereClause = `law_name = '${lawName.replace(/'/g, "''")}'`;

	const collection = createCollection(
		electricCollectionOptions<ElectricAnnotationRecord>({
			id: `annotations-${lawName}`,
			syncMode: 'eager',
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'amendment_annotations',
					where: whereClause,
					columns: ANNOTATION_COLUMNS
				},
				onError: async (error: unknown) => {
					const status =
						error instanceof Error && 'status' in error
							? (error as { status: number }).status
							: null;

					if (status === 401) {
						console.warn('[TanStack DB] Annotations: Unauthorized (401) — sign in required');
						return;
					}

					if (status === 400) {
						const now = Date.now();
						if (now - annotationShapeResetAttemptedAt < 30_000) {
							console.error('[TanStack DB] Annotations: Shape recovery already attempted recently');
							return;
						}
						annotationShapeResetAttemptedAt = now;
						console.warn('[TanStack DB] Annotations: Broken shape (400), recreating collection');
						try {
							await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=amendment_annotations`, {
								method: 'DELETE'
							});
						} catch {
							// DELETE may not be available
						}
						setTimeout(async () => {
							try {
								annotationCol = null;
								annotationCol = await createAnnotationCollection(currentAnnotationLawName);
							} catch (e) {
								console.error('[TanStack DB] Annotations: Collection recreation failed:', e);
							}
						}, 1500);
						return;
					}

					console.error('[TanStack DB] Annotations: Electric sync error:', error);
					return;
				}
			},
			getKey: (item) => item.id as string
		})
	);

	console.log(`[TanStack DB] Annotations collection initialized for law: ${lawName}`);
	return collection as unknown as Collection<ElectricAnnotationRecord, string>;
}

/**
 * Get annotations collection for a specific law (browser only).
 * Creates the collection on first call; recreates if law changes.
 */
let currentAnnotationLawName = '';
export async function getAnnotationCollection(
	lawName: string
): Promise<Collection<ElectricAnnotationRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	if (annotationCol && currentAnnotationLawName === lawName) {
		return annotationCol;
	}

	currentAnnotationLawName = lawName;
	annotationCol = await createAnnotationCollection(lawName);
	return annotationCol;
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

	const collections: Record<string, string> = {};
	if (ukLrtCol) collections.ukLrt = 'uk-lrt';
	if (latCol) collections.lat = `lat-${currentLatLawName}`;
	if (annotationCol) collections.annotations = `annotations-${currentAnnotationLawName}`;

	return {
		initialized: ukLrtCol !== null,
		collections,
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
					return typeof value === 'string'
						? `${field} > '${escapeValue(String(value))}'`
						: `${field} > ${value}`;
				case 'less_than':
					return typeof value === 'string'
						? `${field} < '${escapeValue(String(value))}'`
						: `${field} < ${value}`;
				case 'greater_or_equal':
					return typeof value === 'string'
						? `${field} >= '${escapeValue(String(value))}'`
						: `${field} >= ${value}`;
				case 'less_or_equal':
					return typeof value === 'string'
						? `${field} <= '${escapeValue(String(value))}'`
						: `${field} <= ${value}`;
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
