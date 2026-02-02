/**
 * UK LRT Record Schema
 *
 * Type definition for UK Legal/Regulatory Transport records.
 */

/**
 * Entry in the consolidated JSONB holder fields
 * Represents a single holder/duty_type/clause combination
 */
export interface HolderEntry {
	holder: string;
	duty_type: string;
	clause: string | null;
	article: string | null;
}

/**
 * Consolidated JSONB structure for holder fields (duties, rights, responsibilities, powers)
 * Replaces the 16 deprecated text columns with 4 structured JSONB fields
 */
export interface HolderJsonb {
	entries: HolderEntry[];
	holders: string[];
	articles: string[];
}

/**
 * Entry in the consolidated JSONB POPIMAR field
 * Represents a single category/article combination
 */
export interface PopimarEntry {
	category: string;
	article: string | null;
}

/**
 * Consolidated JSONB structure for POPIMAR field (Phase 3 Issue #15)
 * Replaces the 4 deprecated text columns (popimar_article, popimar_article_clause, article_popimar, article_popimar_clause)
 */
export interface PopimarJsonb {
	entries: PopimarEntry[];
	categories: string[];
	articles: string[];
}

/**
 * Entry in the consolidated JSONB Role fields
 * Represents a single role/article combination
 */
export interface RoleEntry {
	role: string;
	article: string | null;
}

/**
 * Consolidated JSONB structure for Role fields (Phase 3 Issue #16)
 * Replaces the 4 deprecated text columns (article_role, role_article, role_gvt_article, article_role_gvt)
 */
export interface RoleJsonb {
	entries: RoleEntry[];
	roles: string[];
	articles: string[];
}

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
	// Consolidated JSONB Role fields (Phase 3 Issue #16 - replaces 4 deprecated text columns)
	// Phase 4: Removed deprecated text columns - article_role, role_article
	role_details: RoleJsonb | null;
	role_gvt_details: RoleJsonb | null;
	// Duty Type
	duty_type: string | null;
	duty_type_article: string | null;
	article_duty_type: string | null;
	// Duty Holder
	duty_holder: Record<string, unknown> | null;
	// Power Holder
	power_holder: Record<string, unknown> | null;
	// Rights Holder
	rights_holder: Record<string, unknown> | null;
	// Responsibility Holder
	responsibility_holder: Record<string, unknown> | null;
	// Consolidated JSONB holder fields (Phase 3 - replaces 16 deprecated text columns)
	duties: HolderJsonb | null;
	rights: HolderJsonb | null;
	responsibilities: HolderJsonb | null;
	powers: HolderJsonb | null;
	// POPIMAR
	popimar: Record<string, unknown> | null;
	// Consolidated JSONB POPIMAR field (Phase 3 Issue #15 - replaces 4 deprecated text columns)
	popimar_details: PopimarJsonb | null;
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
	latest_rescind_date: string | null;
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
		// Consolidated JSONB Role fields (Phase 3 Issue #16)
		// Phase 4: Removed deprecated text columns - article_role, role_article
		role_details: parseRoleJsonb(data.role_details),
		role_gvt_details: parseRoleJsonb(data.role_gvt_details),
		duty_type: parseString(data.duty_type),
		duty_type_article: parseString(data.duty_type_article),
		article_duty_type: parseString(data.article_duty_type),
		duty_holder: parseJson(data.duty_holder),
		power_holder: parseJson(data.power_holder),
		rights_holder: parseJson(data.rights_holder),
		responsibility_holder: parseJson(data.responsibility_holder),
		// Consolidated JSONB holder fields (Phase 3)
		duties: parseHolderJsonb(data.duties),
		rights: parseHolderJsonb(data.rights),
		responsibilities: parseHolderJsonb(data.responsibilities),
		powers: parseHolderJsonb(data.powers),
		popimar: parseJson(data.popimar),
		// Consolidated JSONB POPIMAR field (Phase 3 Issue #15)
		popimar_details: parsePopimarJsonb(data.popimar_details),
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
		latest_rescind_date: parseString(data.latest_rescind_date),
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

/**
 * Parse consolidated JSONB holder fields (duties, rights, responsibilities, powers)
 */
function parseHolderJsonb(value: unknown): HolderJsonb | null {
	if (value === null || value === undefined) return null;

	let parsed: unknown = value;
	if (typeof value === 'string') {
		try {
			parsed = JSON.parse(value);
		} catch {
			return null;
		}
	}

	if (typeof parsed !== 'object' || parsed === null) return null;

	const obj = parsed as Record<string, unknown>;

	// Validate structure
	if (!Array.isArray(obj.entries)) return null;

	return {
		entries: (obj.entries as unknown[]).map((entry) => {
			const e = entry as Record<string, unknown>;
			return {
				holder: String(e.holder || ''),
				duty_type: String(e.duty_type || ''),
				clause: e.clause ? String(e.clause) : null,
				article: e.article ? String(e.article) : null
			};
		}),
		holders: Array.isArray(obj.holders) ? obj.holders.map(String) : [],
		articles: Array.isArray(obj.articles) ? obj.articles.map(String) : []
	};
}

/**
 * Parse consolidated JSONB Role fields (Phase 3 Issue #16)
 */
function parseRoleJsonb(value: unknown): RoleJsonb | null {
	if (value === null || value === undefined) return null;

	let parsed: unknown = value;
	if (typeof value === 'string') {
		try {
			parsed = JSON.parse(value);
		} catch {
			return null;
		}
	}

	if (typeof parsed !== 'object' || parsed === null) return null;

	const obj = parsed as Record<string, unknown>;

	// Validate structure
	if (!Array.isArray(obj.entries)) return null;

	return {
		entries: (obj.entries as unknown[]).map((entry) => {
			const e = entry as Record<string, unknown>;
			return {
				role: String(e.role || ''),
				article: e.article ? String(e.article) : null
			};
		}),
		roles: Array.isArray(obj.roles) ? obj.roles.map(String) : [],
		articles: Array.isArray(obj.articles) ? obj.articles.map(String) : []
	};
}

/**
 * Parse consolidated JSONB POPIMAR field (Phase 3 Issue #15)
 */
function parsePopimarJsonb(value: unknown): PopimarJsonb | null {
	if (value === null || value === undefined) return null;

	let parsed: unknown = value;
	if (typeof value === 'string') {
		try {
			parsed = JSON.parse(value);
		} catch {
			return null;
		}
	}

	if (typeof parsed !== 'object' || parsed === null) return null;

	const obj = parsed as Record<string, unknown>;

	// Validate structure
	if (!Array.isArray(obj.entries)) return null;

	return {
		entries: (obj.entries as unknown[]).map((entry) => {
			const e = entry as Record<string, unknown>;
			return {
				category: String(e.category || ''),
				article: e.article ? String(e.article) : null
			};
		}),
		categories: Array.isArray(obj.categories) ? obj.categories.map(String) : [],
		articles: Array.isArray(obj.articles) ? obj.articles.map(String) : []
	};
}
