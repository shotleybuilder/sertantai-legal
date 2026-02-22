/**
 * Amendment Annotation Record Schema
 *
 * Type definition for amendment annotation records — one row per legislative
 * change annotation (F-codes, C-codes, I-codes, E-codes).
 */

/**
 * Amendment Annotation record type matching the database schema.
 */
export interface AnnotationRecord {
	id: string;
	law_name: string;
	law_id: string;
	code: string;
	code_type: string;
	source: string;
	text: string;
	affected_sections: string[] | null;
	created_at: string | null;
	updated_at: string | null;
}

/**
 * Columns to sync from amendment_annotations table.
 */
export const ANNOTATION_COLUMNS: string[] = [
	'id',
	'law_name',
	'law_id',
	'code',
	'code_type',
	'source',
	'text',
	'affected_sections',
	'created_at',
	'updated_at'
];

/**
 * Transform raw Electric data to AnnotationRecord
 */
export function transformAnnotationRecord(data: Record<string, unknown>): AnnotationRecord {
	return {
		id: String(data.id),
		law_name: String(data.law_name || ''),
		law_id: String(data.law_id || ''),
		code: String(data.code || ''),
		code_type: String(data.code_type || ''),
		source: String(data.source || ''),
		text: String(data.text || ''),
		affected_sections: parseArray(data.affected_sections),
		created_at: parseString(data.created_at),
		updated_at: parseString(data.updated_at)
	};
}

function parseString(value: unknown): string | null {
	if (value === null || value === undefined || value === '') return null;
	return String(value);
}

function parseArray(value: unknown): string[] | null {
	if (value === null || value === undefined) return null;
	if (Array.isArray(value)) return value.map(String);
	if (typeof value === 'string') {
		// PostgreSQL array format: {a,b,c}
		if (value.startsWith('{') && value.endsWith('}')) {
			const inner = value.slice(1, -1);
			if (inner === '') return [];
			return inner.split(',').map((s) => s.trim());
		}
		// JSON array format: ["a","b","c"]
		if (value.startsWith('[') && value.endsWith(']')) {
			try {
				const parsed = JSON.parse(value);
				if (Array.isArray(parsed)) return parsed.map(String);
			} catch {
				return null;
			}
		}
	}
	return null;
}
