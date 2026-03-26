/**
 * Tests for seedDefaultViews — ensures default view configs stay in sync.
 *
 * Issue #56: When code-defined default views change (e.g. column visibility,
 * pageSize), persisted views in PGLite must be updated on page load.
 */
import { describe, it, expect, vi } from 'vitest';
import { seedDefaultViews, _configsEqual, type ViewDef, type ViewActions } from './seed-defaults';
import type { ViewConfig, SavedView } from '@shotleybuilder/svelte-gridlite-views';

// ── Helpers ─────────────────────────────────────────────────────

function makeConfig(overrides: Partial<ViewConfig> = {}): ViewConfig {
	return {
		filters: [],
		filterLogic: 'and',
		sorting: [{ column: 'name', direction: 'asc' }],
		grouping: [],
		columnVisibility: { name: true, title: true, year: true },
		columnOrder: ['name', 'title', 'year'],
		columnWidths: {},
		pageSize: 25,
		...overrides
	};
}

function makeSavedView(name: string, config: ViewConfig, id?: string): SavedView {
	return {
		id: id ?? crypto.randomUUID(),
		gridId: 'test-grid',
		name,
		config,
		isDefault: false,
		usageCount: 0,
		lastUsed: new Date().toISOString(),
		createdAt: new Date().toISOString(),
		updatedAt: new Date().toISOString()
	};
}

function makeDef(name: string, config: ViewConfig, isDefault = false): ViewDef {
	return { name, description: `${name} view`, config, isDefault };
}

function mockActions(): ViewActions & {
	calls: { save: unknown[]; update: unknown[]; delete: unknown[] };
} {
	const calls = { save: [] as unknown[], update: [] as unknown[], delete: [] as unknown[] };
	return {
		calls,
		save: vi.fn(async (input) => {
			calls.save.push(input);
			return makeSavedView(input.name, input.config);
		}),
		update: vi.fn(async (id, updates) => {
			calls.update.push({ id, updates });
		}),
		delete: vi.fn(async (id) => {
			calls.delete.push(id);
		})
	};
}

// ── configsEqual ────────────────────────────────────────────────

describe('configsEqual', () => {
	it('returns true for identical configs', () => {
		const a = makeConfig();
		const b = makeConfig();
		expect(_configsEqual(a, b)).toBe(true);
	});

	it('detects columnVisibility change', () => {
		const a = makeConfig({ columnVisibility: { name: true, title: true, year: true } });
		const b = makeConfig({ columnVisibility: { name: true, title: true, year: false } });
		expect(_configsEqual(a, b)).toBe(false);
	});

	it('detects columnOrder change', () => {
		const a = makeConfig({ columnOrder: ['name', 'title', 'year'] });
		const b = makeConfig({ columnOrder: ['name', 'year', 'title'] });
		expect(_configsEqual(a, b)).toBe(false);
	});

	it('detects pageSize change', () => {
		const a = makeConfig({ pageSize: 25 });
		const b = makeConfig({ pageSize: 500 });
		expect(_configsEqual(a, b)).toBe(false);
	});

	it('treats undefined and null pageSize as equal', () => {
		const a = makeConfig({ pageSize: undefined });
		const b = makeConfig({ pageSize: undefined });
		// Both undefined → null via ?? null
		expect(_configsEqual(a, b)).toBe(true);
	});

	it('detects sorting change', () => {
		const a = makeConfig({ sorting: [{ column: 'name', direction: 'asc' }] });
		const b = makeConfig({ sorting: [{ column: 'lat_count', direction: 'desc' }] });
		expect(_configsEqual(a, b)).toBe(false);
	});

	it('detects new columns added to visibility', () => {
		const a = makeConfig({ columnVisibility: { name: true, title: true } });
		const b = makeConfig({ columnVisibility: { name: true, title: true, duty_type: true } });
		expect(_configsEqual(a, b)).toBe(false);
	});

	it('treats same columnVisibility with different key order as equal (JSONB round-trip)', () => {
		const a = makeConfig({
			columnVisibility: { name: true, title: true, year: false, type_code: true }
		});
		const b = makeConfig({
			columnVisibility: { type_code: true, year: false, name: true, title: true }
		});
		expect(_configsEqual(a, b)).toBe(true);
	});

	it('treats same columnWidths with different key order as equal', () => {
		const a = makeConfig({ columnWidths: { name: 100, title: 200 } });
		const b = makeConfig({ columnWidths: { title: 200, name: 100 } });
		expect(_configsEqual(a, b)).toBe(true);
	});
});

// ── seedDefaultViews ────────────────────────────────────────────

describe('seedDefaultViews', () => {
	it('seeds all views when none exist', async () => {
		const actions = mockActions();
		const defaults = [
			makeDef('View A', makeConfig()),
			makeDef('View B', makeConfig({ pageSize: 500 }))
		];

		const result = await seedDefaultViews(defaults, [], actions);

		expect(result.seeded).toEqual(['View A', 'View B']);
		expect(result.updated).toEqual([]);
		expect(actions.calls.save).toHaveLength(2);
	});

	it('does not update when config is unchanged', async () => {
		const actions = mockActions();
		const config = makeConfig();
		const defaults = [makeDef('View A', config)];
		const existing = [makeSavedView('View A', config, 'existing-id')];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.seeded).toEqual([]);
		expect(result.updated).toEqual([]);
		expect(actions.calls.update).toHaveLength(0);
		expect(actions.calls.save).toHaveLength(0);
	});

	it('updates existing view when columnVisibility changes', async () => {
		const actions = mockActions();
		const oldConfig = makeConfig({
			columnVisibility: { name: true, title: true, year: true, type_code: true },
			columnOrder: ['name', 'title', 'year', 'type_code']
		});
		const newConfig = makeConfig({
			columnVisibility: { name: true, title: true, live: true, live_source: true, duty_type: true },
			columnOrder: ['name', 'title', 'live', 'live_source', 'duty_type']
		});

		const defaults = [makeDef('LAT Cleanup', newConfig)];
		const existing = [makeSavedView('LAT Cleanup', oldConfig, 'lat-cleanup-id')];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.updated).toEqual(['LAT Cleanup']);
		expect(actions.calls.update).toHaveLength(1);
		expect(actions.calls.update[0]).toEqual({
			id: 'lat-cleanup-id',
			updates: { config: newConfig }
		});
	});

	it('updates existing view when pageSize changes', async () => {
		const actions = mockActions();
		const oldConfig = makeConfig({ pageSize: 25 });
		const newConfig = makeConfig({ pageSize: 500 });

		const defaults = [makeDef('LAT Cleanup', newConfig)];
		const existing = [makeSavedView('LAT Cleanup', oldConfig, 'lat-id')];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.updated).toEqual(['LAT Cleanup']);
		expect(actions.calls.update).toHaveLength(1);
	});

	it('handles mixed: some views exist, some new, some updated', async () => {
		const actions = mockActions();
		const configA = makeConfig();
		const configB_old = makeConfig({ pageSize: 25 });
		const configB_new = makeConfig({ pageSize: 500 });
		const configC = makeConfig({ sorting: [{ column: 'year', direction: 'desc' }] });

		const defaults = [
			makeDef('View A', configA), // exists, unchanged
			makeDef('View B', configB_new), // exists, needs update
			makeDef('View C', configC) // new, needs seeding
		];
		const existing = [
			makeSavedView('View A', configA, 'id-a'),
			makeSavedView('View B', configB_old, 'id-b')
		];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.seeded).toEqual(['View C']);
		expect(result.updated).toEqual(['View B']);
		expect(actions.calls.save).toHaveLength(1);
		expect(actions.calls.update).toHaveLength(1);
	});

	it('deduplicates views with same name', async () => {
		const actions = mockActions();
		const config = makeConfig();
		const defaults = [makeDef('View A', config)];
		const existing = [
			makeSavedView('View A', config, 'id-1'),
			makeSavedView('View A', config, 'id-2') // duplicate
		];

		await seedDefaultViews(defaults, existing, actions);

		expect(actions.calls.delete).toHaveLength(1);
		expect(actions.calls.delete[0]).toBe('id-2');
	});

	it('returns defaultViewId for existing default view', async () => {
		const actions = mockActions();
		const config = makeConfig();
		const defaults = [makeDef('Default View', config, true)];
		const existing = [makeSavedView('Default View', config, 'default-id')];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.defaultViewId).toBe('default-id');
	});

	it('returns defaultViewId for newly seeded default view', async () => {
		const actions = mockActions();
		const config = makeConfig();
		const defaults = [makeDef('Default View', config, true)];

		const result = await seedDefaultViews(defaults, [], actions);

		expect(result.defaultViewId).not.toBeNull();
		expect(result.seeded).toEqual(['Default View']);
	});

	it('detects PGLite deserialized config with undefined pageSize vs code-defined pageSize', async () => {
		const actions = mockActions();
		// PGLite rowToView returns pageSize: undefined when page_size is NULL
		const pgliteConfig = makeConfig();
		delete (pgliteConfig as unknown as Record<string, unknown>).pageSize;
		// Code defines pageSize: 500
		const codeConfig = makeConfig({ pageSize: 500 });

		const defaults = [makeDef('LAT Cleanup', codeConfig)];
		const existing = [makeSavedView('LAT Cleanup', pgliteConfig, 'lat-id')];

		const result = await seedDefaultViews(defaults, existing, actions);

		expect(result.updated).toEqual(['LAT Cleanup']);
	});
});
