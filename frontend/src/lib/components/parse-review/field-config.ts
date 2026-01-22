/**
 * Field configuration for ParseReviewModal
 *
 * Derived from docs/LRT-SCHEMA.md v0.7
 * Field labels use "Friendly Name" column from schema
 * Field order matches table order in schema document
 */

import type { ParseStage } from '$lib/api/scraper';

/**
 * Maps database column names to human-readable labels
 * Source: LRT-SCHEMA.md Friendly Name column
 */
export const FIELD_LABELS: Record<string, string> = {
	// Credentials
	id: 'ID',
	name: 'Name',
	title_en: 'Title',
	year: 'Year',
	number: 'Number',
	number_int: 'Number (Sortable)',
	type_code: 'Type Code',
	type_desc: 'Type Description',
	type_class: 'Type Class',
	domain: 'Domain',
	acronym: 'Acronym',
	old_style_number: 'Old Style Number',

	// Description
	family: 'Family',
	family_ii: 'Sub-Family',
	si_code: 'SI Codes',
	tags: 'Tags',
	md_description: 'Description',
	md_subjects: 'Subjects',

	// Status
	live: 'Status',
	live_description: 'Status Description',

	// Geographic Extent
	geo_extent: 'Geographic Extent',
	geo_region: 'Region',
	geo_detail: 'Detail',
	md_restrict_extent: 'Restriction Extent',

	// Metadata - Dates
	md_date: 'Primary Date',
	md_made_date: 'Made Date',
	md_enactment_date: 'Enacted Date',
	md_coming_into_force_date: 'In Force Date',
	md_dct_valid_date: 'DCT Valid Date',
	md_modified: 'Modified Date',
	md_restrict_start_date: 'Restriction Start',
	latest_amend_date: 'Latest Amendment',
	latest_change_date: 'Latest Change',
	latest_rescind_date: 'Latest Rescind',

	// Metadata - Document Statistics
	md_total_paras: 'Total Paragraphs',
	md_body_paras: 'Body Paragraphs',
	md_schedule_paras: 'Schedule Paragraphs',
	md_attachment_paras: 'Attachment Paragraphs',
	md_images: 'Images',

	// Function - Flags
	function: 'Function',
	is_making: 'Is Making',
	is_commencing: 'Is Commencing',
	is_amending: 'Is Amending',
	is_rescinding: 'Is Rescinding',
	is_enacting: 'Is Enacting',

	// Function - Enacting
	enacted_by: 'Enacted By',
	enacted_by_meta: 'Enacted By (Meta)',
	enacting: 'Enacts',

	// Function - Self-Affects
	stats_self_affects_count: 'Self Amendments',
	stats_self_affects_count_per_law_detailed: 'Self Affects (Detail)',

	// Function - Amending (this law affects others)
	amending_stats_affects_count: 'Affects Count',
	amending_stats_affected_laws_count: 'Affected Laws Count',
	amending_stats_affects_count_per_law: 'Affects Per Law',
	amending_stats_affects_count_per_law_detailed: 'Affects Per Law (Detail)',
	amending: 'Amends',

	// Function - Rescinding (this law rescinds others)
	rescinding_stats_rescinding_laws_count: 'Rescinded Laws Count',
	rescinding_stats_rescinding_count_per_law: 'Rescinding Per Law',
	rescinding_stats_rescinding_count_per_law_detailed: 'Rescinding Per Law (Detail)',
	rescinding: 'Rescinds',

	// Function - Amended By (this law is affected by others)
	amended_by_stats_affected_by_count: 'Affected By Count',
	amended_by_stats_affected_by_laws_count: 'Amending Laws Count',
	amended_by_stats_affected_by_count_per_law: 'Affected By Per Law',
	amended_by_stats_affected_by_count_per_law_detailed: 'Affected By Per Law (Detail)',
	amended_by: 'Amended By',

	// Function - Rescinded By (this law is rescinded by others)
	rescinded_by_stats_rescinded_by_laws_count: 'Rescinding Laws Count',
	rescinded_by_stats_rescinded_by_count_per_law: 'Rescinded By Per Law',
	rescinded_by_stats_rescinded_by_count_per_law_detailed: 'Rescinded By Per Law (Detail)',
	rescinded_by: 'Rescinded By',

	// Function - Linked (Graph Edges)
	linked_enacted_by: 'Linked Enacted By',
	linked_amending: 'Linked Amends',
	linked_amended_by: 'Linked Amended By',
	linked_rescinding: 'Linked Rescinds',
	linked_rescinded_by: 'Linked Rescinded By',

	// Taxa - Purpose
	purpose: 'Purpose',

	// Taxa - Roles (DRRP Model)
	role: 'Role',
	article_role: 'Article Role',
	role_article: 'Role Article',
	role_gvt: 'Role Gvt',
	role_gvt_article: 'Role Gvt Article',
	article_role_gvt: 'Article Role Gvt',

	// Taxa - Duty Type
	duty_type: 'Duty Type',
	duty_type_article: 'Duty Type Article',
	article_duty_type: 'Article Duty Type',

	// Taxa - Duty Holder
	duty_holder: 'Duty Holder',
	duty_holder_article: 'Duty Holder Article',
	duty_holder_article_clause: 'Duty Holder Article Clause',
	article_duty_holder: 'Article Duty Holder',
	article_duty_holder_clause: 'Article Duty Holder Clause',

	// Taxa - Rights Holder
	rights_holder: 'Rights Holder',
	rights_holder_article: 'Rights Holder Article',
	rights_holder_article_clause: 'Rights Holder Article Clause',
	article_rights_holder: 'Article Rights Holder',
	article_rights_holder_clause: 'Article Rights Holder Clause',

	// Taxa - Responsibility Holder
	responsibility_holder: 'Responsibility Holder',
	responsibility_holder_article: 'Responsibility Holder Article',
	responsibility_holder_article_clause: 'Responsibility Holder Article Clause',
	article_responsibility_holder: 'Article Responsibility Holder',
	article_responsibility_holder_clause: 'Article Responsibility Holder Clause',

	// Taxa - Power Holder
	power_holder: 'Power Holder',
	power_holder_article: 'Power Holder Article',
	power_holder_article_clause: 'Power Holder Article Clause',
	article_power_holder: 'Article Power Holder',
	article_power_holder_clause: 'Article Power Holder Clause',

	// Taxa - POPIMAR
	popimar: 'POPIMAR',
	popimar_article: 'POPIMAR Article',
	popimar_article_clause: 'POPIMAR Article Clause',
	article_popimar: 'Article POPIMAR',
	article_popimar_clause: 'Article POPIMAR Clause',

	// Change Logs
	amending_change_log: 'Amending Change Log',
	amended_by_change_log: 'Amended By Change Log',
	record_change_log: 'Record Change Log',

	// External
	leg_gov_uk_url: 'legislation.gov.uk URL',

	// Timestamps
	created_at: 'Created At',
	updated_at: 'Updated At'
};

/**
 * Get field label with fallback to formatted field name
 */
export function getFieldLabel(field: string): string {
	if (FIELD_LABELS[field]) {
		return FIELD_LABELS[field];
	}
	// Fallback: convert snake_case to Title Case
	return field
		.split('_')
		.map((word) => word.charAt(0).toUpperCase() + word.slice(1))
		.join(' ');
}

/**
 * Field type for rendering hints
 */
export type FieldType =
	| 'text'
	| 'date'
	| 'number'
	| 'boolean'
	| 'array'
	| 'json'
	| 'url'
	| 'multiline';

/**
 * Field configuration for a single field
 */
export interface FieldConfig {
	key: string;
	label: string;
	type: FieldType;
	stage: ParseStage | 'input' | 'derived' | 'system';
	/** Alternative keys to check (for API variations) */
	altKeys?: string[];
	/** Whether this field should be hidden in create mode */
	hideInCreate?: boolean;
	/** Whether this field should be hidden when empty */
	hideWhenEmpty?: boolean;
	/** Whether this field is editable (uses custom rendering in modal) */
	editable?: boolean;
}

/**
 * Subsection configuration
 */
export interface SubsectionConfig {
	id: string;
	title: string;
	fields: FieldConfig[];
	defaultExpanded?: boolean;
}

/**
 * Section configuration
 */
export interface SectionConfig {
	id: string;
	title: string;
	/** Primary parse stage for this section (for re-parse controls) */
	stage?: ParseStage;
	/** Whether section has subsections or direct fields */
	subsections?: SubsectionConfig[];
	fields?: FieldConfig[];
	defaultExpanded?: boolean;
}

/**
 * Complete section configuration matching LRT-SCHEMA.md structure
 *
 * Structure follows the blueprint exactly:
 * - STAGE 1 💠 metadata: Credentials, Description, Dates, Document Statistics
 * - STAGE 2 📍 extent: Geographic Extent
 * - STAGE 3 🚀 enacted_by: Enacting
 * - STAGE 4 🔄 amendments: Function, Self-Affects, Amending, Amended By, Rescinding, Rescinded By
 * - STAGE 5 🚫 repeal_revoke: Status
 * - STAGE 6 🦋 taxa: Purpose, Roles, Duty Type, Duty Holder, Rights Holder, etc.
 */
export const SECTION_CONFIG: SectionConfig[] = [
	// ==========================================
	// STAGE 1 💠 metadata
	// ==========================================
	{
		id: 'stage1_metadata',
		title: 'STAGE 1 💠 metadata',
		stage: 'metadata',
		defaultExpanded: true,
		subsections: [
			{
				id: 'credentials',
				title: 'Credentials',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md Credentials table
					{
						key: 'id',
						label: 'ID',
						type: 'text',
						stage: 'system',
						hideInCreate: true,
						hideWhenEmpty: true
					},
					{ key: 'name', label: 'Name', type: 'text', stage: 'input' },
					{ key: 'type_code', label: 'Type Code', type: 'text', stage: 'input' },
					{ key: 'year', label: 'Year', type: 'number', stage: 'input', altKeys: ['Year'] },
					{ key: 'number', label: 'Number', type: 'text', stage: 'input', altKeys: ['Number'] },
					{
						key: 'old_style_number',
						label: 'Old Style Number',
						type: 'text',
						stage: 'input',
						hideWhenEmpty: true
					},
					{
						key: 'title_en',
						label: 'Title',
						type: 'text',
						stage: 'metadata',
						altKeys: ['Title_EN']
					},
					{
						key: 'acronym',
						label: 'Acronym',
						type: 'text',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{
						key: 'leg_gov_uk_url',
						label: 'legislation.gov.uk URL',
						type: 'url',
						stage: 'derived'
					},
					{ key: 'type_desc', label: 'Type Description', type: 'text', stage: 'derived' },
					{ key: 'type_class', label: 'Type Class', type: 'text', stage: 'derived' },
					{
						key: 'domain',
						label: 'Domain',
						type: 'array',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{
						key: 'number_int',
						label: 'Number (Sortable)',
						type: 'number',
						stage: 'derived',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'description',
				title: 'Description',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md Description table
					{ key: 'family', label: 'Family', type: 'text', stage: 'derived', editable: true },
					{
						key: 'family_ii',
						label: 'Sub-Family',
						type: 'text',
						stage: 'derived',
						editable: true
					},
					{
						key: 'si_code',
						label: 'SI Codes',
						type: 'json',
						stage: 'metadata',
						altKeys: ['SICode']
					},
					{ key: 'tags', label: 'Tags', type: 'array', stage: 'derived' },
					{
						key: 'md_description',
						label: 'Description',
						type: 'multiline',
						stage: 'metadata',
						hideWhenEmpty: true
					},
					{
						key: 'md_subjects',
						label: 'Subjects',
						type: 'json',
						stage: 'metadata',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'dates',
				title: 'Dates',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md Dates table
					{ key: 'md_date', label: 'Primary Date', type: 'date', stage: 'metadata' },
					{ key: 'md_made_date', label: 'Made Date', type: 'date', stage: 'metadata' },
					{
						key: 'md_enactment_date',
						label: 'Enacted Date',
						type: 'date',
						stage: 'metadata',
						hideWhenEmpty: true
					},
					{
						key: 'md_coming_into_force_date',
						label: 'In Force Date',
						type: 'date',
						stage: 'metadata'
					},
					{
						key: 'md_dct_valid_date',
						label: 'DCT Valid Date',
						type: 'date',
						stage: 'metadata',
						hideWhenEmpty: true
					},
					{
						key: 'md_modified',
						label: 'Modified Date',
						type: 'date',
						stage: 'metadata',
						hideWhenEmpty: true
					},
					{
						key: 'md_restrict_start_date',
						label: 'Restriction Start',
						type: 'date',
						stage: 'metadata',
						hideWhenEmpty: true
					},
					{
						key: 'md_restrict_extent',
						label: 'Restriction Extent',
						type: 'text',
						stage: 'metadata',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'document_statistics',
				title: 'Document Statistics',
				defaultExpanded: false,
				fields: [
					// Order matches LRT-SCHEMA.md Document Statistics table
					{ key: 'md_total_paras', label: 'Total Paragraphs', type: 'number', stage: 'metadata' },
					{ key: 'md_body_paras', label: 'Body Paragraphs', type: 'number', stage: 'metadata' },
					{
						key: 'md_schedule_paras',
						label: 'Schedule Paragraphs',
						type: 'number',
						stage: 'metadata'
					},
					{
						key: 'md_attachment_paras',
						label: 'Attachment Paragraphs',
						type: 'number',
						stage: 'metadata'
					},
					{ key: 'md_images', label: 'Images', type: 'number', stage: 'metadata' }
				]
			}
		]
	},
	// ==========================================
	// STAGE 2 📍 geographic extent
	// ==========================================
	{
		id: 'stage2_extent',
		title: 'STAGE 2 📍 geographic extent',
		stage: 'extent',
		defaultExpanded: true,
		fields: [
			// Order matches LRT-SCHEMA.md Geographic Extent table
			{
				key: 'geo_extent',
				label: 'Geographic Extent',
				type: 'text',
				stage: 'extent',
				altKeys: ['extent']
			},
			{
				key: 'geo_region',
				label: 'Region',
				type: 'array',
				stage: 'extent',
				altKeys: ['extent_regions']
			},
			{ key: 'geo_detail', label: 'Detail', type: 'multiline', stage: 'extent' }
		]
	},
	// ==========================================
	// STAGE 3 🚀 enacted_by
	// ==========================================
	{
		id: 'stage3_enacted_by',
		title: 'STAGE 3 🚀 enacted_by',
		stage: 'enacted_by',
		defaultExpanded: true,
		fields: [
			// Order matches LRT-SCHEMA.md Enacting <> Enacted_By table
			{ key: 'enacted_by', label: 'Enacted By', type: 'array', stage: 'enacted_by' },
			{
				key: 'enacted_by_meta',
				label: 'Enacted By (Meta)',
				type: 'json',
				stage: 'enacted_by',
				hideWhenEmpty: true
			},
			{ key: 'is_enacting', label: 'Is Enacting', type: 'boolean', stage: 'derived' },
			{ key: 'enacting', label: 'Enacts', type: 'array', stage: 'derived', hideWhenEmpty: true },
			{
				key: 'linked_enacted_by',
				label: 'Linked Enacted By',
				type: 'array',
				stage: 'derived',
				hideWhenEmpty: true
			}
		]
	},
	// ==========================================
	// STAGE 4 🔄 amendments
	// ==========================================
	{
		id: 'stage4_amendments',
		title: 'STAGE 4 🔄 amendments',
		stage: 'amendments',
		defaultExpanded: true,
		subsections: [
			{
				id: 'function',
				title: 'Function',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Function table
					{
						key: 'function',
						label: 'Function',
						type: 'json',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{ key: 'is_making', label: 'Is Making', type: 'boolean', stage: 'derived' },
					{ key: 'is_commencing', label: 'Is Commencing', type: 'boolean', stage: 'derived' }
				]
			},
			{
				id: 'self_affects',
				title: 'Self-Affects',
				defaultExpanded: false,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Self-Affects table
					{
						key: 'stats_self_affects_count',
						label: 'Self Amendments',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'stats_self_affects_count_per_law_detailed',
						label: 'Self Affects (Detail)',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'amending',
				title: 'Amending',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Amending table
					{ key: 'is_amending', label: 'Is Amending', type: 'boolean', stage: 'derived' },
					{
						key: 'amending_stats_affects_count',
						label: 'Affects Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affected_laws_count',
						label: 'Affected Laws Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affects_count_per_law',
						label: 'Affects Per Law',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affects_count_per_law_detailed',
						label: 'Affects Per Law (Detail)',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amending',
						label: 'Amends',
						type: 'array',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'linked_amending',
						label: 'Linked Amends',
						type: 'array',
						stage: 'derived',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'rescinding',
				title: 'Rescinding',
				defaultExpanded: false,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Rescinding table
					{ key: 'is_rescinding', label: 'Is Rescinding', type: 'boolean', stage: 'derived' },
					{
						key: 'rescinding_stats_rescinding_laws_count',
						label: 'Rescinded Laws Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding_stats_rescinding_count_per_law',
						label: 'Rescinding Per Law',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding_stats_rescinding_count_per_law_detailed',
						label: 'Rescinding Per Law (Detail)',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding',
						label: 'Rescinds',
						type: 'array',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'linked_rescinding',
						label: 'Linked Rescinds',
						type: 'array',
						stage: 'derived',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'amended_by',
				title: 'Amended By',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Amended By table
					{
						key: 'amended_by_stats_affected_by_count',
						label: 'Affected By Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_laws_count',
						label: 'Amending Laws Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_count_per_law',
						label: 'Affected By Per Law',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_count_per_law_detailed',
						label: 'Affected By Per Law (Detail)',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by',
						label: 'Amended By',
						type: 'array',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'linked_amended_by',
						label: 'Linked Amended By',
						type: 'array',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{
						key: 'latest_amend_date',
						label: 'Latest Amendment',
						type: 'date',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{
						key: 'latest_change_date',
						label: 'Latest Change',
						type: 'date',
						stage: 'derived',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'rescinded_by',
				title: 'Rescinded By',
				defaultExpanded: false,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 4 Rescinded By table
					{
						key: 'rescinded_by_stats_rescinded_by_laws_count',
						label: 'Rescinding Laws Count',
						type: 'number',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by_stats_rescinded_by_count_per_law',
						label: 'Rescinded By Per Law',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by_stats_rescinded_by_count_per_law_detailed',
						label: 'Rescinded By Per Law (Detail)',
						type: 'multiline',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by',
						label: 'Rescinded By',
						type: 'array',
						stage: 'amendments',
						hideWhenEmpty: true
					},
					{
						key: 'linked_rescinded_by',
						label: 'Linked Rescinded By',
						type: 'array',
						stage: 'derived',
						hideWhenEmpty: true
					},
					{
						key: 'latest_rescind_date',
						label: 'Latest Rescind',
						type: 'date',
						stage: 'derived',
						hideWhenEmpty: true
					}
				]
			}
		]
	},
	// ==========================================
	// STAGE 5 🚫 repeal_revoke
	// ==========================================
	{
		id: 'stage5_repeal_revoke',
		title: 'STAGE 5 🚫 repeal_revoke',
		stage: 'repeal_revoke',
		defaultExpanded: true,
		fields: [
			// Order matches LRT-SCHEMA.md STAGE 5 Status table
			{ key: 'live', label: 'Status', type: 'text', stage: 'repeal_revoke' },
			{
				key: 'live_description',
				label: 'Status Description',
				type: 'text',
				stage: 'repeal_revoke',
				hideWhenEmpty: true
			}
		]
	},
	{
		id: 'taxa',
		title: 'Taxa',
		stage: 'taxa',
		defaultExpanded: false,
		subsections: [
			{
				id: 'purpose',
				title: 'Purpose',
				defaultExpanded: false,
				fields: [
					{ key: 'purpose', label: 'Purpose', type: 'json', stage: 'taxa', hideWhenEmpty: true }
				]
			},
			{
				id: 'roles',
				title: 'Roles (DRRP Model)',
				defaultExpanded: true,
				fields: [
					{ key: 'role', label: 'Role', type: 'array', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'article_role',
						label: 'Article Role',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'role_article',
						label: 'Role Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{ key: 'role_gvt', label: 'Role Gvt', type: 'json', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'role_gvt_article',
						label: 'Role Gvt Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_role_gvt',
						label: 'Article Role Gvt',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'duty_type',
				title: 'Duty Type',
				defaultExpanded: true,
				fields: [
					{
						key: 'duty_type',
						label: 'Duty Type',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'duty_type_article',
						label: 'Duty Type Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_duty_type',
						label: 'Article Duty Type',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'duty_holder',
				title: 'Duty Holder',
				defaultExpanded: false,
				fields: [
					{
						key: 'duty_holder',
						label: 'Duty Holder',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'duty_holder_article',
						label: 'Duty Holder Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'duty_holder_article_clause',
						label: 'Duty Holder Article Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_duty_holder',
						label: 'Article Duty Holder',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_duty_holder_clause',
						label: 'Article Duty Holder Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'rights_holder',
				title: 'Rights Holder',
				defaultExpanded: false,
				fields: [
					{
						key: 'rights_holder',
						label: 'Rights Holder',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'rights_holder_article',
						label: 'Rights Holder Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'rights_holder_article_clause',
						label: 'Rights Holder Article Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_rights_holder',
						label: 'Article Rights Holder',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_rights_holder_clause',
						label: 'Article Rights Holder Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'responsibility_holder',
				title: 'Responsibility Holder',
				defaultExpanded: false,
				fields: [
					{
						key: 'responsibility_holder',
						label: 'Responsibility Holder',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'responsibility_holder_article',
						label: 'Responsibility Holder Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'responsibility_holder_article_clause',
						label: 'Responsibility Holder Article Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_responsibility_holder',
						label: 'Article Responsibility Holder',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_responsibility_holder_clause',
						label: 'Article Responsibility Holder Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'power_holder',
				title: 'Power Holder',
				defaultExpanded: false,
				fields: [
					{
						key: 'power_holder',
						label: 'Power Holder',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'power_holder_article',
						label: 'Power Holder Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'power_holder_article_clause',
						label: 'Power Holder Article Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_power_holder',
						label: 'Article Power Holder',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_power_holder_clause',
						label: 'Article Power Holder Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'popimar',
				title: 'POPIMAR',
				defaultExpanded: false,
				fields: [
					{ key: 'popimar', label: 'POPIMAR', type: 'json', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'popimar_article',
						label: 'POPIMAR Article',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'popimar_article_clause',
						label: 'POPIMAR Article Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_popimar',
						label: 'Article POPIMAR',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'article_popimar_clause',
						label: 'Article POPIMAR Clause',
						type: 'multiline',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			}
		]
	},
	{
		id: 'change_logs',
		title: 'Change Logs',
		defaultExpanded: false,
		fields: [
			{
				key: 'amending_change_log',
				label: 'Amending Change Log',
				type: 'multiline',
				stage: 'system',
				hideWhenEmpty: true
			},
			{
				key: 'amended_by_change_log',
				label: 'Amended By Change Log',
				type: 'multiline',
				stage: 'system',
				hideWhenEmpty: true
			},
			{
				key: 'record_change_log',
				label: 'Record Change Log',
				type: 'json',
				stage: 'system',
				hideWhenEmpty: true
			}
		]
	},
	{
		id: 'timestamps',
		title: 'Timestamps',
		defaultExpanded: false,
		fields: [
			{ key: 'created_at', label: 'Created At', type: 'date', stage: 'system', hideInCreate: true },
			{ key: 'updated_at', label: 'Updated At', type: 'date', stage: 'system', hideInCreate: true }
		]
	}
];
