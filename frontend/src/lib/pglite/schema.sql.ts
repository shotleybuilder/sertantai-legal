/**
 * PGLite Schema for laws table (multi-jurisdiction legal register).
 *
 * Mirrors the server-side legal_register table for columns synced via Electric.
 * Multiple country partitions sync into this single local table.
 * Column types match the server schema where possible.
 *
 * Only includes columns from ADMIN_COLUMNS (excludes heavy JSONB
 * like role_details, duties, rights, responsibilities, powers, popimar_details).
 */

export const CREATE_LAWS_SQL = `
CREATE TABLE IF NOT EXISTS laws (
  id UUID PRIMARY KEY,
  country TEXT NOT NULL DEFAULT 'uk',

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
  live_from_changes TEXT,

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
  making_review TEXT,
  making_review_at TIMESTAMPTZ,

  -- Amendment links
  amending TEXT[],
  amended_by TEXT[],
  is_amending BOOLEAN,
  rescinding TEXT[],
  rescinded_by TEXT[],
  is_rescinding BOOLEAN,
  enacted_by TEXT[],
  is_enacting BOOLEAN,
  enacted_by_meta JSONB[],

  -- LAT
  lat_count INTEGER NOT NULL DEFAULT 0,
  latest_lat_updated_at TIMESTAMPTZ,

  -- Fitness v0.3 (reconciled entities from fractalaw)
  fitness_entities TEXT[],
  fitness_scope_dimensions TEXT[],
  fitness_mention_count INTEGER,
  fitness_applies_count INTEGER,
  fitness_disapplies_count INTEGER,

  has_fitness TEXT NOT NULL DEFAULT 'false',

  -- Source URL (replaces generated leg_gov_uk_url)
  source_url TEXT,

  -- Timestamps
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
`;

export const CREATE_ORG_APPLICABILITIES_SQL = `
CREATE TABLE IF NOT EXISTS org_applicabilities (
  id UUID PRIMARY KEY,
  organization_id UUID NOT NULL,
  law_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'unreviewed',
  source TEXT NOT NULL DEFAULT 'manual',
  notes TEXT,
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_oa_org_law ON org_applicabilities (organization_id, law_name);
CREATE INDEX IF NOT EXISTS idx_oa_status ON org_applicabilities (status);
CREATE INDEX IF NOT EXISTS idx_oa_law_name ON org_applicabilities (law_name);
`;

export const CREATE_DEFINITIONS_SQL = `
CREATE TABLE IF NOT EXISTS definitions (
  id UUID PRIMARY KEY,
  law_name TEXT NOT NULL,
  term TEXT NOT NULL,
  term_welsh TEXT,
  definition TEXT NOT NULL,
  section_id TEXT,
  scope TEXT,
  references_other_law BOOLEAN NOT NULL DEFAULT false,
  citation BOOLEAN NOT NULL DEFAULT false,
  referenced_law_citation TEXT,
  source TEXT NOT NULL DEFAULT 'csv_import',
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);
`;

export const CREATE_DEFINITION_LINKS_SQL = `
CREATE TABLE IF NOT EXISTS definition_links (
  child_definition_id UUID NOT NULL,
  root_definition_id UUID NOT NULL,
  inserted_at TIMESTAMP NOT NULL DEFAULT NOW(),
  PRIMARY KEY (child_definition_id, root_definition_id)
);
`;

export const CREATE_DEFINITIONS_INDEXES_SQL = `
CREATE INDEX IF NOT EXISTS idx_defs_law_name ON definitions (law_name);
CREATE INDEX IF NOT EXISTS idx_defs_term ON definitions (term);
CREATE INDEX IF NOT EXISTS idx_defs_refs_other ON definitions (references_other_law);
CREATE INDEX IF NOT EXISTS idx_defs_citation ON definitions (citation);
CREATE INDEX IF NOT EXISTS idx_defs_law_term ON definitions (law_name, term);
CREATE INDEX IF NOT EXISTS idx_dl_root ON definition_links (root_definition_id);
`;

export const CREATE_LAWS_INDEXES_SQL = `
CREATE INDEX IF NOT EXISTS idx_laws_country ON laws (country);
CREATE INDEX IF NOT EXISTS idx_laws_name ON laws (name);
CREATE INDEX IF NOT EXISTS idx_laws_year ON laws (year);
CREATE INDEX IF NOT EXISTS idx_laws_family ON laws (family);
CREATE INDEX IF NOT EXISTS idx_laws_live ON laws (live);
CREATE INDEX IF NOT EXISTS idx_laws_is_making ON laws (is_making);
CREATE INDEX IF NOT EXISTS idx_laws_making_classification ON laws (making_classification);
`;

/**
 * Initialize the laws schema in PGLite.
 * Drops and recreates if schema version has changed (e.g. column type fixes).
 * Otherwise safe to call multiple times — uses IF NOT EXISTS.
 */
const SCHEMA_VERSION = 18; // Add definitions + definition_links for definitions admin UI

export async function initSchema(pg: {
	exec: (sql: string) => Promise<unknown>;
	query: <T>(sql: string, params?: unknown[]) => Promise<{ rows: T[] }>;
}): Promise<void> {
	// Check stored schema version
	await pg.exec(`CREATE TABLE IF NOT EXISTS _pglite_meta (key TEXT PRIMARY KEY, value TEXT)`);
	const result = await pg.query<{ value: string }>(
		`SELECT value FROM _pglite_meta WHERE key = 'laws_schema_version'`
	);
	const currentVersion = result.rows[0] ? parseInt(result.rows[0].value, 10) : 0;

	if (currentVersion < SCHEMA_VERSION) {
		// Schema changed — drop old tables and recreate
		console.log(
			`[PGLite] Schema version ${currentVersion} → ${SCHEMA_VERSION}, recreating laws table`
		);
		await pg.exec('DROP TABLE IF EXISTS uk_lrt CASCADE');
		await pg.exec('DROP TABLE IF EXISTS laws CASCADE');
		await pg.exec('DROP TABLE IF EXISTS org_applicabilities CASCADE');
		await pg.exec('DROP TABLE IF EXISTS definition_links CASCADE');
		await pg.exec('DROP TABLE IF EXISTS definitions CASCADE');
		// Drop all gridlite tables so both kit and views packages recreate cleanly
		await pg.exec('DROP TABLE IF EXISTS _gridlite_column_state CASCADE');
		await pg.exec('DROP TABLE IF EXISTS _gridlite_views CASCADE');
		await pg.exec('DROP TABLE IF EXISTS _gridlite_meta CASCADE');
		await pg.exec(CREATE_LAWS_SQL);
		await pg.exec(CREATE_LAWS_INDEXES_SQL);
		await pg.exec(CREATE_ORG_APPLICABILITIES_SQL);
		await pg.exec(CREATE_DEFINITIONS_SQL);
		await pg.exec(CREATE_DEFINITION_LINKS_SQL);
		await pg.exec(CREATE_DEFINITIONS_INDEXES_SQL);
		await pg.exec(
			`INSERT INTO _pglite_meta (key, value) VALUES ('laws_schema_version', '${SCHEMA_VERSION}') ON CONFLICT (key) DO UPDATE SET value = '${SCHEMA_VERSION}'`
		);
	} else {
		await pg.exec(CREATE_LAWS_SQL);
		await pg.exec(CREATE_LAWS_INDEXES_SQL);
		await pg.exec(CREATE_ORG_APPLICABILITIES_SQL);
		await pg.exec(CREATE_DEFINITIONS_SQL);
		await pg.exec(CREATE_DEFINITION_LINKS_SQL);
		await pg.exec(CREATE_DEFINITIONS_INDEXES_SQL);
	}

	// Fix incompatible _gridlite_column_state from svelte-gridlite-views (lacks grid_id).
	// Drop all gridlite tables so both kit and views recreate with correct schemas.
	try {
		const cs = await pg.query<{ column_name: string }>(
			`SELECT column_name FROM information_schema.columns WHERE table_name = '_gridlite_column_state' AND column_name = 'grid_id'`
		);
		// Table exists but missing grid_id → incompatible schema
		const tableExists = await pg.query<{ c: string }>(
			`SELECT '1' as c FROM information_schema.tables WHERE table_name = '_gridlite_column_state' LIMIT 1`
		);
		if (tableExists.rows.length > 0 && cs.rows.length === 0) {
			console.log('[PGLite] Dropping incompatible _gridlite_column_state (missing grid_id)');
			await pg.exec('DROP TABLE IF EXISTS _gridlite_column_state CASCADE');
			await pg.exec('DROP TABLE IF EXISTS _gridlite_views CASCADE');
			await pg.exec('DROP TABLE IF EXISTS _gridlite_meta CASCADE');
		}
	} catch {
		/* table doesn't exist yet — fine */
	}

	console.log('[PGLite] laws schema initialized');
}
