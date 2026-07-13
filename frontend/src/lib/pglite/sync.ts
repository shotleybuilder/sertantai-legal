/**
 * PGLite Shape Sync Manager — Multi-Country
 *
 * Subscribes to a single Electric shape on the parent `legal_register` table
 * (PostgreSQL transparently queries all country partitions). All countries
 * sync into a single local `laws` table.
 *
 * Uses `shapeKey` for persistent offset — on warm starts, only delta changes
 * are fetched.
 */

import { browser } from '$app/environment';
import { writable } from 'svelte/store';
import { getPglite } from './client';
import { initSchema } from './schema.sql';
import { ELECTRIC_URL } from '$lib/electric/client';
import { electricFetchClient } from '$lib/electric/fetch-client';
import { getAuthToken } from '$lib/stores/auth';

// ── Column Sets ─────────────────────────────────────────────────────────────

/**
 * All syncable columns from legal_register partition tables.
 * Excludes PostgreSQL generated columns (number_int, has_fitness) which Electric cannot sync.
 */
const ALL_COLUMNS: string[] = [
	'id',
	'country',
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
	'is_amending',
	'rescinding',
	'rescinded_by',
	'is_rescinding',
	'enacted_by',
	'is_enacting',
	'is_making',
	'is_commencing',
	'geo_detail',
	'duty_type',
	'duty_type_article',
	'article_duty_type',
	'updated_at',
	'md_modified',
	'enacted_by_meta',
	'live_from_changes',
	'lat_count',
	'latest_lat_updated_at',
	'fitness_entities',
	'fitness_scope_dimensions',
	'fitness_mention_count',
	'fitness_applies_count',
	'fitness_disapplies_count',
	'making_classification',
	'making_review',
	'making_review_at',
	'source_url'
];

/**
 * Heavy JSONB columns excluded from sync to reduce payload ~50%.
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
 * Admin columns: all columns minus heavy JSONB.
 */
const ADMIN_COLUMNS: string[] = ALL_COLUMNS.filter((col) => !HEAVY_JSONB_COLUMNS.has(col));

/** Exported for use by shape recovery in error handlers */
export { ADMIN_COLUMNS };

// ── Auth Helpers ────────────────────────────────────────────────────────────

/** Extract org_id from JWT token in localStorage (no signature verification). */
function getOrgIdFromToken(): string | null {
	const token = getAuthToken();
	if (!token) return null;
	try {
		const payload = token.split('.')[1];
		const decoded = JSON.parse(atob(payload.replace(/-/g, '+').replace(/_/g, '/')));
		return decoded.org_id ?? null;
	} catch {
		return null;
	}
}

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
const unsubscribeFns: (() => void)[] = [];

/**
 * Initialize PGLite schema and start Electric shape sync for all countries.
 * Safe to call multiple times — only starts once.
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
			'SELECT COUNT(*)::int AS count FROM laws'
		);
		const existingCount = countResult.rows[0]?.count ?? 0;

		// Clear stale subscriptions from OLD schema versions only
		// (don't clear 'laws' — that would force a full re-sync and cause duplicate key errors)
		for (const key of ['uk-lrt', 'laws-uk', 'laws-au']) {
			try {
				await pg.electric.deleteSubscription(key);
			} catch {
				// No subscription to delete
			}
		}

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

		// Single shape on parent legal_register table — all countries
		const result = await pg.electric.syncShapeToTable({
			shape: {
				url: `${ELECTRIC_URL}/v1/shape`,
				fetchClient: electricFetchClient,
				params: {
					table: 'legal_register',
					columns: ADMIN_COLUMNS
				}
			},
			table: 'laws',
			primaryKey: ['id'],
			shapeKey: 'laws',
			mapColumns: (message) => {
				const val = message.value;
				const mapped: Record<string, unknown> = {};
				for (const [key, v] of Object.entries(val)) {
					mapped[key] = typeof v === 'bigint' ? Number(v) : v;
				}
				// has_fitness: server generated column can't be synced via Electric
				const hasFitness = mapped.fitness_entities != null;
				mapped.has_fitness = hasFitness ? 'true' : 'false';
				return mapped;
			},
			initialInsertMethod: 'json',
			onInitialSync: async () => {
				const countRes = await pg.query<{ count: number }>(
					'SELECT COUNT(*)::int AS count FROM laws'
				);
				const count = countRes.rows[0]?.count ?? 0;
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
				console.error('[PGLite Sync] Error:', error);
				syncStatus.update((s) => ({
					...s,
					error: error.message || 'Sync error',
					syncing: false,
					offline: true
				}));
			}
		});

		unsubscribeFns.push(result.unsubscribe);
		console.log('[PGLite Sync] Shape subscription active (all countries)');

		// Org-scoped applicabilities shape (auth-gated)
		const orgId = getOrgIdFromToken();
		if (orgId) {
			try {
				// Clear stale applicabilities subscription
				try {
					await pg.electric.deleteSubscription(`org-applicabilities-${orgId}`);
				} catch {
					// No subscription to delete
				}

				const oaResult = await pg.electric.syncShapeToTable({
					shape: {
						url: `${ELECTRIC_URL}/v1/shape`,
						fetchClient: electricFetchClient,
						params: {
							table: 'org_applicabilities',
							where: `organization_id = '${orgId}'`
						}
					},
					table: 'org_applicabilities',
					primaryKey: ['id'],
					shapeKey: `org-applicabilities-${orgId}`,
					onInitialSync: async () => {
						const countRes = await pg.query<{ count: number }>(
							'SELECT COUNT(*)::int AS count FROM org_applicabilities'
						);
						console.log(
							`[PGLite Sync] Applicabilities synced: ${countRes.rows[0]?.count ?? 0} records`
						);
					},
					onError: async (error: Error) => {
						console.error('[PGLite Sync] Applicabilities sync error:', error);
					}
				});
				unsubscribeFns.push(oaResult.unsubscribe);
				console.log(`[PGLite Sync] Applicabilities shape active for org ${orgId}`);
			} catch (error) {
				console.warn('[PGLite Sync] Applicabilities shape failed (auth may be required):', error);
			}
		} else {
			console.log('[PGLite Sync] No org_id — skipping applicabilities shape');
		}
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
 * Stop all sync subscriptions.
 */
export function stopSync(): void {
	for (const unsub of unsubscribeFns) {
		unsub();
	}
	unsubscribeFns.length = 0;
	syncStarted = false;
}
