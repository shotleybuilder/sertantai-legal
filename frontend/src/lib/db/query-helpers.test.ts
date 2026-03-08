/**
 * Tests for TanStack DB query helpers.
 *
 * Covers filtersToWhereCallback() which translates svelte-table-kit
 * FilterCondition[] into TanStack DB expression trees for use with
 * createLiveQueryCollection.
 */

import { describe, it, expect, vi } from 'vitest';
import { filtersToWhereCallback, type FilterConditionInput } from './query-helpers';

/**
 * Create a proxy that mimics a TanStack DB source object.
 * In real usage, the query builder passes { alias: proxy } where
 * proxy.field returns a ref like { type: 'ref', path: ['alias', 'field'] }.
 */
function createSourceProxy(alias: string = 'law') {
	const handler: ProxyHandler<Record<string, unknown>> = {
		get(_target, prop: string) {
			return { type: 'ref', path: [alias, prop] };
		}
	};
	return new Proxy({} as Record<string, unknown>, handler);
}

/** Helper: invoke the callback with a mock sources object */
function evalCallback(callback: ReturnType<typeof filtersToWhereCallback>, alias: string = 'law') {
	if (!callback) return null;
	return callback({ [alias]: createSourceProxy(alias) });
}

/** Helper: shorthand for building a single-filter callback and evaluating it */
function evalFilter(filter: FilterConditionInput, alias: string = 'law') {
	const cb = filtersToWhereCallback([filter]);
	return evalCallback(cb, alias);
}

describe('filtersToWhereCallback', () => {
	// ── Null / empty cases ──────────────────────────────────────────

	describe('empty inputs', () => {
		it('returns null for empty array', () => {
			expect(filtersToWhereCallback([])).toBeNull();
		});

		it('returns null for undefined-ish input', () => {
			expect(filtersToWhereCallback(null as unknown as FilterConditionInput[])).toBeNull();
		});
	});

	// ── Equality operators ──────────────────────────────────────────

	describe('equals operator', () => {
		it('produces eq expression for string value', () => {
			const result = evalFilter({ field: 'family', operator: 'equals', value: 'FIRE' });
			expect(result).toMatchObject({
				type: 'func',
				name: 'eq',
				args: [
					{ type: 'ref', path: ['law', 'family'] },
					{ type: 'val', value: 'FIRE' }
				]
			});
		});

		it('produces eq expression for numeric value', () => {
			const result = evalFilter({ field: 'year', operator: 'equals', value: 2024 });
			expect(result).toMatchObject({
				name: 'eq',
				args: [
					{ type: 'ref', path: ['law', 'year'] },
					{ type: 'val', value: 2024 }
				]
			});
		});

		it('produces eq expression for boolean value', () => {
			const result = evalFilter({ field: 'is_making', operator: 'equals', value: true });
			expect(result).toMatchObject({
				name: 'eq',
				args: [
					{ type: 'ref', path: ['law', 'is_making'] },
					{ type: 'val', value: true }
				]
			});
		});
	});

	describe('not_equals operator', () => {
		it('produces not(eq(...)) expression', () => {
			const result = evalFilter({ field: 'live', operator: 'not_equals', value: 'Revoked' });
			expect(result).toMatchObject({
				name: 'not',
				args: [
					{
						name: 'eq',
						args: [
							{ type: 'ref', path: ['law', 'live'] },
							{ type: 'val', value: 'Revoked' }
						]
					}
				]
			});
		});
	});

	// ── String matching operators ───────────────────────────────────

	describe('contains operator', () => {
		it('produces ilike expression with % wildcards', () => {
			const result = evalFilter({ field: 'title_en', operator: 'contains', value: 'Safety' });
			expect(result).toMatchObject({
				name: 'ilike',
				args: [
					{ type: 'ref', path: ['law', 'title_en'] },
					{ type: 'val', value: '%Safety%' }
				]
			});
		});
	});

	describe('not_contains operator', () => {
		it('produces not(ilike(...)) expression', () => {
			const result = evalFilter({ field: 'title_en', operator: 'not_contains', value: 'Draft' });
			expect(result).toMatchObject({
				name: 'not',
				args: [
					{
						name: 'ilike',
						args: [
							{ type: 'ref', path: ['law', 'title_en'] },
							{ type: 'val', value: '%Draft%' }
						]
					}
				]
			});
		});
	});

	describe('starts_with operator', () => {
		it('produces ilike expression with trailing %', () => {
			const result = evalFilter({ field: 'name', operator: 'starts_with', value: 'UK_uksi' });
			expect(result).toMatchObject({
				name: 'ilike',
				args: [
					{ type: 'ref', path: ['law', 'name'] },
					{ type: 'val', value: 'UK_uksi%' }
				]
			});
		});
	});

	describe('ends_with operator', () => {
		it('produces ilike expression with leading %', () => {
			const result = evalFilter({ field: 'name', operator: 'ends_with', value: '_2024' });
			expect(result).toMatchObject({
				name: 'ilike',
				args: [
					{ type: 'ref', path: ['law', 'name'] },
					{ type: 'val', value: '%_2024' }
				]
			});
		});
	});

	// ── Comparison operators ────────────────────────────────────────

	describe('greater_than operator', () => {
		it('produces gt expression', () => {
			const result = evalFilter({ field: 'year', operator: 'greater_than', value: 2020 });
			expect(result).toMatchObject({
				name: 'gt',
				args: [
					{ type: 'ref', path: ['law', 'year'] },
					{ type: 'val', value: 2020 }
				]
			});
		});
	});

	describe('less_than operator', () => {
		it('produces lt expression', () => {
			const result = evalFilter({ field: 'year', operator: 'less_than', value: 2025 });
			expect(result).toMatchObject({
				name: 'lt',
				args: [
					{ type: 'ref', path: ['law', 'year'] },
					{ type: 'val', value: 2025 }
				]
			});
		});
	});

	describe('greater_or_equal operator', () => {
		it('produces gte expression', () => {
			const result = evalFilter({ field: 'year', operator: 'greater_or_equal', value: 2022 });
			expect(result).toMatchObject({
				name: 'gte',
				args: [
					{ type: 'ref', path: ['law', 'year'] },
					{ type: 'val', value: 2022 }
				]
			});
		});
	});

	describe('less_or_equal operator', () => {
		it('produces lte expression', () => {
			const result = evalFilter({ field: 'year', operator: 'less_or_equal', value: 2024 });
			expect(result).toMatchObject({
				name: 'lte',
				args: [
					{ type: 'ref', path: ['law', 'year'] },
					{ type: 'val', value: 2024 }
				]
			});
		});
	});

	// ── Date operators ──────────────────────────────────────────────

	describe('is_after operator', () => {
		it('produces gt expression with string date value', () => {
			const result = evalFilter({
				field: 'md_made_date',
				operator: 'is_after',
				value: '2023-12-31'
			});
			expect(result).toMatchObject({
				name: 'gt',
				args: [
					{ type: 'ref', path: ['law', 'md_made_date'] },
					{ type: 'val', value: '2023-12-31' }
				]
			});
		});
	});

	describe('is_before operator', () => {
		it('produces lt expression with string date value', () => {
			const result = evalFilter({
				field: 'md_made_date',
				operator: 'is_before',
				value: '2024-01-01'
			});
			expect(result).toMatchObject({
				name: 'lt',
				args: [
					{ type: 'ref', path: ['law', 'md_made_date'] },
					{ type: 'val', value: '2024-01-01' }
				]
			});
		});
	});

	// ── Null operators ──────────────────────────────────────────────

	describe('is_empty operator', () => {
		it('produces isNull expression', () => {
			const result = evalFilter({ field: 'family', operator: 'is_empty', value: null });
			expect(result).toMatchObject({
				name: 'isNull',
				args: [{ type: 'ref', path: ['law', 'family'] }]
			});
		});
	});

	describe('is_not_empty operator', () => {
		it('produces not(isNull(...)) expression', () => {
			const result = evalFilter({ field: 'family', operator: 'is_not_empty', value: null });
			expect(result).toMatchObject({
				name: 'not',
				args: [
					{
						name: 'isNull',
						args: [{ type: 'ref', path: ['law', 'family'] }]
					}
				]
			});
		});
	});

	// ── Array operator ──────────────────────────────────────────────

	describe('in operator', () => {
		it('produces inArray expression', () => {
			const result = evalFilter({
				field: 'type_code',
				operator: 'in',
				value: ['ukpga', 'uksi']
			});
			expect(result).toMatchObject({
				name: 'in', // TanStack DB names it 'in' internally despite the `inArray` export
				args: [
					{ type: 'ref', path: ['law', 'type_code'] },
					{ type: 'val', value: ['ukpga', 'uksi'] }
				]
			});
		});
	});

	// ── Unknown / invalid operators ─────────────────────────────────

	describe('unknown operator', () => {
		it('logs warning and returns fallback eq(1,1) for single unknown filter', () => {
			const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
			const result = evalFilter({ field: 'year', operator: 'magic_filter', value: 42 });

			expect(warnSpy).toHaveBeenCalledWith(
				expect.stringContaining('Unknown filter operator: magic_filter')
			);
			// Single unknown filter → no valid exprs → fallback eq(1, 1)
			expect(result).toMatchObject({
				name: 'eq',
				args: [
					{ type: 'val', value: 1 },
					{ type: 'val', value: 1 }
				]
			});
			warnSpy.mockRestore();
		});
	});

	// ── Multiple filter combination ─────────────────────────────────

	describe('combining multiple filters', () => {
		it('combines two filters with and()', () => {
			const cb = filtersToWhereCallback([
				{ field: 'year', operator: 'greater_or_equal', value: 2023 },
				{ field: 'family', operator: 'equals', value: 'FIRE' }
			]);
			const result = evalCallback(cb);

			expect(result).toMatchObject({
				name: 'and',
				args: [
					{
						name: 'gte',
						args: [
							{ type: 'ref', path: ['law', 'year'] },
							{ type: 'val', value: 2023 }
						]
					},
					{
						name: 'eq',
						args: [
							{ type: 'ref', path: ['law', 'family'] },
							{ type: 'val', value: 'FIRE' }
						]
					}
				]
			});
		});

		it('combines three filters with and()', () => {
			const cb = filtersToWhereCallback([
				{ field: 'year', operator: 'greater_or_equal', value: 2020 },
				{ field: 'live', operator: 'equals', value: 'Live' },
				{ field: 'geo_extent', operator: 'equals', value: 'E+W+S+NI' }
			]);
			const result = evalCallback(cb);

			expect(result).toMatchObject({ name: 'and' });
			// and() should have all 3 expressions as args
			expect((result as any).args).toHaveLength(3);
			expect((result as any).args[0].name).toBe('gte');
			expect((result as any).args[1].name).toBe('eq');
			expect((result as any).args[2].name).toBe('eq');
		});

		it('returns single expression unwrapped (no and) for one filter', () => {
			const cb = filtersToWhereCallback([{ field: 'year', operator: 'equals', value: 2024 }]);
			const result = evalCallback(cb);

			// Single filter should NOT be wrapped in and()
			expect(result).toMatchObject({ name: 'eq' });
		});

		it('skips unknown operators and combines remaining valid filters', () => {
			const warnSpy = vi.spyOn(console, 'warn').mockImplementation(() => {});
			const cb = filtersToWhereCallback([
				{ field: 'year', operator: 'greater_or_equal', value: 2020 },
				{ field: 'family', operator: 'magic', value: 'FIRE' },
				{ field: 'live', operator: 'equals', value: 'Live' }
			]);
			const result = evalCallback(cb);

			// 2 valid filters → and()
			expect(result).toMatchObject({ name: 'and' });
			expect((result as any).args).toHaveLength(2);
			expect((result as any).args[0].name).toBe('gte');
			expect((result as any).args[1].name).toBe('eq');

			warnSpy.mockRestore();
		});
	});

	// ── Source alias ─────────────────────────────────────────────────

	describe('source alias handling', () => {
		it('uses the first key from sources as the alias', () => {
			const cb = filtersToWhereCallback([{ field: 'year', operator: 'equals', value: 2024 }]);
			const result = evalCallback(cb, 'record');

			expect(result).toMatchObject({
				name: 'eq',
				args: [
					{ type: 'ref', path: ['record', 'year'] },
					{ type: 'val', value: 2024 }
				]
			});
		});
	});

	// ── Realistic saved view scenarios ──────────────────────────────

	describe('realistic filter scenarios', () => {
		it('handles "This Month" view (date range + active)', () => {
			const now = new Date();
			const startOfMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`;

			const cb = filtersToWhereCallback([
				{ field: 'md_date', operator: 'is_after', value: startOfMonth },
				{ field: 'live', operator: 'not_equals', value: 'Revoked' }
			]);
			const result = evalCallback(cb);

			expect(result).toMatchObject({ name: 'and' });
			expect((result as any).args[0].name).toBe('gt');
			expect((result as any).args[1].name).toBe('not');
		});

		it('handles "Making Laws" view (boolean + family filter)', () => {
			const cb = filtersToWhereCallback([
				{ field: 'is_making', operator: 'equals', value: true },
				{ field: 'family', operator: 'contains', value: 'FIRE' }
			]);
			const result = evalCallback(cb);

			expect(result).toMatchObject({ name: 'and' });
			expect((result as any).args[0]).toMatchObject({
				name: 'eq',
				args: [{ path: ['law', 'is_making'] }, { value: true }]
			});
			expect((result as any).args[1]).toMatchObject({
				name: 'ilike',
				args: [{ path: ['law', 'family'] }, { value: '%FIRE%' }]
			});
		});

		it('handles "Last 3 Years" view (year range)', () => {
			const currentYear = new Date().getFullYear();
			const cb = filtersToWhereCallback([
				{ field: 'year', operator: 'greater_or_equal', value: currentYear - 2 }
			]);
			const result = evalCallback(cb);

			expect(result).toMatchObject({
				name: 'gte',
				args: [{ path: ['law', 'year'] }, { value: currentYear - 2 }]
			});
		});
	});
});
