/**
 * Tests for ElectricSQL UK LRT sync utilities
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { get } from 'svelte/store';

// Mock browser environment
vi.mock('$app/environment', () => ({
	browser: true
}));

// Mock the TanStack DB collection
vi.mock('$lib/db/index.client', () => ({
	getUkLrtCollection: vi.fn()
}));

// Import after mocks
import {
	buildWhereFromFilters,
	syncStatus
} from './sync-uk-lrt';

describe('buildWhereFromFilters', () => {
	it('returns default 3-year filter when no filters provided', () => {
		const currentYear = new Date().getFullYear();
		const result = buildWhereFromFilters([]);
		expect(result).toBe(`year >= ${currentYear - 2}`);
	});

	it('returns default filter when filters array is empty', () => {
		const currentYear = new Date().getFullYear();
		const result = buildWhereFromFilters([]);
		expect(result).toBe(`year >= ${currentYear - 2}`);
	});

	it('builds equals clause for string value', () => {
		const filters = [
			{ field: 'family', operator: 'equals', value: 'FIRE' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("family = 'FIRE'");
	});

	it('builds equals clause for numeric value', () => {
		const filters = [
			{ field: 'year', operator: 'equals', value: 2024 }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe('year = 2024');
	});

	it('builds not_equals clause', () => {
		const filters = [
			{ field: 'live', operator: 'not_equals', value: 'Revoked' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("live != 'Revoked'");
	});

	it('builds contains clause with ILIKE', () => {
		const filters = [
			{ field: 'title_en', operator: 'contains', value: 'Safety' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("title_en ILIKE '%Safety%'");
	});

	it('builds not_contains clause', () => {
		const filters = [
			{ field: 'title_en', operator: 'not_contains', value: 'Draft' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("title_en NOT ILIKE '%Draft%'");
	});

	it('builds starts_with clause', () => {
		const filters = [
			{ field: 'name', operator: 'starts_with', value: 'UK_uksi' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("name ILIKE 'UK_uksi%'");
	});

	it('builds ends_with clause', () => {
		const filters = [
			{ field: 'name', operator: 'ends_with', value: '_2024' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("name ILIKE '%_2024'");
	});

	it('builds greater_than clause', () => {
		const filters = [
			{ field: 'year', operator: 'greater_than', value: 2020 }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe('year > 2020');
	});

	it('builds less_than clause', () => {
		const filters = [
			{ field: 'year', operator: 'less_than', value: 2025 }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe('year < 2025');
	});

	it('builds greater_or_equal clause', () => {
		const filters = [
			{ field: 'year', operator: 'greater_or_equal', value: 2022 }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe('year >= 2022');
	});

	it('builds less_or_equal clause', () => {
		const filters = [
			{ field: 'year', operator: 'less_or_equal', value: 2024 }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe('year <= 2024');
	});

	it('builds is_empty clause', () => {
		const filters = [
			{ field: 'family', operator: 'is_empty', value: null }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("(family IS NULL OR family = '')");
	});

	it('builds is_not_empty clause', () => {
		const filters = [
			{ field: 'family', operator: 'is_not_empty', value: null }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("(family IS NOT NULL AND family != '')");
	});

	it('builds is_before date clause', () => {
		const filters = [
			{ field: 'md_made_date', operator: 'is_before', value: '2024-01-01' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("md_made_date < '2024-01-01'");
	});

	it('builds is_after date clause', () => {
		const filters = [
			{ field: 'md_made_date', operator: 'is_after', value: '2023-12-31' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("md_made_date > '2023-12-31'");
	});

	it('combines multiple filters with AND', () => {
		const filters = [
			{ field: 'year', operator: 'greater_or_equal', value: 2023 },
			{ field: 'family', operator: 'equals', value: 'FIRE' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("year >= 2023 AND family = 'FIRE'");
	});

	it('handles three or more filters', () => {
		const filters = [
			{ field: 'year', operator: 'greater_or_equal', value: 2020 },
			{ field: 'live', operator: 'equals', value: 'Live' },
			{ field: 'geo_extent', operator: 'equals', value: 'E+W+S+NI' }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("year >= 2020 AND live = 'Live' AND geo_extent = 'E+W+S+NI'");
	});

	it('escapes single quotes in string values', () => {
		const filters = [
			{ field: 'title_en', operator: 'contains', value: "Worker's Rights" }
		];
		const result = buildWhereFromFilters(filters);
		expect(result).toBe("title_en ILIKE '%Worker''s Rights%'");
	});

	it('ignores unknown operators and returns default', () => {
		const filters = [
			{ field: 'year', operator: 'unknown_operator', value: 2024 }
		];
		const currentYear = new Date().getFullYear();
		const result = buildWhereFromFilters(filters);
		expect(result).toBe(`year >= ${currentYear - 2}`);
	});
});

describe('getDefaultWhere (via buildWhereFromFilters)', () => {
	it('returns current year minus 2 for default filter', () => {
		const currentYear = new Date().getFullYear();
		const expectedWhere = `year >= ${currentYear - 2}`;

		// When no filters, buildWhereFromFilters returns default
		const result = buildWhereFromFilters([]);
		expect(result).toBe(expectedWhere);
	});

	it('default filter covers 3 years', () => {
		const currentYear = new Date().getFullYear();
		const result = buildWhereFromFilters([]);

		// Extract year from result
		const match = result.match(/year >= (\d+)/);
		expect(match).not.toBeNull();

		const filterYear = parseInt(match![1], 10);
		expect(currentYear - filterYear).toBe(2); // 3 years: current, current-1, current-2
	});
});

describe('syncStatus store', () => {
	beforeEach(() => {
		// Reset store to initial state
		syncStatus.set({
			connected: false,
			syncing: false,
			offline: false,
			recordCount: 0,
			lastSyncTime: null,
			error: null,
			whereClause: '',
			reconnectAttempts: 0
		});
	});

	it('has correct initial state', () => {
		const status = get(syncStatus);
		expect(status.connected).toBe(false);
		expect(status.syncing).toBe(false);
		expect(status.offline).toBe(false);
		expect(status.recordCount).toBe(0);
		expect(status.lastSyncTime).toBeNull();
		expect(status.error).toBeNull();
		expect(status.whereClause).toBe('');
		expect(status.reconnectAttempts).toBe(0);
	});

	it('can update syncing state', () => {
		syncStatus.update(s => ({ ...s, syncing: true, whereClause: 'year >= 2024' }));

		const status = get(syncStatus);
		expect(status.syncing).toBe(true);
		expect(status.whereClause).toBe('year >= 2024');
	});

	it('can update connected state with record count', () => {
		syncStatus.update(s => ({
			...s,
			connected: true,
			syncing: false,
			recordCount: 544,
			lastSyncTime: new Date()
		}));

		const status = get(syncStatus);
		expect(status.connected).toBe(true);
		expect(status.syncing).toBe(false);
		expect(status.recordCount).toBe(544);
		expect(status.lastSyncTime).not.toBeNull();
	});

	it('can track offline and reconnect attempts', () => {
		syncStatus.update(s => ({
			...s,
			offline: true,
			reconnectAttempts: 3,
			error: 'Connection lost. Reconnecting (3/5)...'
		}));

		const status = get(syncStatus);
		expect(status.offline).toBe(true);
		expect(status.reconnectAttempts).toBe(3);
		expect(status.error).toContain('Reconnecting');
	});
});
