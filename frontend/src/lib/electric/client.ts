/**
 * ElectricSQL Client Configuration
 *
 * Provides the base URL and utilities for connecting to the Electric sync service.
 */

/**
 * Resolve the Electric sync URL from environment variables.
 *
 * The Electric client's URL constructor requires an absolute URL.
 * In production, VITE_ELECTRIC_URL is a relative path (e.g. "/api/electric")
 * which must be resolved against the browser's origin.
 *
 * IMPORTANT: The URL must go through the Phoenix backend proxy (/api/electric),
 * NOT directly to Electric (/electric). The proxy injects the ELECTRIC_SECRET
 * server-side. Direct Electric access returns 401 "Invalid API secret".
 * See: https://github.com/shotleybuilder/sertantai-legal/issues/41
 *
 * @param rawUrl - The raw VITE_ELECTRIC_URL value (absolute or relative path)
 * @param origin - The browser origin (window.location.origin), or undefined for SSR
 * @returns Absolute URL string suitable for the Electric client
 */
export function resolveElectricUrl(rawUrl: string, origin?: string): string {
	if (rawUrl.startsWith('/') && !rawUrl.startsWith('//') && origin) {
		return `${origin}${rawUrl}`;
	}
	return rawUrl;
}

// Electric sync service URL — goes through Phoenix backend proxy (Gatekeeper pattern)
// Dev: http://localhost:4003/api/electric, Prod: https://legal.sertantai.com/api/electric
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';
const rawElectricUrl = import.meta.env.VITE_ELECTRIC_URL || `${API_URL}/api/electric`;

export const ELECTRIC_URL = resolveElectricUrl(
	rawElectricUrl,
	typeof window !== 'undefined' ? window.location.origin : undefined
);

// Re-export for convenience
export { ELECTRIC_URL as electricUrl };

/**
 * Get the current year for default filtering
 */
export function getCurrentYear(): number {
	return new Date().getFullYear();
}

/**
 * Build the default WHERE clause for uk_lrt shapes.
 * Default: last 3 years of legislation.
 */
export function getDefaultUkLrtWhere(): string {
	const currentYear = getCurrentYear();
	const startYear = currentYear - 2; // Last 3 years (e.g., 2024, 2025, 2026)
	return `year >= ${startYear}`;
}

/**
 * Build a WHERE clause from TableKit filter conditions.
 * Combines user filters with sensible defaults.
 */
export function buildWhereClause(filters: FilterCondition[]): string {
	if (!filters || filters.length === 0) {
		return getDefaultUkLrtWhere();
	}

	const clauses = filters
		.map((filter) => {
			const { field, operator, value } = filter;

			// Handle different operators
			switch (operator) {
				case 'equals':
					return typeof value === 'string'
						? `${field} = '${escapeValue(value)}'`
						: `${field} = ${value}`;
				case 'not_equals':
					return typeof value === 'string'
						? `${field} != '${escapeValue(value)}'`
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
					return `${field} > ${value}`;
				case 'less_than':
					return `${field} < ${value}`;
				case 'greater_or_equal':
					return `${field} >= ${value}`;
				case 'less_or_equal':
					return `${field} <= ${value}`;
				case 'is_empty':
					return `${field} IS NULL OR ${field} = ''`;
				case 'is_not_empty':
					return `${field} IS NOT NULL AND ${field} != ''`;
				case 'is_before':
					return `${field} < '${escapeValue(String(value))}'`;
				case 'is_after':
					return `${field} > '${escapeValue(String(value))}'`;
				default:
					return null;
			}
		})
		.filter(Boolean);

	if (clauses.length === 0) {
		return getDefaultUkLrtWhere();
	}

	// Join with AND (could support OR logic in future)
	return clauses.join(' AND ');
}

/**
 * Escape single quotes in SQL values to prevent injection
 */
function escapeValue(value: string): string {
	return value.replace(/'/g, "''");
}

/**
 * Filter condition type (matches TableKit/svelte-table-kit)
 */
export interface FilterCondition {
	id: string;
	field: string;
	operator: FilterOperator;
	value: string | number | boolean;
}

export type FilterOperator =
	| 'equals'
	| 'not_equals'
	| 'contains'
	| 'not_contains'
	| 'starts_with'
	| 'ends_with'
	| 'is_empty'
	| 'is_not_empty'
	| 'greater_than'
	| 'less_than'
	| 'greater_or_equal'
	| 'less_or_equal'
	| 'is_before'
	| 'is_after';
