/**
 * PGLite Shape Sync Manager
 *
 * Connects a single Electric shape subscription to the local PGLite uk_lrt table.
 * Uses `shapeKey` for persistent offset — on warm starts, only delta changes
 * are fetched instead of re-downloading the full ~48MB dataset.
 *
 * Replaces three separate TanStack DB collections (admin progressive,
 * browse on-demand, LAT queue eager) with one persistent local table.
 */

import { browser } from '$app/environment';
import { writable } from 'svelte/store';
import { getPglite } from './client';
import { initSchema } from './schema.sql';
import { ELECTRIC_URL } from '$lib/electric/client';
import { electricFetchClient } from '$lib/electric/fetch-client';

// ── Column Sets ─────────────────────────────────────────────────────────────

/**
 * All syncable columns from uk_lrt table.
 * Excludes PostgreSQL generated columns (leg_gov_uk_url, number_int) which Electric cannot sync.
 */
const UK_LRT_ALL_COLUMNS: string[] = [
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
	'live_from_changes',
	'lat_count',
	'latest_lat_updated_at',
	'fitness_person',
	'fitness_process',
	'fitness_place',
	'fitness_plant',
	'fitness_property',
	'fitness_sector',
	'fitness',
	'making_classification'
];

/**
 * Heavy JSONB columns excluded from sync to reduce payload ~50%.
 * Detail data is available via ParseReviewModal REST call when needed.
 */
const HEAVY_JSONB_COLUMNS = new Set([
	'role_details',
	'role_gvt_details',
	'duties',
	'responsibilities',
	'powers',
	'popimar_details',
	'rights',
	'fitness'
]);

/**
 * Admin columns: all columns minus heavy JSONB (~2.5 KB/row instead of ~5.7 KB/row).
 */
const UK_LRT_ADMIN_COLUMNS: string[] = UK_LRT_ALL_COLUMNS.filter(
	(col) => !HEAVY_JSONB_COLUMNS.has(col)
);

// ── Sync Status Store ───────────────────────────────────────────────────────

export interface SyncStatus {
	connected: boolean;
	syncing: boolean;
	offline: boolean;
	recordCount: number;
	lastSyncTime: Date | null;
	error: string | null;
}

export const syncStatus = writable<SyncStatus>({
	connected: false,
	syncing: true,
	offline: false,
	recordCount: 0,
	lastSyncTime: null,
	error: null
});

// ── Sync Lifecycle ──────────────────────────────────────────────────────────

let syncStarted = false;
let unsubscribeSync: (() => void) | null = null;
let resetAttemptedAt = 0;

/**
 * Initialize PGLite schema and start Electric shape sync.
 * Safe to call multiple times — only starts once.
 *
 * On first visit: full sync (~19K rows, 15-30s).
 * On subsequent visits: resumes from persisted offset (sub-second).
 */
export async function startSync(): Promise<void> {
	if (!browser) return;
	if (syncStarted) return;
	syncStarted = true;

	try {
		const pg = await getPglite();
		await initSchema(pg);

		// Check for existing data (warm start)
		const countResult = await pg.query<{ count: number }>(
			'SELECT COUNT(*)::int AS count FROM uk_lrt'
		);
		const existingCount = countResult.rows[0]?.count ?? 0;

		if (existingCount > 0) {
			console.log(`[PGLite Sync] Warm start: ${existingCount} existing records`);
			syncStatus.set({
				connected: true,
				syncing: false,
				offline: false,
				recordCount: existingCount,
				lastSyncTime: new Date(),
				error: null
			});
		} else {
			// Table is empty — clear any stale subscription state so pglite-sync
			// does a full initial sync instead of resuming from a stale offset.
			try {
				await pg.electric.deleteSubscription('uk-lrt');
				console.log('[PGLite Sync] Cleared stale subscription — starting fresh');
			} catch {
				// No subscription to delete — first time
			}

			console.log('[PGLite Sync] Cold start: syncing full dataset');
			syncStatus.set({
				connected: true,
				syncing: true,
				offline: false,
				recordCount: 0,
				lastSyncTime: null,
				error: null
			});
		}

		// Start shape sync
		const result = await pg.electric.syncShapeToTable({
			shape: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'uk_lrt',
					columns: UK_LRT_ADMIN_COLUMNS
				}
			},
			table: 'uk_lrt',
			primaryKey: ['id'],
			shapeKey: 'uk-lrt',
			// Use mapColumns to convert BigInt values (Electric parses int8 as BigInt)
			// which can't be serialized to JSON by json_to_recordset insert method.
			mapColumns: (message) => {
				const val = message.value;
				const mapped: Record<string, unknown> = {};
				for (const [key, v] of Object.entries(val)) {
					mapped[key] = typeof v === 'bigint' ? Number(v) : v;
				}
				// has_fitness: server generated column can't be synced via Electric,
				// so compute client-side from tag arrays (null = no data).
				// Stored as TEXT 'true'/'false' for gridlite-kit filter compatibility.
				const hasFitness =
					mapped.fitness_person != null ||
					mapped.fitness_process != null ||
					mapped.fitness_place != null ||
					mapped.fitness_plant != null ||
					mapped.fitness_property != null ||
					mapped.fitness_sector != null;
				mapped.has_fitness = hasFitness ? 'true' : 'false';
				return mapped;
			},
			initialInsertMethod: 'json',
			onInitialSync: async () => {
				const result = await pg.query<{ count: number }>(
					'SELECT COUNT(*)::int AS count FROM uk_lrt'
				);
				const count = result.rows[0]?.count ?? 0;
				console.log(`[PGLite Sync] Initial sync complete: ${count} records`);
				syncStatus.set({
					connected: true,
					syncing: false,
					offline: false,
					recordCount: count,
					lastSyncTime: new Date(),
					error: null
				});
			},
			onError: async (error: Error & { status?: number }) => {
				const status = error.status ?? null;

				if (status === 401) {
					console.warn('[PGLite Sync] Unauthorized (401)');
					syncStatus.update((s) => ({
						...s,
						error: 'Authentication required',
						syncing: false
					}));
					return;
				}

				if (status === 400) {
					const now = Date.now();
					if (now - resetAttemptedAt < 30_000) {
						console.error('[PGLite Sync] Shape recovery already attempted recently');
						syncStatus.update((s) => ({
							...s,
							error: 'Electric sync unavailable — try refreshing the page',
							syncing: false
						}));
						return;
					}
					resetAttemptedAt = now;
					console.warn('[PGLite Sync] Broken shape (400), deleting subscription and retrying');

					try {
						// Delete the server-side shape
						const colParam = encodeURIComponent(UK_LRT_ADMIN_COLUMNS.join(','));
						await electricFetchClient(`${ELECTRIC_URL}/v1/shape?table=uk_lrt&columns=${colParam}`, {
							method: 'DELETE'
						});
					} catch {
						// DELETE may not be available
					}

					try {
						// Delete the local subscription state so it re-syncs fresh
						await pg.electric.deleteSubscription('uk-lrt');
					} catch {
						// May not exist yet
					}

					// Reset and allow re-initialization
					syncStarted = false;
					unsubscribeSync = null;
					setTimeout(() => startSync(), 2000);
					return;
				}

				console.error('[PGLite Sync] Error:', error);
				syncStatus.update((s) => ({
					...s,
					error: error.message || 'Sync error',
					syncing: false,
					offline: true
				}));
			}
		});

		unsubscribeSync = result.unsubscribe;
		console.log('[PGLite Sync] Shape subscription active');
	} catch (error) {
		console.error('[PGLite Sync] Failed to start:', error);
		syncStarted = false;
		syncStatus.set({
			connected: false,
			syncing: false,
			offline: true,
			recordCount: 0,
			lastSyncTime: null,
			error: error instanceof Error ? error.message : 'Failed to start sync'
		});
	}
}

/**
 * Stop the sync subscription.
 */
export function stopSync(): void {
	if (unsubscribeSync) {
		unsubscribeSync();
		unsubscribeSync = null;
	}
	syncStarted = false;
}
