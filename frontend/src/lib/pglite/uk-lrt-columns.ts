/**
 * uk-lrt-columns.ts — Column metadata for legal register records.
 *
 * Used by gridlite-adapter-tanstack-db which cannot auto-introspect
 * column types (unlike the PGLite adapter which reads information_schema).
 *
 * Matches the PGLite schema in schema.sql.ts for synced admin columns.
 */

import type { ColumnMetadata } from '@shotleybuilder/svelte-gridlite-kit/types';

export const UK_LRT_COLUMN_METADATA: ColumnMetadata[] = [
	// Identity
	{ name: 'id', dataType: 'text', postgresType: 'uuid', nullable: false, hasDefault: true },
	{
		name: 'country',
		dataType: 'text',
		postgresType: 'text',
		nullable: false,
		hasDefault: true
	},
	{ name: 'name', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
	{ name: 'title_en', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{ name: 'acronym', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{
		name: 'old_style_number',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{ name: 'year', dataType: 'number', postgresType: 'integer', nullable: true, hasDefault: false },
	{ name: 'number', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
	{ name: 'type_code', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{ name: 'type_class', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{
		name: 'type_desc',
		dataType: 'text',
		postgresType: 'varchar',
		nullable: true,
		hasDefault: false
	},
	{ name: 'domain', dataType: 'json', postgresType: 'text[]', nullable: true, hasDefault: false },

	// Description
	{ name: 'family', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
	{
		name: 'family_ii',
		dataType: 'text',
		postgresType: 'varchar',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_description',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{ name: 'function', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },
	{ name: 'si_code', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },
	{ name: 'tags', dataType: 'json', postgresType: 'varchar[]', nullable: true, hasDefault: false },

	// Status
	{ name: 'live', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
	{
		name: 'live_description',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'live_from_changes',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},

	// Geographic
	{ name: 'geo_extent', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{
		name: 'geo_region',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{ name: 'geo_detail', dataType: 'text', postgresType: 'text', nullable: true, hasDefault: false },
	{
		name: 'md_restrict_extent',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},

	// Dates
	{ name: 'md_date', dataType: 'date', postgresType: 'date', nullable: true, hasDefault: false },
	{
		name: 'md_date_year',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_date_month',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_made_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_enactment_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_coming_into_force_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_dct_valid_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_restrict_start_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_modified',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_amend_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_amend_date_year',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_amend_date_month',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_rescind_date',
		dataType: 'date',
		postgresType: 'date',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_rescind_date_year',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'latest_rescind_date_month',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},

	// Document stats
	{
		name: 'md_total_paras',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_body_paras',
		dataType: 'number',
		postgresType: 'smallint',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_schedule_paras',
		dataType: 'number',
		postgresType: 'smallint',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_attachment_paras',
		dataType: 'number',
		postgresType: 'smallint',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_images',
		dataType: 'number',
		postgresType: 'smallint',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'md_subjects',
		dataType: 'json',
		postgresType: 'jsonb',
		nullable: true,
		hasDefault: false
	},

	// Role/Actor
	{ name: 'role', dataType: 'json', postgresType: 'varchar[]', nullable: true, hasDefault: false },
	{ name: 'role_gvt', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },

	// Duty Type
	{ name: 'duty_type', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },
	{
		name: 'duty_type_article',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'article_duty_type',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},

	// Holders
	{
		name: 'duty_holder',
		dataType: 'json',
		postgresType: 'jsonb',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'power_holder',
		dataType: 'json',
		postgresType: 'jsonb',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'rights_holder',
		dataType: 'json',
		postgresType: 'jsonb',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'responsibility_holder',
		dataType: 'json',
		postgresType: 'jsonb',
		nullable: true,
		hasDefault: false
	},

	// Purpose & POPIMAR
	{ name: 'purpose', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },
	{ name: 'popimar', dataType: 'json', postgresType: 'jsonb', nullable: true, hasDefault: false },

	// Making/Function booleans
	{
		name: 'is_making',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'is_commencing',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'making_classification',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'making_review',
		dataType: 'text',
		postgresType: 'text',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'making_review_at',
		dataType: 'date',
		postgresType: 'timestamptz',
		nullable: true,
		hasDefault: false
	},

	// Amendment links
	{ name: 'amending', dataType: 'json', postgresType: 'text[]', nullable: true, hasDefault: false },
	{
		name: 'amended_by',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'is_amending',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'rescinding',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'rescinded_by',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'is_rescinding',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'enacted_by',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'is_enacting',
		dataType: 'boolean',
		postgresType: 'boolean',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'enacted_by_meta',
		dataType: 'json',
		postgresType: 'jsonb[]',
		nullable: true,
		hasDefault: false
	},

	// LAT
	{
		name: 'lat_count',
		dataType: 'number',
		postgresType: 'integer',
		nullable: false,
		hasDefault: true
	},
	{
		name: 'latest_lat_updated_at',
		dataType: 'date',
		postgresType: 'timestamptz',
		nullable: true,
		hasDefault: false
	},

	// Fitness v0.3
	{
		name: 'fitness_entities',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_scope_dimensions',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_mention_count',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_applies_count',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_disapplies_count',
		dataType: 'number',
		postgresType: 'integer',
		nullable: true,
		hasDefault: false
	},

	// Fitness legacy
	{
		name: 'fitness_person',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_process',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_place',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_plant',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_property',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'fitness_sector',
		dataType: 'json',
		postgresType: 'text[]',
		nullable: true,
		hasDefault: false
	},
	{
		name: 'has_fitness',
		dataType: 'text',
		postgresType: 'text',
		nullable: false,
		hasDefault: true
	},

	// Timestamps
	{
		name: 'created_at',
		dataType: 'date',
		postgresType: 'timestamp',
		nullable: false,
		hasDefault: true
	},
	{
		name: 'updated_at',
		dataType: 'date',
		postgresType: 'timestamp',
		nullable: false,
		hasDefault: true
	}
];
