/**
 * SQL Filter Builder
 *
 * Translates svelte-table-kit FilterCondition[] into parameterized SQL
 * WHERE clauses for PGLite queries. Replaces the TanStack DB query-helpers
 * which used `eq`, `gt`, `ilike`, etc. expression builders.
 *
 * All values are parameterized ($1, $2, ...) to prevent SQL injection.
 */

export interface FilterConditionInput {
	field: string;
	operator: string;
	value: unknown;
}

export interface SQLFilter {
	sql: string;
	params: unknown[];
}

// Allowed column names (prevent SQL injection via column names)
const VALID_COLUMNS = new Set([
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
	'making_classification',
	'domain',
	'role',
	'tags',
	'md_description',
	'acronym',
	'old_style_number',
	'md_dct_valid_date',
	'md_restrict_start_date',
	'purpose',
	'popimar',
	'leg_gov_uk_url',
	'updated_at'
]);

/**
 * Convert an array of filter conditions to a parameterized SQL WHERE clause.
 *
 * Returns `{ sql: '1=1', params: [] }` if no valid filters.
 *
 * @example
 * filtersToSQL([
 *   { field: 'md_date', operator: 'is_after', value: '2024-01-01' },
 *   { field: 'live', operator: 'equals', value: '✔ In force' }
 * ])
 * // → { sql: '"md_date" > $1 AND "live" = $2', params: ['2024-01-01', '✔ In force'] }
 */
export function filtersToSQL(filters: FilterConditionInput[]): SQLFilter {
	if (!filters || filters.length === 0) {
		return { sql: '1=1', params: [] };
	}

	const clauses: string[] = [];
	const params: unknown[] = [];

	for (const filter of filters) {
		if (!VALID_COLUMNS.has(filter.field)) {
			console.warn(`[sql-filters] Unknown column: ${filter.field}`);
			continue;
		}

		const col = `"${filter.field}"`;
		const clause = buildClause(col, filter.operator, filter.value, params);
		if (clause) {
			clauses.push(clause);
		}
	}

	if (clauses.length === 0) {
		return { sql: '1=1', params: [] };
	}

	return {
		sql: clauses.join(' AND '),
		params
	};
}

/**
 * Build a single SQL clause for one filter condition.
 * Pushes values into the shared params array and returns the clause string.
 */
function buildClause(
	col: string,
	operator: string,
	value: unknown,
	params: unknown[]
): string | null {
	switch (operator) {
		case 'equals': {
			params.push(value);
			return `${col} = $${params.length}`;
		}
		case 'not_equals': {
			params.push(value);
			return `${col} != $${params.length}`;
		}
		case 'contains': {
			params.push(`%${String(value ?? '')}%`);
			return `${col} ILIKE $${params.length}`;
		}
		case 'not_contains': {
			params.push(`%${String(value ?? '')}%`);
			return `${col} NOT ILIKE $${params.length}`;
		}
		case 'starts_with': {
			params.push(`${String(value ?? '')}%`);
			return `${col} ILIKE $${params.length}`;
		}
		case 'ends_with': {
			params.push(`%${String(value ?? '')}`);
			return `${col} ILIKE $${params.length}`;
		}
		case 'greater_or_equal': {
			params.push(value);
			return `${col} >= $${params.length}`;
		}
		case 'greater_than': {
			params.push(value);
			return `${col} > $${params.length}`;
		}
		case 'less_or_equal': {
			params.push(value);
			return `${col} <= $${params.length}`;
		}
		case 'less_than': {
			params.push(value);
			return `${col} < $${params.length}`;
		}
		case 'is_after': {
			params.push(String(value ?? ''));
			return `${col} > $${params.length}`;
		}
		case 'is_before': {
			params.push(String(value ?? ''));
			return `${col} < $${params.length}`;
		}
		case 'is_empty': {
			return `${col} IS NULL`;
		}
		case 'is_not_empty': {
			return `${col} IS NOT NULL`;
		}
		case 'in': {
			if (!Array.isArray(value) || value.length === 0) return null;
			const placeholders = value.map((v) => {
				params.push(v);
				return `$${params.length}`;
			});
			return `${col} IN (${placeholders.join(', ')})`;
		}
		default:
			console.warn(`[sql-filters] Unknown operator: ${operator}`);
			return null;
	}
}
