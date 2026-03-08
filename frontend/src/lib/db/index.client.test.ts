/**
 * Tests for TanStack DB collection factories and column sets.
 *
 * Covers:
 * - Column set definitions (admin excludes heavy JSONB, browse is minimal)
 * - Singleton collection factories (getAdminCollection, getBrowseCollection, getLatQueueCollection)
 * - Sync status store
 */

import { describe, it, expect, vi, beforeAll } from 'vitest';
import { get } from 'svelte/store';

// ── Mocks ───────────────────────────────────────────────────────────────────

vi.mock('$app/environment', () => ({
	browser: true
}));

// Track what electricCollectionOptions receives
const capturedOptions: Record<string, unknown>[] = [];

// Mock collection with minimal interface
function createMockCollection() {
	const changeCallbacks: Array<() => void> = [];
	return {
		isReady: vi.fn(() => false),
		size: 0,
		subscribeChanges: vi.fn((cb: () => void) => {
			changeCallbacks.push(cb);
			return { unsubscribe: vi.fn() };
		}),
		toArray: [],
		keys: vi.fn(() => []),
		has: vi.fn(() => false),
		cleanup: vi.fn()
	};
}

vi.mock('@tanstack/db', () => ({
	createCollection: vi.fn(() => createMockCollection())
}));

vi.mock('@tanstack/electric-db-collection', () => ({
	electricCollectionOptions: vi.fn((opts: Record<string, unknown>) => {
		capturedOptions.push(opts);
		return opts;
	})
}));

vi.mock('$lib/electric/fetch-client', () => ({
	electricFetchClient: vi.fn()
}));

vi.mock('$lib/electric/client', () => ({
	ELECTRIC_URL: 'http://localhost:4003/api/electric'
}));

// Import after mocks
import {
	UK_LRT_ALL_COLUMNS,
	UK_LRT_ADMIN_COLUMNS,
	UK_LRT_BROWSE_COLUMNS,
	syncStatus,
	getAdminCollection,
	getBrowseCollection,
	getLatQueueCollection
} from './index.client';

// ── Column Sets ─────────────────────────────────────────────────────────────

describe('column sets', () => {
	describe('UK_LRT_ALL_COLUMNS', () => {
		it('is a non-empty array of strings', () => {
			expect(UK_LRT_ALL_COLUMNS).toBeInstanceOf(Array);
			expect(UK_LRT_ALL_COLUMNS.length).toBeGreaterThan(50);
			UK_LRT_ALL_COLUMNS.forEach((col) => expect(typeof col).toBe('string'));
		});

		it('includes id column', () => {
			expect(UK_LRT_ALL_COLUMNS).toContain('id');
		});

		it('includes core identification columns', () => {
			expect(UK_LRT_ALL_COLUMNS).toContain('family');
			expect(UK_LRT_ALL_COLUMNS).toContain('name');
			expect(UK_LRT_ALL_COLUMNS).toContain('title_en');
			expect(UK_LRT_ALL_COLUMNS).toContain('year');
		});

		it('includes heavy JSONB columns', () => {
			expect(UK_LRT_ALL_COLUMNS).toContain('role_details');
			expect(UK_LRT_ALL_COLUMNS).toContain('role_gvt_details');
			expect(UK_LRT_ALL_COLUMNS).toContain('duties');
			expect(UK_LRT_ALL_COLUMNS).toContain('responsibilities');
			expect(UK_LRT_ALL_COLUMNS).toContain('powers');
			expect(UK_LRT_ALL_COLUMNS).toContain('popimar_details');
			expect(UK_LRT_ALL_COLUMNS).toContain('rights');
		});

		it('includes fitness columns (issue #39)', () => {
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_person');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_process');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_place');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_plant');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_property');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness_sector');
			expect(UK_LRT_ALL_COLUMNS).toContain('fitness');
		});

		it('excludes generated columns (leg_gov_uk_url, number_int)', () => {
			expect(UK_LRT_ALL_COLUMNS).not.toContain('leg_gov_uk_url');
			expect(UK_LRT_ALL_COLUMNS).not.toContain('number_int');
		});
	});

	describe('UK_LRT_ADMIN_COLUMNS', () => {
		const HEAVY_JSONB = [
			'role_details',
			'role_gvt_details',
			'duties',
			'responsibilities',
			'powers',
			'popimar_details',
			'rights'
		];

		it('excludes all 7 heavy JSONB columns', () => {
			HEAVY_JSONB.forEach((col) => {
				expect(UK_LRT_ADMIN_COLUMNS).not.toContain(col);
			});
		});

		it('has exactly 7 fewer columns than ALL_COLUMNS', () => {
			expect(UK_LRT_ADMIN_COLUMNS.length).toBe(UK_LRT_ALL_COLUMNS.length - 7);
		});

		it('retains all non-JSONB columns', () => {
			const nonHeavy = UK_LRT_ALL_COLUMNS.filter((col) => !HEAVY_JSONB.includes(col));
			nonHeavy.forEach((col) => {
				expect(UK_LRT_ADMIN_COLUMNS).toContain(col);
			});
		});

		it('retains core columns needed for admin views', () => {
			expect(UK_LRT_ADMIN_COLUMNS).toContain('id');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('family');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('title_en');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('year');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('is_making');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('function');
			expect(UK_LRT_ADMIN_COLUMNS).toContain('live');
		});
	});

	describe('UK_LRT_BROWSE_COLUMNS', () => {
		it('is a smaller subset than admin columns', () => {
			expect(UK_LRT_BROWSE_COLUMNS.length).toBeLessThan(UK_LRT_ADMIN_COLUMNS.length);
		});

		it('includes id for key resolution', () => {
			expect(UK_LRT_BROWSE_COLUMNS).toContain('id');
		});

		it('includes columns needed for browse views', () => {
			expect(UK_LRT_BROWSE_COLUMNS).toContain('family');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('name');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('title_en');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('year');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('type_code');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('live');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('function');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('is_making');
		});

		it('includes date columns for date-based views', () => {
			expect(UK_LRT_BROWSE_COLUMNS).toContain('md_date');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('md_date_year');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('latest_amend_date');
			expect(UK_LRT_BROWSE_COLUMNS).toContain('latest_rescind_date');
		});

		it('includes updated_at for sync ordering', () => {
			expect(UK_LRT_BROWSE_COLUMNS).toContain('updated_at');
		});

		it('excludes heavy JSONB columns', () => {
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('role_details');
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('duties');
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('powers');
		});

		it('excludes amendment link columns (not needed for browse)', () => {
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('amending');
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('amended_by');
			expect(UK_LRT_BROWSE_COLUMNS).not.toContain('rescinding');
		});

		it('all browse columns exist in ALL_COLUMNS', () => {
			UK_LRT_BROWSE_COLUMNS.forEach((col) => {
				expect(UK_LRT_ALL_COLUMNS).toContain(col);
			});
		});
	});
});

// ── Collection Factories ────────────────────────────────────────────────────
// Singletons persist across tests within a file, so we initialize all three
// once in beforeAll and inspect the captured options afterward.

describe('collection factories', () => {
	let adminCol: unknown;
	let browseCol: unknown;
	let latQueueCol: unknown;

	beforeAll(async () => {
		adminCol = await getAdminCollection();
		browseCol = await getBrowseCollection();
		latQueueCol = await getLatQueueCollection();
	});

	// Helper to find captured options by collection id
	function findOpts(id: string) {
		return capturedOptions.find((o) => o.id === id);
	}

	describe('getAdminCollection', () => {
		it('returns a collection object', () => {
			expect(adminCol).toBeDefined();
			expect(adminCol).toHaveProperty('subscribeChanges');
		});

		it('creates collection with progressive sync mode', () => {
			const opts = findOpts('uk-lrt-admin');
			expect(opts).toBeDefined();
			expect(opts!.syncMode).toBe('progressive');
		});

		it('uses admin columns (no heavy JSONB)', () => {
			const opts = findOpts('uk-lrt-admin');
			const params = (opts!.shapeOptions as any).params;
			expect(params.columns).toEqual(UK_LRT_ADMIN_COLUMNS);
			expect(params.columns).not.toContain('role_details');
		});

		it('does not include WHERE clause (syncs everything)', () => {
			const opts = findOpts('uk-lrt-admin');
			const params = (opts!.shapeOptions as any).params;
			expect(params.where).toBeUndefined();
		});

		it('returns same instance on subsequent calls (singleton)', async () => {
			const second = await getAdminCollection();
			expect(second).toBe(adminCol);
		});
	});

	describe('getBrowseCollection', () => {
		it('creates collection with on-demand sync mode', () => {
			const opts = findOpts('uk-lrt-browse');
			expect(opts).toBeDefined();
			expect(opts!.syncMode).toBe('on-demand');
		});

		it('uses browse columns (lightweight subset)', () => {
			const opts = findOpts('uk-lrt-browse');
			const params = (opts!.shapeOptions as any).params;
			expect(params.columns).toEqual(UK_LRT_BROWSE_COLUMNS);
		});

		it('does not include WHERE clause (on-demand fetches per-query)', () => {
			const opts = findOpts('uk-lrt-browse');
			const params = (opts!.shapeOptions as any).params;
			expect(params.where).toBeUndefined();
		});

		it('returns same instance on subsequent calls (singleton)', async () => {
			const second = await getBrowseCollection();
			expect(second).toBe(browseCol);
		});
	});

	describe('getLatQueueCollection', () => {
		it('creates collection with eager sync mode', () => {
			const opts = findOpts('uk-lrt-lat-queue');
			expect(opts).toBeDefined();
			expect(opts!.syncMode).toBe('eager');
		});

		it('uses WHERE is_making = true', () => {
			const opts = findOpts('uk-lrt-lat-queue');
			const params = (opts!.shapeOptions as any).params;
			expect(params.where).toBe('is_making = true');
		});

		it('uses admin columns (same as admin, since it is an admin page)', () => {
			const opts = findOpts('uk-lrt-lat-queue');
			const params = (opts!.shapeOptions as any).params;
			expect(params.columns).toEqual(UK_LRT_ADMIN_COLUMNS);
		});

		it('returns same instance on subsequent calls (singleton)', async () => {
			const second = await getLatQueueCollection();
			expect(second).toBe(latQueueCol);
		});
	});

	describe('shared configuration', () => {
		it('all collections use uk_lrt table', () => {
			['uk-lrt-admin', 'uk-lrt-browse', 'uk-lrt-lat-queue'].forEach((id) => {
				const opts = findOpts(id);
				const params = (opts!.shapeOptions as any).params;
				expect(params.table).toBe('uk_lrt');
			});
		});

		it('all collections use Electric URL with /v1/shape path', () => {
			['uk-lrt-admin', 'uk-lrt-browse', 'uk-lrt-lat-queue'].forEach((id) => {
				const opts = findOpts(id);
				const url = (opts!.shapeOptions as any).url;
				expect(url).toBe('http://localhost:4003/api/electric/v1/shape');
			});
		});

		it('all collections have onError handler', () => {
			['uk-lrt-admin', 'uk-lrt-browse', 'uk-lrt-lat-queue'].forEach((id) => {
				const opts = findOpts(id);
				const onError = (opts!.shapeOptions as any).onError;
				expect(typeof onError).toBe('function');
			});
		});

		it('all collections use id as key', () => {
			['uk-lrt-admin', 'uk-lrt-browse', 'uk-lrt-lat-queue'].forEach((id) => {
				const opts = findOpts(id);
				const getKey = opts!.getKey as (item: { id: string }) => string;
				expect(getKey({ id: 'test-123' })).toBe('test-123');
			});
		});
	});
});

// ── Sync Status Store ───────────────────────────────────────────────────────

describe('syncStatus store', () => {
	it('can update connection state', () => {
		syncStatus.update((s) => ({
			...s,
			connected: true,
			syncing: false,
			recordCount: 19089
		}));

		const status = get(syncStatus);
		expect(status.connected).toBe(true);
		expect(status.syncing).toBe(false);
		expect(status.recordCount).toBe(19089);
	});

	it('can track errors', () => {
		syncStatus.update((s) => ({
			...s,
			error: 'Authentication required',
			syncing: false
		}));

		const status = get(syncStatus);
		expect(status.error).toBe('Authentication required');
		expect(status.syncing).toBe(false);
	});

	it('can track offline state', () => {
		syncStatus.update((s) => ({
			...s,
			offline: true,
			connected: false,
			error: 'Network unavailable'
		}));

		const status = get(syncStatus);
		expect(status.offline).toBe(true);
		expect(status.connected).toBe(false);
	});

	it('can update lastSyncTime', () => {
		const now = new Date();
		syncStatus.update((s) => ({
			...s,
			lastSyncTime: now
		}));

		const status = get(syncStatus);
		expect(status.lastSyncTime).toBe(now);
	});
});
