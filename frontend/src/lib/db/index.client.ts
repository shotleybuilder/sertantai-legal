/**
 * TanStack DB Collections (Client-Only)
 *
 * Creates reactive collections for UK LRT data using the official
 * @tanstack/electric-db-collection integration.
 *
 * Collection Strategy:
 * - Admin pages: `progressive` mode — snapshot loads first view fast,
 *   full dataset (~19K records, ~48MB) backfills in background.
 *   After backfill, all filtering is client-side sub-millisecond.
 * - Public pages: `on-demand` mode — only fetches data when queried
 *   via createLiveQueryCollection. Previously fetched data stays cached.
 * - LAT Queue: `eager` mode — small fixed dataset (is_making = true).
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

// ── Column Sets ─────────────────────────────────────────────────────────────

/**
 * All syncable columns from uk_lrt table.
 * Excludes PostgreSQL generated columns (leg_gov_uk_url, number_int) which Electric cannot sync.
 */
export const UK_LRT_ALL_COLUMNS: string[] = [
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
	'fitness_person',
	'fitness_process',
	'fitness_place',
	'fitness_plant',
	'fitness_property',
	'fitness_sector',
	'fitness'
];

/**
 * Heavy JSONB columns excluded from admin sync to reduce payload ~50%.
 * Detail data is available via ParseReviewModal REST call when needed.
 */
const HEAVY_JSONB_COLUMNS = new Set([
	'role_details',
	'role_gvt_details',
	'duties',
	'responsibilities',
	'powers',
	'popimar_details',
	'rights'
]);

/**
 * Admin columns: all columns minus heavy JSONB (~2.5 KB/row instead of ~5.7 KB/row).
 * Full sync: 19K × 2.5 KB ≈ 48 MB (progressive backfill).
 */
export const UK_LRT_ADMIN_COLUMNS: string[] = UK_LRT_ALL_COLUMNS.filter(
	(col) => !HEAVY_JSONB_COLUMNS.has(col)
);

/**
 * Browse columns: lightweight subset for public-facing pages.
 * Only columns needed for browse views (no amendment links, no holder details).
 */
export const UK_LRT_BROWSE_COLUMNS: string[] = [
	'id',
	'family',
	'family_ii',
	'name',
	'title_en',
	'year',
	'number',
	'type_code',
	'type_class',
	'live',
	'live_description',
	'function',
	'is_making',
	'si_code',
	'geo_extent',
	'geo_region',
	'geo_detail',
	'md_restrict_extent',
	'md_date',
	'md_date_year',
	'md_date_month',
	'md_made_date',
	'md_enactment_date',
	'md_coming_into_force_date',
	'latest_amend_date',
	'latest_amend_date_year',
	'latest_amend_date_month',
	'latest_rescind_date',
	'latest_rescind_date_year',
	'latest_rescind_date_month',
	'updated_at'
];

// ── Sync Status ─────────────────────────────────────────────────────────────

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

// ── Shared Error Handler ────────────────────────────────────────────────────

/**
 * Creates a shape error handler for a specific collection.
 * Handles 401 (auth), 400 (broken shape) with throttled recovery.
 * On 400, nulls out the singleton so next getter call recreates it.
 */
function shapeErrorHandler(collectionId: string, columns: string[], resetSingleton: () => void) {
	let resetAttemptedAt = 0;

	return async (error: unknown) => {
		const status =
			error instanceof Error && 'status' in error ? (error as { status: number }).status : null;

		if (status === 401) {
			syncStatus.update((s) => ({
				...s,
				error: 'Authentication required',
				syncing: false
			}));
			console.warn(`[TanStack DB] ${collectionId}: Unauthorized (401)`);
			return;
		}

		if (status === 400) {
			const now = Date.now();
			if (now - resetAttemptedAt < 30_000) {
				console.error(`[TanStack DB] ${collectionId}: Shape recovery already attempted recently`);
				syncStatus.update((s) => ({
					...s,
					error: 'Electric sync unavailable — try refreshing the page',
					syncing: false
				}));
				return;
			}
			resetAttemptedAt = now;
			console.warn(`[TanStack DB] ${collectionId}: Broken shape (400), resetting`);

			try {
				const colParam = encodeURIComponent(columns.join(','));
				await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=uk_lrt&columns=${colParam}`, {
					method: 'DELETE'
				});
			} catch {
				// DELETE may not be available
			}

			// Null out singleton so next call recreates fresh
			resetSingleton();
			return;
		}

		console.error(`[TanStack DB] ${collectionId}: sync error:`, error);
	};
}

/**
 * Attach sync status monitoring to a collection.
 */
function monitorSyncStatus(
	collection: Collection<ElectricUkLrtRecord, string>,
	collectionId: string
) {
	let statusDebounceTimer: ReturnType<typeof setTimeout> | null = null;
	let resetAttemptedAt = 0;

	const checkStatus = () => {
		if (statusDebounceTimer) clearTimeout(statusDebounceTimer);
		statusDebounceTimer = setTimeout(() => {
			const isReady = collection.isReady();
			const recordCount = collection.size;

			if (recordCount > 0) resetAttemptedAt = 0;

			syncStatus.update((s) => ({
				...s,
				connected: true,
				syncing: !isReady,
				recordCount,
				lastSyncTime: isReady ? new Date() : s.lastSyncTime
			}));
		}, 100);
	};

	collection.subscribeChanges(() => checkStatus());

	syncStatus.update((s) => ({
		...s,
		connected: true,
		syncing: true,
		recordCount: collection.size,
		whereClause: collectionId
	}));

	console.log(`[TanStack DB] ${collectionId} collection initialized`);
}

// ── Admin Collection (Progressive) ──────────────────────────────────────────

let adminCollection: Collection<ElectricUkLrtRecord, string> | null = null;

/**
 * Admin collection: progressive sync, no WHERE clause.
 * First query loads fast via fetchSnapshot. Full dataset (~19K records, ~48MB
 * without heavy JSONB) backfills in background. After backfill, all filtering
 * is client-side sub-millisecond.
 */
export async function getAdminCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	if (adminCollection) return adminCollection;

	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	adminCollection = createCollection(
		electricCollectionOptions<ElectricUkLrtRecord>({
			id: 'uk-lrt-admin',
			syncMode: 'progressive',
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'uk_lrt',
					columns: UK_LRT_ADMIN_COLUMNS
					// No WHERE — progressive syncs everything
				},
				onError: shapeErrorHandler('uk-lrt-admin', UK_LRT_ADMIN_COLUMNS, () => {
					adminCollection = null;
				})
			},
			getKey: (item) => item.id as string
		})
	) as unknown as Collection<ElectricUkLrtRecord, string>;

	monitorSyncStatus(adminCollection, 'uk-lrt-admin (progressive)');
	return adminCollection;
}

// ── Browse Collection (On-Demand) ───────────────────────────────────────────

let browseCollection: Collection<ElectricUkLrtRecord, string> | null = null;

/**
 * Browse collection: on-demand sync, no WHERE clause.
 * Starts at offset=now (changes only). Each createLiveQueryCollection
 * triggers loadSubset → fetchSnapshot to pull only matching rows.
 * Previously fetched data stays cached in the collection.
 */
export async function getBrowseCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	if (browseCollection) return browseCollection;

	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	browseCollection = createCollection(
		electricCollectionOptions<ElectricUkLrtRecord>({
			id: 'uk-lrt-browse',
			syncMode: 'on-demand',
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'uk_lrt',
					columns: UK_LRT_BROWSE_COLUMNS
					// No WHERE — on-demand fetches per-query
				},
				onError: shapeErrorHandler('uk-lrt-browse', UK_LRT_BROWSE_COLUMNS, () => {
					browseCollection = null;
				})
			},
			getKey: (item) => item.id as string
		})
	) as unknown as Collection<ElectricUkLrtRecord, string>;

	monitorSyncStatus(browseCollection, 'uk-lrt-browse (on-demand)');
	return browseCollection;
}

// ── LAT Queue Collection (Eager) ────────────────────────────────────────────

let latQueueCollection: Collection<ElectricUkLrtRecord, string> | null = null;

/**
 * LAT Queue collection: eager sync with fixed WHERE (is_making = true).
 * Small dataset (~3K records), never changes scope.
 */
export async function getLatQueueCollection(): Promise<Collection<ElectricUkLrtRecord, string>> {
	if (!browser) {
		throw new Error('TanStack DB collections can only be used in the browser');
	}

	if (latQueueCollection) return latQueueCollection;

	const { createCollection } = await import('@tanstack/db');
	const { electricCollectionOptions } = await import('@tanstack/electric-db-collection');

	latQueueCollection = createCollection(
		electricCollectionOptions<ElectricUkLrtRecord>({
			id: 'uk-lrt-lat-queue',
			syncMode: 'eager',
			shapeOptions: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'uk_lrt',
					where: 'is_making = true',
					columns: UK_LRT_ADMIN_COLUMNS
				},
				onError: shapeErrorHandler('uk-lrt-lat-queue', UK_LRT_ADMIN_COLUMNS, () => {
					latQueueCollection = null;
				})
			},
			getKey: (item) => item.id as string
		})
	) as unknown as Collection<ElectricUkLrtRecord, string>;

	monitorSyncStatus(latQueueCollection, 'uk-lrt-lat-queue (eager)');
	return latQueueCollection;
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

// ── Status ──────────────────────────────────────────────────────────────────

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
	if (adminCollection) collections.admin = 'uk-lrt-admin (progressive)';
	if (browseCollection) collections.browse = 'uk-lrt-browse (on-demand)';
	if (latQueueCollection) collections.latQueue = 'uk-lrt-lat-queue (eager)';
	if (latCol) collections.lat = `lat-${currentLatLawName}`;
	if (annotationCol) collections.annotations = `annotations-${currentAnnotationLawName}`;

	return {
		initialized: adminCollection !== null || browseCollection !== null,
		collections,
		storage: 'Electric (memory)'
	};
}
