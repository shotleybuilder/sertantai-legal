/**
 * Query Helpers for TanStack DB Live Query Collections
 *
 * Translates svelte-table-kit FilterCondition[] into TanStack DB
 * query builder expressions for use with createLiveQueryCollection.
 *
 * Used by on-demand pages (browse) where filter changes need to
 * trigger loadSubset → fetchSnapshot from Electric.
 */

import { eq, gt, gte, lt, lte, and, not, ilike, isNull, inArray } from '@tanstack/db';

export interface FilterConditionInput {
	field: string;
	operator: string;
	value: unknown;
}

/**
 * Convert a single filter condition to a TanStack DB expression.
 * Returns null if the operator is unknown or the filter can't be translated.
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
function filterToExpr(source: any, filter: FilterConditionInput): ReturnType<typeof eq> | null {
	const field = source[filter.field];
	if (field === undefined) return null;

	const { operator, value } = filter;
	const strVal = String(value ?? '');

	switch (operator) {
		case 'equals':
			return eq(field, value);
		case 'not_equals':
			return not(eq(field, value));
		case 'contains':
			return ilike(field, `%${strVal}%`);
		case 'not_contains':
			return not(ilike(field, `%${strVal}%`));
		case 'starts_with':
			return ilike(field, `${strVal}%`);
		case 'ends_with':
			return ilike(field, `%${strVal}`);
		case 'greater_or_equal':
			return gte(field, value);
		case 'greater_than':
			return gt(field, value);
		case 'less_or_equal':
			return lte(field, value);
		case 'less_than':
			return lt(field, value);
		case 'is_after':
			return gt(field, strVal);
		case 'is_before':
			return lt(field, strVal);
		case 'is_empty':
			return isNull(field);
		case 'is_not_empty':
			return not(isNull(field));
		case 'in':
			return inArray(field, value);
		default:
			console.warn(`[query-helpers] Unknown filter operator: ${operator}`);
			return null;
	}
}

/**
 * Build a TanStack DB where callback from an array of filter conditions.
 * Returns null if no valid filters — caller should skip .where() in that case.
 *
 * Usage with createLiveQueryCollection:
 * ```
 * const whereCallback = filtersToWhereCallback(filters);
 * const liveQuery = createLiveQueryCollection((q) => {
 *   let query = q.from({ law: baseCollection });
 *   if (whereCallback) query = query.where(whereCallback);
 *   return query;
 * });
 * ```
 */
export function filtersToWhereCallback(
	filters: FilterConditionInput[]
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
): ((sources: any) => ReturnType<typeof eq>) | null {
	if (!filters || filters.length === 0) return null;

	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	return (sources: any) => {
		// sources is { law: proxy } — we use the first (and only) alias
		const sourceKey = Object.keys(sources)[0];
		const source = sources[sourceKey];

		const exprs = filters
			.map((f) => filterToExpr(source, f))
			.filter((e): e is ReturnType<typeof eq> => e !== null);

		if (exprs.length === 0) return eq(1, 1); // true — no valid filters
		if (exprs.length === 1) return exprs[0];
		return and(exprs[0], exprs[1], ...exprs.slice(2));
	};
}
