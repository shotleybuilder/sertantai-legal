/**
 * LAT (Legal Articles Table) Record Schema
 *
 * Type definition for LAT records — one row per structural unit of legal text.
 * Each record represents an addressable unit: title, part, chapter, heading,
 * section, article, paragraph, schedule entry, etc.
 */

/**
 * LAT Record type matching the database schema.
 * Excludes embedding/token columns (AI-only, not synced to frontend).
 */
export interface LatRecord {
	section_id: string;
	law_name: string;
	law_id: string;
	sort_key: string;
	position: number;
	section_type: string;
	hierarchy_path: string | null;
	depth: number;
	part: string | null;
	chapter: string | null;
	heading_group: string | null;
	provision: string | null;
	paragraph: string | null;
	sub_paragraph: string | null;
	schedule: string | null;
	text: string;
	language: string;
	extent_code: string | null;
	amendment_count: number | null;
	modification_count: number | null;
	commencement_count: number | null;
	extent_count: number | null;
	editorial_count: number | null;
	legacy_id: string | null;
	created_at: string | null;
	updated_at: string | null;
}

/**
 * Columns to sync from lat table.
 * Excludes embedding, embedding_model, embedded_at, token_ids, tokenizer_model
 * (AI pipeline only — large arrays not needed in frontend).
 */
export const LAT_COLUMNS: string[] = [
	'section_id',
	'law_name',
	'law_id',
	'sort_key',
	'position',
	'section_type',
	'hierarchy_path',
	'depth',
	'part',
	'chapter',
	'heading_group',
	'provision',
	'paragraph',
	'sub_paragraph',
	'schedule',
	'text',
	'language',
	'extent_code',
	'amendment_count',
	'modification_count',
	'commencement_count',
	'extent_count',
	'editorial_count',
	'legacy_id',
	'created_at',
	'updated_at'
];

/**
 * Transform raw Electric data to LatRecord
 */
export function transformLatRecord(data: Record<string, unknown>): LatRecord {
	return {
		section_id: String(data.section_id),
		law_name: String(data.law_name || ''),
		law_id: String(data.law_id || ''),
		sort_key: String(data.sort_key || ''),
		position: parseNumber(data.position) ?? 0,
		section_type: String(data.section_type || ''),
		hierarchy_path: parseString(data.hierarchy_path),
		depth: parseNumber(data.depth) ?? 0,
		part: parseString(data.part),
		chapter: parseString(data.chapter),
		heading_group: parseString(data.heading_group),
		provision: parseString(data.provision),
		paragraph: parseString(data.paragraph),
		sub_paragraph: parseString(data.sub_paragraph),
		schedule: parseString(data.schedule),
		text: String(data.text || ''),
		language: String(data.language || 'en'),
		extent_code: parseString(data.extent_code),
		amendment_count: parseNumber(data.amendment_count),
		modification_count: parseNumber(data.modification_count),
		commencement_count: parseNumber(data.commencement_count),
		extent_count: parseNumber(data.extent_count),
		editorial_count: parseNumber(data.editorial_count),
		legacy_id: parseString(data.legacy_id),
		created_at: parseString(data.created_at),
		updated_at: parseString(data.updated_at)
	};
}

function parseString(value: unknown): string | null {
	if (value === null || value === undefined || value === '') return null;
	return String(value);
}

function parseNumber(value: unknown): number | null {
	if (value === null || value === undefined) return null;
	const num = typeof value === 'string' ? parseFloat(value) : Number(value);
	return isNaN(num) ? null : num;
}
