/**
 * UK LRT Record Schema
 *
 * Type definition for UK Legal/Regulatory Transport records.
 */

/**
 * UK LRT Record type matching the database schema
 */
export interface UkLrtRecord {
	id: string;
	name: string;
	title_en: string;
	year: number;
	number: string;
	type_code: string;
	type_class: string;
	family: string | null;
	family_ii: string | null;
	live: string | null;
	live_description: string | null;
	geo_extent: string | null;
	geo_region: string | null;
	geo_detail: string | null;
	md_restrict_extent: string | null;
	si_code: string | null;
	tags: string[] | null;
	function: string[] | null;
	// Role/Actor
	role: string[] | null;
	role_gvt: Record<string, unknown> | null;
	article_role: string | null;
	role_article: string | null;
	// Duty Type
	duty_type: string | null;
	duty_type_article: string | null;
	article_duty_type: string | null;
	// Duty Holder
	duty_holder: Record<string, unknown> | null;
	duty_holder_article: string | null;
	duty_holder_article_clause: string | null;
	article_duty_holder: string | null;
	article_duty_holder_clause: string | null;
	// Power Holder
	power_holder: Record<string, unknown> | null;
	power_holder_article: string | null;
	power_holder_article_clause: string | null;
	article_power_holder: string | null;
	article_power_holder_clause: string | null;
	// Rights Holder
	rights_holder: Record<string, unknown> | null;
	rights_holder_article: string | null;
	rights_holder_article_clause: string | null;
	article_rights_holder: string | null;
	article_rights_holder_clause: string | null;
	// Responsibility Holder
	responsibility_holder: Record<string, unknown> | null;
	responsibility_holder_article: string | null;
	responsibility_holder_article_clause: string | null;
	article_responsibility_holder: string | null;
	article_responsibility_holder_clause: string | null;
	// POPIMAR
	popimar: Record<string, unknown> | null;
	popimar_article: string | null;
	popimar_article_clause: string | null;
	article_popimar: string | null;
	article_popimar_clause: string | null;
	// Purpose
	purpose: Record<string, unknown> | null;
	is_making: number | null;
	enacted_by: string | null;
	amending: Record<string, unknown> | null;
	amended_by: Record<string, unknown> | null;
	md_date: string | null;
	md_made_date: string | null;
	md_enactment_date: string | null;
	md_coming_into_force_date: string | null;
	md_dct_valid_date: string | null;
	md_restrict_start_date: string | null;
	md_total_paras: number | null;
	md_body_paras: number | null;
	md_schedule_paras: number | null;
	md_attachment_paras: number | null;
	md_images: number | null;
	latest_amend_date: string | null;
	leg_gov_uk_url: string | null;
	created_at: string | null;
	updated_at: string | null;
}

/**
 * Transform raw Electric data to UkLrtRecord
 * Handles type conversions for numeric and JSON fields
 */
export function transformUkLrtRecord(data: Record<string, unknown>): UkLrtRecord {
	return {
		id: String(data.id),
		name: String(data.name || ''),
		title_en: String(data.title_en || ''),
		year: parseNumber(data.year) ?? 0,
		number: String(data.number || ''),
		type_code: String(data.type_code || ''),
		type_class: String(data.type_class || ''),
		family: parseString(data.family),
		family_ii: parseString(data.family_ii),
		live: parseString(data.live),
		live_description: parseString(data.live_description),
		geo_extent: parseString(data.geo_extent),
		geo_region: parseString(data.geo_region),
		geo_detail: parseString(data.geo_detail),
		md_restrict_extent: parseString(data.md_restrict_extent),
		si_code: parseString(data.si_code),
		tags: parseArray(data.tags),
		function: parseArray(data.function),
		role: parseArray(data.role),
		role_gvt: parseJson(data.role_gvt),
		article_role: parseString(data.article_role),
		role_article: parseString(data.role_article),
		duty_type: parseString(data.duty_type),
		duty_type_article: parseString(data.duty_type_article),
		article_duty_type: parseString(data.article_duty_type),
		duty_holder: parseJson(data.duty_holder),
		duty_holder_article: parseString(data.duty_holder_article),
		duty_holder_article_clause: parseString(data.duty_holder_article_clause),
		article_duty_holder: parseString(data.article_duty_holder),
		article_duty_holder_clause: parseString(data.article_duty_holder_clause),
		power_holder: parseJson(data.power_holder),
		power_holder_article: parseString(data.power_holder_article),
		power_holder_article_clause: parseString(data.power_holder_article_clause),
		article_power_holder: parseString(data.article_power_holder),
		article_power_holder_clause: parseString(data.article_power_holder_clause),
		rights_holder: parseJson(data.rights_holder),
		rights_holder_article: parseString(data.rights_holder_article),
		rights_holder_article_clause: parseString(data.rights_holder_article_clause),
		article_rights_holder: parseString(data.article_rights_holder),
		article_rights_holder_clause: parseString(data.article_rights_holder_clause),
		responsibility_holder: parseJson(data.responsibility_holder),
		responsibility_holder_article: parseString(data.responsibility_holder_article),
		responsibility_holder_article_clause: parseString(data.responsibility_holder_article_clause),
		article_responsibility_holder: parseString(data.article_responsibility_holder),
		article_responsibility_holder_clause: parseString(data.article_responsibility_holder_clause),
		popimar: parseJson(data.popimar),
		popimar_article: parseString(data.popimar_article),
		popimar_article_clause: parseString(data.popimar_article_clause),
		article_popimar: parseString(data.article_popimar),
		article_popimar_clause: parseString(data.article_popimar_clause),
		purpose: parseJson(data.purpose),
		is_making: parseNumber(data.is_making),
		enacted_by: parseString(data.enacted_by),
		amending: parseJson(data.amending),
		amended_by: parseJson(data.amended_by),
		md_date: parseString(data.md_date),
		md_made_date: parseString(data.md_made_date),
		md_enactment_date: parseString(data.md_enactment_date),
		md_coming_into_force_date: parseString(data.md_coming_into_force_date),
		md_dct_valid_date: parseString(data.md_dct_valid_date),
		md_restrict_start_date: parseString(data.md_restrict_start_date),
		md_total_paras: parseNumber(data.md_total_paras),
		md_body_paras: parseNumber(data.md_body_paras),
		md_schedule_paras: parseNumber(data.md_schedule_paras),
		md_attachment_paras: parseNumber(data.md_attachment_paras),
		md_images: parseNumber(data.md_images),
		latest_amend_date: parseString(data.latest_amend_date),
		leg_gov_uk_url: parseString(data.leg_gov_uk_url),
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

function parseJson(value: unknown): Record<string, unknown> | null {
	if (value === null || value === undefined) return null;
	if (typeof value === 'object') return value as Record<string, unknown>;
	if (typeof value === 'string') {
		try {
			return JSON.parse(value);
		} catch {
			return null;
		}
	}
	return null;
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
