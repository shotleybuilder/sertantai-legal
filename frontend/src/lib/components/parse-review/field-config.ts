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
	live_source: 'Status Source',
	live_conflict: 'Status Conflict',
	live_from_changes: 'Status (Changes)',
	live_from_metadata: 'Status (Metadata)',
	live_conflict_detail: 'Conflict Detail',

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
	amending_stats_affects_count_per_law: 'Affects Per Law (Legacy)',
	amending_stats_affects_count_per_law_detailed: 'Affects Per Law Detail (Legacy)',
	affects_stats_per_law: '🔺 Affects Stats Per Law',
	amending: 'Amends',

	// Function - Rescinding (this law rescinds others)
	rescinding_stats_rescinding_laws_count: 'Rescinded Laws Count',
	rescinding_stats_rescinding_count_per_law: 'Rescinding Per Law (Legacy)',
	rescinding_stats_rescinding_count_per_law_detailed: 'Rescinding Per Law Detail (Legacy)',
	rescinding_stats_per_law: '🔺 Rescinding Stats Per Law',
	rescinding: 'Rescinds',

	// Function - Amended By (this law is affected by others)
	amended_by_stats_affected_by_count: 'Affected By Count',
	amended_by_stats_affected_by_laws_count: 'Amending Laws Count',
	amended_by_stats_affected_by_count_per_law: 'Affected By Per Law (Legacy)',
	amended_by_stats_affected_by_count_per_law_detailed: 'Affected By Per Law Detail (Legacy)',
	affected_by_stats_per_law: '🔻 Affected By Stats Per Law',
	amended_by: 'Amended By',

	// Function - Rescinded By (this law is rescinded by others)
	rescinded_by_stats_rescinded_by_laws_count: 'Rescinding Laws Count',
	rescinded_by_stats_rescinded_by_count_per_law: 'Rescinded By Per Law (Legacy)',
	rescinded_by_stats_rescinded_by_count_per_law_detailed: 'Rescinded By Per Law Detail (Legacy)',
	rescinded_by_stats_per_law: '🔻 Rescinded By Stats Per Law',
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
	role_gvt: 'Role Gvt',
	// Consolidated JSONB Role fields (Phase 3 Issue #16)
	// Phase 4: Removed deprecated text columns - article_role, role_article, role_gvt_article, article_role_gvt
	role_details: 'Role Details (JSONB)',
	role_gvt_details: 'Role Gvt Details (JSONB)',

	// Taxa - Duty Type
	duty_type: 'Duty Type',
	duty_type_article: 'Duty Type Article',
	article_duty_type: 'Article Duty Type',

	// Taxa - Holder Lists (simple maps)
	duty_holder: 'Duty Holder',
	rights_holder: 'Rights Holder',
	responsibility_holder: 'Responsibility Holder',
	power_holder: 'Power Holder',

	// Taxa - Consolidated JSONB Holder Fields (Phase 3)
	duties: 'Duties',
	rights: 'Rights',
	responsibilities: 'Responsibilities',
	powers: 'Powers',

	// Taxa - POPIMAR
	popimar: 'POPIMAR',
	popimar_details: 'POPIMAR Details (JSONB)',
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
 * - STAGE 4 🔄 amending: Self-Affects, Amending, Rescinding (this law affects others)
 * - STAGE 5 🔄 amended_by: Amended By, Rescinded By (this law affected by others)
 * - STAGE 6 🚫 repeal_revoke: Status
 * - STAGE 7 🦋 taxa: Purpose, Roles, Duty Type, Duty Holder, Rights Holder, etc.
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
	// STAGE 4 🔄 amending (this law affects others)
	// ==========================================
	{
		id: 'stage4_amending',
		title: 'STAGE 4 🔄 amending',
		stage: 'amending',
		defaultExpanded: true,
		subsections: [
			{
				id: 'function',
				title: 'Function',
				defaultExpanded: true,
				fields: [
					// Function flags derived from amending data
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
					// Self-amendments (this law amending itself)
					{
						key: 'stats_self_affects_count',
						label: 'Self Amendments',
						type: 'number',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'stats_self_affects_count_per_law_detailed',
						label: 'Self Affects (Detail)',
						type: 'multiline',
						stage: 'amending',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'amending',
				title: 'Amending',
				defaultExpanded: true,
				fields: [
					// Laws THIS law amends
					{ key: 'is_amending', label: 'Is Amending', type: 'boolean', stage: 'derived' },
					{
						key: 'amending_stats_affects_count',
						label: 'Affects Count',
						type: 'number',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affected_laws_count',
						label: 'Affected Laws Count',
						type: 'number',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'affects_stats_per_law',
						label: '🔺 Affects Stats Per Law',
						type: 'json',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affects_count_per_law',
						label: 'Affects Per Law (Legacy)',
						type: 'multiline',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'amending_stats_affects_count_per_law_detailed',
						label: 'Affects Per Law Detail (Legacy)',
						type: 'multiline',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'amending',
						label: 'Amends',
						type: 'array',
						stage: 'amending',
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
					// Laws THIS law rescinds
					{ key: 'is_rescinding', label: 'Is Rescinding', type: 'boolean', stage: 'derived' },
					{
						key: 'rescinding_stats_rescinding_laws_count',
						label: 'Rescinded Laws Count',
						type: 'number',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding_stats_per_law',
						label: '🔺 Rescinding Stats Per Law',
						type: 'json',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding_stats_rescinding_count_per_law',
						label: 'Rescinding Per Law (Legacy)',
						type: 'multiline',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding_stats_rescinding_count_per_law_detailed',
						label: 'Rescinding Per Law Detail (Legacy)',
						type: 'multiline',
						stage: 'amending',
						hideWhenEmpty: true
					},
					{
						key: 'rescinding',
						label: 'Rescinds',
						type: 'array',
						stage: 'amending',
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
			}
		]
	},
	// ==========================================
	// STAGE 5 🔄 amended_by (this law affected by others)
	// ==========================================
	{
		id: 'stage5_amended_by',
		title: 'STAGE 5 🔄 amended_by',
		stage: 'amended_by',
		defaultExpanded: true,
		subsections: [
			{
				id: 'amended_by',
				title: 'Amended By',
				defaultExpanded: true,
				fields: [
					// Laws that amend THIS law
					{
						key: 'amended_by_stats_affected_by_count',
						label: 'Affected By Count',
						type: 'number',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_laws_count',
						label: 'Amending Laws Count',
						type: 'number',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'affected_by_stats_per_law',
						label: '🔻 Affected By Stats Per Law',
						type: 'json',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_count_per_law',
						label: 'Affected By Per Law (Legacy)',
						type: 'multiline',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by_stats_affected_by_count_per_law_detailed',
						label: 'Affected By Per Law Detail (Legacy)',
						type: 'multiline',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'amended_by',
						label: 'Amended By',
						type: 'array',
						stage: 'amended_by',
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
					// Laws that rescind THIS law
					{
						key: 'rescinded_by_stats_rescinded_by_laws_count',
						label: 'Rescinding Laws Count',
						type: 'number',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by_stats_per_law',
						label: '🔻 Rescinded By Stats Per Law',
						type: 'json',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by_stats_rescinded_by_count_per_law',
						label: 'Rescinded By Per Law (Legacy)',
						type: 'multiline',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by_stats_rescinded_by_count_per_law_detailed',
						label: 'Rescinded By Per Law Detail (Legacy)',
						type: 'multiline',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'rescinded_by',
						label: 'Rescinded By',
						type: 'array',
						stage: 'amended_by',
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
	// STAGE 6 🚫 repeal_revoke
	// ==========================================
	{
		id: 'stage6_repeal_revoke',
		title: 'STAGE 6 🚫 repeal_revoke',
		stage: 'repeal_revoke',
		defaultExpanded: true,
		subsections: [
			{
				id: 'status',
				title: 'Status',
				defaultExpanded: true,
				fields: [
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
				id: 'reconciliation',
				title: 'Reconciliation',
				defaultExpanded: false,
				fields: [
					{
						key: 'live_source',
						label: 'Status Source',
						type: 'text',
						stage: 'repeal_revoke',
						hideWhenEmpty: true
					},
					{
						key: 'live_conflict',
						label: 'Status Conflict',
						type: 'boolean',
						stage: 'repeal_revoke',
						hideWhenEmpty: true
					},
					{
						key: 'live_from_changes',
						label: 'Status (Changes)',
						type: 'text',
						stage: 'amended_by',
						hideWhenEmpty: true
					},
					{
						key: 'live_from_metadata',
						label: 'Status (Metadata)',
						type: 'text',
						stage: 'repeal_revoke',
						hideWhenEmpty: true
					},
					{
						key: 'live_conflict_detail',
						label: 'Conflict Detail',
						type: 'json',
						stage: 'repeal_revoke',
						hideWhenEmpty: true
					}
				]
			}
		]
	},
	// ==========================================
	// STAGE 7 🦋 taxa
	// ==========================================
	{
		id: 'stage7_taxa',
		title: 'STAGE 7 🦋 taxa',
		stage: 'taxa',
		defaultExpanded: false,
		subsections: [
			{
				id: 'purpose',
				title: 'Purpose',
				defaultExpanded: false,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 6 Purpose table
					{ key: 'purpose', label: 'Purpose', type: 'json', stage: 'taxa', hideWhenEmpty: true }
				]
			},
			{
				id: 'roles',
				title: 'Roles',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 6 Roles table
					{ key: 'role', label: 'Role', type: 'array', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'role_details',
						label: 'Role Details (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{ key: 'role_gvt', label: 'Role Gvt', type: 'json', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'role_gvt_details',
						label: 'Role Gvt Details (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					}
					// Phase 4 Issue #16: Removed deprecated text columns - article_role, role_article, role_gvt_article, article_role_gvt
				]
			},
			{
				id: 'duty_type',
				title: 'Duty Type',
				defaultExpanded: true,
				fields: [
					// Order matches LRT-SCHEMA.md STAGE 6 Duty Type table
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
				id: 'duties',
				title: 'Duties',
				defaultExpanded: false,
				fields: [
					// Phase 3: Consolidated JSONB holder fields
					{
						key: 'duty_holder',
						label: 'Duty Holders',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'duties',
						label: 'Duties (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'rights',
				title: 'Rights',
				defaultExpanded: false,
				fields: [
					{
						key: 'rights_holder',
						label: 'Rights Holders',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'rights',
						label: 'Rights (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'responsibilities',
				title: 'Responsibilities',
				defaultExpanded: false,
				fields: [
					{
						key: 'responsibility_holder',
						label: 'Responsibility Holders',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'responsibilities',
						label: 'Responsibilities (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					}
				]
			},
			{
				id: 'powers',
				title: 'Powers',
				defaultExpanded: false,
				fields: [
					{
						key: 'power_holder',
						label: 'Power Holders',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
					{
						key: 'powers',
						label: 'Powers (JSONB)',
						type: 'json',
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
					// Order matches LRT-SCHEMA.md STAGE 6 POPIMAR table
					{ key: 'popimar', label: 'POPIMAR', type: 'json', stage: 'taxa', hideWhenEmpty: true },
					{
						key: 'popimar_details',
						label: 'POPIMAR Details (JSONB)',
						type: 'json',
						stage: 'taxa',
						hideWhenEmpty: true
					},
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
