/**
 * PGLite Schema for uk_lrt
 *
 * Mirrors the server-side uk_lrt table for columns synced via Electric.
 * Column types match the server schema where possible. Electric sends all
 * values as strings, but PGLite's Postgres engine handles type coercion.
 *
 * Only includes columns from UK_LRT_ADMIN_COLUMNS (excludes heavy JSONB
 * like role_details, duties, rights, responsibilities, powers, popimar_details).
 */

export const CREATE_UK_LRT_SQL = `
CREATE TABLE IF NOT EXISTS uk_lrt (
  id UUID PRIMARY KEY,

  -- Credentials
  name VARCHAR,
  title_en TEXT,
  acronym TEXT,
  old_style_number TEXT,
  year INTEGER,
  number VARCHAR,
  type_code TEXT,
  type_class TEXT,
  type_desc VARCHAR,
  domain TEXT[],

  -- Description
  family VARCHAR,
  family_ii VARCHAR,
  md_description TEXT,
  function JSONB,
  si_code JSONB,
  tags VARCHAR[],

  -- Status
  live VARCHAR,
  live_description TEXT,
  live_source TEXT,
  live_conflict BOOLEAN,
  live_from_changes TEXT,
  live_from_metadata TEXT,
  live_conflict_detail JSONB,

  -- Geographic
  geo_extent TEXT,
  geo_region TEXT[],
  geo_detail TEXT,
  md_restrict_extent TEXT,

  -- Dates
  md_date DATE,
  md_date_year INTEGER,
  md_date_month INTEGER,
  md_made_date DATE,
  md_enactment_date DATE,
  md_coming_into_force_date DATE,
  md_dct_valid_date DATE,
  md_restrict_start_date DATE,
  md_modified DATE,
  latest_amend_date DATE,
  latest_amend_date_year INTEGER,
  latest_amend_date_month INTEGER,
  latest_rescind_date DATE,
  latest_rescind_date_year INTEGER,
  latest_rescind_date_month INTEGER,

  -- Document stats
  md_total_paras INTEGER,
  md_body_paras SMALLINT,
  md_schedule_paras SMALLINT,
  md_attachment_paras SMALLINT,
  md_images SMALLINT,
  md_subjects JSONB,

  -- Role/Actor
  role VARCHAR[],
  role_gvt JSONB,

  -- Duty Type
  duty_type JSONB,
  duty_type_article TEXT,
  article_duty_type TEXT,

  -- Holders (legacy flat JSONB)
  duty_holder JSONB,
  power_holder JSONB,
  rights_holder JSONB,
  responsibility_holder JSONB,

  -- Purpose & POPIMAR
  purpose JSONB,
  popimar JSONB,

  -- Making/Function booleans
  is_making BOOLEAN,
  is_commencing BOOLEAN,
  making_classification TEXT,

  -- Amendment links
  amending TEXT[],
  amended_by TEXT[],
  linked_amending TEXT[],
  linked_amended_by TEXT[],
  is_amending BOOLEAN,
  rescinding TEXT[],
  rescinded_by TEXT[],
  linked_rescinding TEXT[],
  linked_rescinded_by TEXT[],
  is_rescinding BOOLEAN,
  enacted_by TEXT[],
  linked_enacted_by TEXT[],
  is_enacting BOOLEAN,
  enacted_by_meta JSONB[],

  -- LAT
  lat_count INTEGER NOT NULL DEFAULT 0,
  latest_lat_updated_at TIMESTAMPTZ,

  -- Fitness
  fitness_person TEXT[],
  fitness_process TEXT[],
  fitness_place TEXT[],
  fitness_plant TEXT[],
  fitness_property TEXT[],
  fitness_sector TEXT[],
  fitness JSONB[],

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
`;

export const CREATE_UK_LRT_INDEXES_SQL = `
CREATE INDEX IF NOT EXISTS idx_uk_lrt_name ON uk_lrt (name);
CREATE INDEX IF NOT EXISTS idx_uk_lrt_year ON uk_lrt (year);
CREATE INDEX IF NOT EXISTS idx_uk_lrt_family ON uk_lrt (family);
CREATE INDEX IF NOT EXISTS idx_uk_lrt_live ON uk_lrt (live);
CREATE INDEX IF NOT EXISTS idx_uk_lrt_is_making ON uk_lrt (is_making);
CREATE INDEX IF NOT EXISTS idx_uk_lrt_making_classification ON uk_lrt (making_classification);
`;

/**
 * Initialize the uk_lrt schema in PGLite.
 * Drops and recreates if schema version has changed (e.g. column type fixes).
 * Otherwise safe to call multiple times — uses IF NOT EXISTS.
 */
const SCHEMA_VERSION = 5; // Bump when schema changes require a fresh table

export async function initSchema(pg: {
	exec: (sql: string) => Promise<unknown>;
	query: <T>(sql: string, params?: unknown[]) => Promise<{ rows: T[] }>;
}): Promise<void> {
	// Check stored schema version
	await pg.exec(`CREATE TABLE IF NOT EXISTS _pglite_meta (key TEXT PRIMARY KEY, value TEXT)`);
	const result = await pg.query<{ value: string }>(
		`SELECT value FROM _pglite_meta WHERE key = 'uk_lrt_schema_version'`
	);
	const currentVersion = result.rows[0] ? parseInt(result.rows[0].value, 10) : 0;

	if (currentVersion < SCHEMA_VERSION) {
		// Schema changed — drop and recreate
		console.log(
			`[PGLite] Schema version ${currentVersion} → ${SCHEMA_VERSION}, recreating uk_lrt table`
		);
		await pg.exec('DROP TABLE IF EXISTS uk_lrt CASCADE');
		// Drop all gridlite tables so both kit and views packages recreate cleanly
		await pg.exec('DROP TABLE IF EXISTS _gridlite_column_state CASCADE');
		await pg.exec('DROP TABLE IF EXISTS _gridlite_views CASCADE');
		await pg.exec('DROP TABLE IF EXISTS _gridlite_meta CASCADE');
		await pg.exec(CREATE_UK_LRT_SQL);
		await pg.exec(CREATE_UK_LRT_INDEXES_SQL);
		await pg.exec(
			`INSERT INTO _pglite_meta (key, value) VALUES ('uk_lrt_schema_version', '${SCHEMA_VERSION}') ON CONFLICT (key) DO UPDATE SET value = '${SCHEMA_VERSION}'`
		);
	} else {
		await pg.exec(CREATE_UK_LRT_SQL);
		await pg.exec(CREATE_UK_LRT_INDEXES_SQL);
	}

	console.log('[PGLite] uk_lrt schema initialized');
}
