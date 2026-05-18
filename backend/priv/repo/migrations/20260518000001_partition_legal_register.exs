defmodule SertantaiLegal.Repo.Migrations.PartitionLegalRegister do
  @moduledoc """
  Phase 1.1: Migrate uk_lrt → legal_register (partitioned by country).

  Also migrates: lat → legal_articles, amendment_annotations (adds country),
  law_edges (adds country), si_code_families (adds country).

  Creates backwards-compatible views so existing Ash resources, controllers,
  and ElectricSQL shapes continue to work unchanged during transition.

  Strategy:
    1. Create new partitioned tables with country + jurisdiction columns
    2. Create UK partitions
    3. Copy data from old tables
    4. Drop old FK constraints and triggers
    5. Rename old tables → _old
    6. Create updatable views with old names
    7. Recreate trigger functions against new table names
    8. Create triggers on new tables
    9. Set REPLICA IDENTITY FULL for ElectricSQL
  """

  use Ecto.Migration

  def up do
    # =========================================================================
    # STEP 1: Create partitioned legal_register table
    # =========================================================================
    execute """
    CREATE TABLE legal_register (
      id uuid NOT NULL DEFAULT gen_random_uuid(),
      country text NOT NULL,
      jurisdiction text NOT NULL,

      -- Core Identifiers
      family text,
      family_ii text,
      name text,
      title_en text,
      year bigint,
      number text,
      acronym text,
      old_style_number text,

      -- Type Classification
      type_desc text,
      type_code text,
      type_class text,
      domain text[],

      -- Status
      live text,
      live_description text,
      live_from_changes text,

      -- Geographic
      geo_extent text,
      geo_region text[],
      geo_detail text,
      md_restrict_extent text,

      -- DRRP Holders (JSONB)
      duty_holder jsonb,
      power_holder jsonb,
      rights_holder jsonb,
      responsibility_holder jsonb,

      -- Classification (JSONB)
      purpose jsonb,
      function jsonb,
      popimar jsonb,
      popimar_details jsonb,
      si_code jsonb,
      enacted_si_codes jsonb,
      enacted_families jsonb,
      md_subjects jsonb,

      -- Roles
      role text[],
      role_gvt jsonb,
      role_details jsonb,
      role_gvt_details jsonb,
      tags text[],

      -- Metadata description
      md_description text,
      md_total_paras bigint,
      md_body_paras bigint,
      md_schedule_paras bigint,
      md_attachment_paras bigint,
      md_images bigint,

      -- Amendment/Rescind/Enact arrays
      amending text[],
      amended_by text[],
      rescinding text[],
      rescinded_by text[],
      enacting text[],
      enacted_by text[],
      enacted_by_meta jsonb[],

      -- Boolean flags
      is_amending boolean,
      is_rescinding boolean,
      is_enacting boolean,
      is_making boolean,
      is_commencing boolean,

      -- Making detection
      making_confidence double precision,
      making_classification text,
      making_detection_tier bigint,
      making_detection_signals jsonb,
      making_review text,
      making_review_at timestamp without time zone,

      -- Dates
      created_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      md_date date,
      md_date_year integer,
      md_date_month integer,
      md_made_date date,
      md_enactment_date date,
      md_coming_into_force_date date,
      md_dct_valid_date date,
      md_modified date,
      md_restrict_start_date date,
      latest_amend_date date,
      latest_amend_date_year integer,
      latest_amend_date_month integer,
      latest_change_date date,
      latest_rescind_date date,
      latest_rescind_date_year integer,
      latest_rescind_date_month integer,

      -- Stats
      "🔺🔻_stats_self_affects_count" bigint,
      "🔺_stats_affects_count" bigint,
      "🔺_stats_affected_laws_count" bigint,
      "🔻_stats_affected_by_count" bigint,
      "🔻_stats_affected_by_laws_count" bigint,
      "🔺_stats_rescinding_laws_count" bigint,
      "🔻_stats_rescinded_by_laws_count" bigint,
      "🔺🔻_stats_self_affects_count_per_law_detailed" text,
      "🔺_affects_stats_per_law" jsonb,
      "🔺_rescinding_stats_per_law" jsonb,
      "🔻_affected_by_stats_per_law" jsonb,
      "🔻_rescinded_by_stats_per_law" jsonb,
      amending_change_log text,
      amended_by_change_log text,
      record_change_log jsonb[],

      -- Duty type
      duty_type jsonb,
      duty_type_article text,
      article_duty_type text,

      -- Consolidated holders (JSONB)
      duties jsonb,
      rights jsonb,
      responsibilities jsonb,
      powers jsonb,

      -- Fitness
      fitness_person text[],
      fitness_process text[],
      fitness_place text[],
      fitness_plant text[],
      fitness_property text[],
      fitness_sector text[],
      fitness jsonb[],

      -- LAT stats (maintained by trigger)
      lat_count integer NOT NULL DEFAULT 0,
      latest_lat_updated_at timestamp with time zone,

      -- Source URL (replaces leg_gov_uk_url generated column)
      source_url text,

      -- Generated columns (jurisdiction-neutral)
      number_int integer GENERATED ALWAYS AS (
        CASE WHEN number ~ '^[0-9]+$' THEN number::integer ELSE NULL END
      ) STORED,
      has_fitness boolean GENERATED ALWAYS AS (
        fitness_person IS NOT NULL OR fitness_process IS NOT NULL OR
        fitness_place IS NOT NULL OR fitness_plant IS NOT NULL OR
        fitness_property IS NOT NULL OR fitness_sector IS NOT NULL
      ) STORED,

      PRIMARY KEY (id, country)
    ) PARTITION BY LIST (country);
    """

    # Create UK partition
    execute "CREATE TABLE legal_register_uk PARTITION OF legal_register FOR VALUES IN ('uk');"

    # =========================================================================
    # STEP 2: Copy UK data from uk_lrt → legal_register
    # =========================================================================
    execute """
    INSERT INTO legal_register (
      id, country, jurisdiction,
      family, family_ii, name, title_en, year, number, acronym, old_style_number,
      type_desc, type_code, type_class, domain,
      live, live_description, live_from_changes,
      geo_extent, geo_region, geo_detail, md_restrict_extent,
      duty_holder, power_holder, rights_holder, responsibility_holder,
      purpose, function, popimar, popimar_details,
      si_code, enacted_si_codes, enacted_families, md_subjects,
      role, role_gvt, role_details, role_gvt_details, tags,
      md_description, md_total_paras, md_body_paras, md_schedule_paras,
      md_attachment_paras, md_images,
      amending, amended_by, rescinding, rescinded_by, enacting, enacted_by, enacted_by_meta,
      is_amending, is_rescinding, is_enacting, is_making, is_commencing,
      making_confidence, making_classification, making_detection_tier,
      making_detection_signals, making_review, making_review_at,
      created_at, updated_at,
      md_date, md_date_year, md_date_month,
      md_made_date, md_enactment_date, md_coming_into_force_date,
      md_dct_valid_date, md_modified, md_restrict_start_date,
      latest_amend_date, latest_amend_date_year, latest_amend_date_month,
      latest_change_date,
      latest_rescind_date, latest_rescind_date_year, latest_rescind_date_month,
      "🔺🔻_stats_self_affects_count", "🔺_stats_affects_count", "🔺_stats_affected_laws_count",
      "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count",
      "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count",
      "🔺🔻_stats_self_affects_count_per_law_detailed",
      "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law",
      "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law",
      amending_change_log, amended_by_change_log, record_change_log,
      duty_type, duty_type_article, article_duty_type,
      duties, rights, responsibilities, powers,
      fitness_person, fitness_process, fitness_place, fitness_plant,
      fitness_property, fitness_sector, fitness,
      lat_count, latest_lat_updated_at,
      source_url
    )
    SELECT
      id, 'uk', 'uk',
      family, family_ii, name, title_en, year, number, acronym, old_style_number,
      type_desc, type_code, type_class, domain,
      live, live_description, live_from_changes,
      geo_extent, geo_region, geo_detail, md_restrict_extent,
      duty_holder, power_holder, rights_holder, responsibility_holder,
      purpose, function, popimar, popimar_details,
      si_code, enacted_si_codes, enacted_families, md_subjects,
      role, role_gvt, role_details, role_gvt_details, tags,
      md_description, md_total_paras, md_body_paras, md_schedule_paras,
      md_attachment_paras, md_images,
      amending, amended_by, rescinding, rescinded_by, enacting, enacted_by, enacted_by_meta,
      is_amending, is_rescinding, is_enacting, is_making, is_commencing,
      making_confidence, making_classification, making_detection_tier,
      making_detection_signals, making_review, making_review_at,
      created_at, updated_at,
      md_date, md_date_year, md_date_month,
      md_made_date, md_enactment_date, md_coming_into_force_date,
      md_dct_valid_date, md_modified, md_restrict_start_date,
      latest_amend_date, latest_amend_date_year, latest_amend_date_month,
      latest_change_date,
      latest_rescind_date, latest_rescind_date_year, latest_rescind_date_month,
      "🔺🔻_stats_self_affects_count", "🔺_stats_affects_count", "🔺_stats_affected_laws_count",
      "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count",
      "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count",
      "🔺🔻_stats_self_affects_count_per_law_detailed",
      "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law",
      "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law",
      amending_change_log, amended_by_change_log, record_change_log,
      duty_type, duty_type_article, article_duty_type,
      duties, rights, responsibilities, powers,
      fitness_person, fitness_process, fitness_place, fitness_plant,
      fitness_property, fitness_sector, fitness,
      lat_count, latest_lat_updated_at,
      leg_gov_uk_url
    FROM uk_lrt;
    """

    # =========================================================================
    # STEP 3: Create partitioned legal_articles table
    # =========================================================================
    execute """
    CREATE TABLE legal_articles (
      section_id text NOT NULL,
      country text NOT NULL,
      law_name text NOT NULL,
      sort_key text NOT NULL,
      position bigint NOT NULL,
      section_type text NOT NULL,
      hierarchy_path text,
      depth bigint NOT NULL,
      part text,
      chapter text,
      heading_group text,
      provision text,
      paragraph text,
      sub_paragraph text,
      schedule text,
      text text NOT NULL,
      language text NOT NULL DEFAULT 'en',
      extent_code text,
      amendment_count bigint,
      modification_count bigint,
      commencement_count bigint,
      extent_count bigint,
      editorial_count bigint,
      embedding double precision[],
      embedding_model text,
      embedded_at timestamp without time zone,
      token_ids bigint[],
      tokenizer_model text,
      legacy_id text,
      created_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      law_id uuid NOT NULL,

      PRIMARY KEY (section_id, country),
      FOREIGN KEY (law_id, country) REFERENCES legal_register (id, country)
    ) PARTITION BY LIST (country);
    """

    execute "CREATE TABLE legal_articles_uk PARTITION OF legal_articles FOR VALUES IN ('uk');"

    # Copy LAT data
    execute """
    INSERT INTO legal_articles (
      section_id, country, law_name, sort_key, position, section_type,
      hierarchy_path, depth, part, chapter, heading_group,
      provision, paragraph, sub_paragraph, schedule,
      text, language, extent_code,
      amendment_count, modification_count, commencement_count,
      extent_count, editorial_count,
      embedding, embedding_model, embedded_at,
      token_ids, tokenizer_model, legacy_id,
      created_at, updated_at, law_id
    )
    SELECT
      section_id, 'uk', law_name, sort_key, position, section_type,
      hierarchy_path, depth, part, chapter, heading_group,
      provision, paragraph, sub_paragraph, schedule,
      text, language, extent_code,
      amendment_count, modification_count, commencement_count,
      extent_count, editorial_count,
      embedding, embedding_model, embedded_at,
      token_ids, tokenizer_model, legacy_id,
      created_at, updated_at, law_id
    FROM lat;
    """

    # =========================================================================
    # STEP 4: Add country to amendment_annotations (not partitioned — smaller table)
    # =========================================================================
    execute """
    CREATE TABLE amendment_annotations_new (
      id text NOT NULL,
      country text NOT NULL DEFAULT 'uk',
      law_name text NOT NULL,
      code text NOT NULL,
      code_type text NOT NULL,
      source text NOT NULL,
      text text NOT NULL,
      affected_sections text[],
      created_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      updated_at timestamp without time zone NOT NULL DEFAULT (now() AT TIME ZONE 'utc'),
      law_id uuid NOT NULL,

      PRIMARY KEY (id, country),
      FOREIGN KEY (law_id, country) REFERENCES legal_register (id, country)
    );
    """

    execute """
    INSERT INTO amendment_annotations_new (
      id, country, law_name, code, code_type, source, text,
      affected_sections, created_at, updated_at, law_id
    )
    SELECT
      id, 'uk', law_name, code, code_type, source, text,
      affected_sections, created_at, updated_at, law_id
    FROM amendment_annotations;
    """

    # =========================================================================
    # STEP 5: Add country to law_edges
    # =========================================================================
    execute """
    CREATE TABLE law_edges_new (
      source_law text NOT NULL,
      target_law text NOT NULL,
      edge_type text NOT NULL,
      country text NOT NULL DEFAULT 'uk',
      source_family text,
      target_family text,
      PRIMARY KEY (source_law, target_law, edge_type, country)
    );
    """

    execute """
    INSERT INTO law_edges_new (source_law, target_law, edge_type, country, source_family, target_family)
    SELECT source_law, target_law, edge_type, 'uk', source_family, target_family
    FROM law_edges;
    """

    # =========================================================================
    # STEP 6: Add country to si_code_families
    # =========================================================================
    execute """
    CREATE TABLE si_code_families_new (
      si_code text NOT NULL,
      family text NOT NULL,
      country text NOT NULL DEFAULT 'uk',
      law_count integer DEFAULT 0,
      pct numeric(5,1) DEFAULT 0.0,
      PRIMARY KEY (si_code, family, country)
    );
    """

    execute """
    INSERT INTO si_code_families_new (si_code, family, country, law_count, pct)
    SELECT si_code, family, 'uk', law_count, pct
    FROM si_code_families;
    """

    # =========================================================================
    # STEP 7: Drop old constraints and triggers
    # =========================================================================

    # Drop FK constraints on old tables
    execute "ALTER TABLE lat DROP CONSTRAINT IF EXISTS lat_law_id_fkey;"

    execute "ALTER TABLE amendment_annotations DROP CONSTRAINT IF EXISTS amendment_annotations_law_id_fkey;"

    # Drop triggers on old tables
    execute "DROP TRIGGER IF EXISTS trg_populate_md_date_derived ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_amend_date ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_rescind_date ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_update_lat_stats ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_update_latest_amend_date ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_update_latest_rescind_date ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_lat_stats ON lat;"

    # =========================================================================
    # STEP 8: Rename old tables → _old, create backwards-compat views
    # =========================================================================
    execute "ALTER TABLE uk_lrt RENAME TO uk_lrt_old;"
    execute "ALTER TABLE lat RENAME TO lat_old;"
    execute "ALTER TABLE amendment_annotations RENAME TO amendment_annotations_old;"
    execute "ALTER TABLE law_edges RENAME TO law_edges_old;"
    execute "ALTER TABLE si_code_families RENAME TO si_code_families_old;"

    # Rename new tables without _new suffix
    execute "ALTER TABLE amendment_annotations_new RENAME TO amendment_annotations;"
    execute "ALTER TABLE law_edges_new RENAME TO law_edges;"
    execute "ALTER TABLE si_code_families_new RENAME TO si_code_families;"

    # Create updatable views with old names
    # These views exclude country/jurisdiction so they look identical to old tables
    # PostgreSQL auto-updatable views: simple single-table SELECTs are updatable
    execute """
    CREATE VIEW uk_lrt AS
    SELECT
      id, family, family_ii, name, title_en, year, number, acronym, old_style_number,
      type_desc, type_code, type_class, domain,
      live, live_description, live_from_changes,
      geo_extent, geo_region, geo_detail, md_restrict_extent,
      duty_holder, power_holder, rights_holder, responsibility_holder,
      purpose, function, popimar, popimar_details,
      si_code, enacted_si_codes, enacted_families, md_subjects,
      role, role_gvt, role_details, role_gvt_details, tags,
      md_description, md_total_paras, md_body_paras, md_schedule_paras,
      md_attachment_paras, md_images,
      amending, amended_by, rescinding, rescinded_by, enacting, enacted_by, enacted_by_meta,
      is_amending, is_rescinding, is_enacting, is_making, is_commencing,
      making_confidence, making_classification, making_detection_tier,
      making_detection_signals, making_review, making_review_at,
      created_at, updated_at,
      md_date, md_date_year, md_date_month,
      md_made_date, md_enactment_date, md_coming_into_force_date,
      md_dct_valid_date, md_modified, md_restrict_start_date,
      latest_amend_date, latest_amend_date_year, latest_amend_date_month,
      latest_change_date,
      latest_rescind_date, latest_rescind_date_year, latest_rescind_date_month,
      "🔺🔻_stats_self_affects_count", "🔺_stats_affects_count", "🔺_stats_affected_laws_count",
      "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count",
      "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count",
      "🔺🔻_stats_self_affects_count_per_law_detailed",
      "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law",
      "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law",
      amending_change_log, amended_by_change_log, record_change_log,
      duty_type, duty_type_article, article_duty_type,
      duties, rights, responsibilities, powers,
      fitness_person, fitness_process, fitness_place, fitness_plant,
      fitness_property, fitness_sector, fitness,
      lat_count, latest_lat_updated_at,
      source_url AS leg_gov_uk_url,
      number_int, has_fitness
    FROM legal_register
    WHERE country = 'uk';
    """

    execute """
    CREATE VIEW lat AS
    SELECT
      section_id, law_name, sort_key, position, section_type,
      hierarchy_path, depth, part, chapter, heading_group,
      provision, paragraph, sub_paragraph, schedule,
      text, language, extent_code,
      amendment_count, modification_count, commencement_count,
      extent_count, editorial_count,
      embedding, embedding_model, embedded_at,
      token_ids, tokenizer_model, legacy_id,
      created_at, updated_at, law_id
    FROM legal_articles
    WHERE country = 'uk';
    """

    # INSTEAD OF triggers for INSERT/UPDATE/DELETE on views
    # Required because views with column aliases (source_url AS leg_gov_uk_url)
    # and WHERE clauses are not always auto-updatable for writes
    execute """
    CREATE OR REPLACE FUNCTION uk_lrt_view_insert() RETURNS trigger AS $$
    BEGIN
      INSERT INTO legal_register (
        id, country, jurisdiction,
        family, family_ii, name, title_en, year, number, acronym, old_style_number,
        type_desc, type_code, type_class, domain,
        live, live_description, live_from_changes,
        geo_extent, geo_region, geo_detail, md_restrict_extent,
        duty_holder, power_holder, rights_holder, responsibility_holder,
        purpose, function, popimar, popimar_details,
        si_code, enacted_si_codes, enacted_families, md_subjects,
        role, role_gvt, role_details, role_gvt_details, tags,
        md_description, md_total_paras, md_body_paras, md_schedule_paras,
        md_attachment_paras, md_images,
        amending, amended_by, rescinding, rescinded_by, enacting, enacted_by, enacted_by_meta,
        is_amending, is_rescinding, is_enacting, is_making, is_commencing,
        making_confidence, making_classification, making_detection_tier,
        making_detection_signals, making_review, making_review_at,
        created_at, updated_at,
        md_date, md_date_year, md_date_month,
        md_made_date, md_enactment_date, md_coming_into_force_date,
        md_dct_valid_date, md_modified, md_restrict_start_date,
        latest_amend_date, latest_amend_date_year, latest_amend_date_month,
        latest_change_date,
        latest_rescind_date, latest_rescind_date_year, latest_rescind_date_month,
        "🔺🔻_stats_self_affects_count", "🔺_stats_affects_count", "🔺_stats_affected_laws_count",
        "🔻_stats_affected_by_count", "🔻_stats_affected_by_laws_count",
        "🔺_stats_rescinding_laws_count", "🔻_stats_rescinded_by_laws_count",
        "🔺🔻_stats_self_affects_count_per_law_detailed",
        "🔺_affects_stats_per_law", "🔺_rescinding_stats_per_law",
        "🔻_affected_by_stats_per_law", "🔻_rescinded_by_stats_per_law",
        amending_change_log, amended_by_change_log, record_change_log,
        duty_type, duty_type_article, article_duty_type,
        duties, rights, responsibilities, powers,
        fitness_person, fitness_process, fitness_place, fitness_plant,
        fitness_property, fitness_sector, fitness,
        lat_count, latest_lat_updated_at,
        source_url
      ) VALUES (
        COALESCE(NEW.id, gen_random_uuid()), 'uk', 'uk',
        NEW.family, NEW.family_ii, NEW.name, NEW.title_en, NEW.year, NEW.number,
        NEW.acronym, NEW.old_style_number,
        NEW.type_desc, NEW.type_code, NEW.type_class, NEW.domain,
        NEW.live, NEW.live_description, NEW.live_from_changes,
        NEW.geo_extent, NEW.geo_region, NEW.geo_detail, NEW.md_restrict_extent,
        NEW.duty_holder, NEW.power_holder, NEW.rights_holder, NEW.responsibility_holder,
        NEW.purpose, NEW.function, NEW.popimar, NEW.popimar_details,
        NEW.si_code, NEW.enacted_si_codes, NEW.enacted_families, NEW.md_subjects,
        NEW.role, NEW.role_gvt, NEW.role_details, NEW.role_gvt_details, NEW.tags,
        NEW.md_description, NEW.md_total_paras, NEW.md_body_paras, NEW.md_schedule_paras,
        NEW.md_attachment_paras, NEW.md_images,
        NEW.amending, NEW.amended_by, NEW.rescinding, NEW.rescinded_by,
        NEW.enacting, NEW.enacted_by, NEW.enacted_by_meta,
        NEW.is_amending, NEW.is_rescinding, NEW.is_enacting, NEW.is_making, NEW.is_commencing,
        NEW.making_confidence, NEW.making_classification, NEW.making_detection_tier,
        NEW.making_detection_signals, NEW.making_review, NEW.making_review_at,
        COALESCE(NEW.created_at, now() AT TIME ZONE 'utc'),
        COALESCE(NEW.updated_at, now() AT TIME ZONE 'utc'),
        NEW.md_date, NEW.md_date_year, NEW.md_date_month,
        NEW.md_made_date, NEW.md_enactment_date, NEW.md_coming_into_force_date,
        NEW.md_dct_valid_date, NEW.md_modified, NEW.md_restrict_start_date,
        NEW.latest_amend_date, NEW.latest_amend_date_year, NEW.latest_amend_date_month,
        NEW.latest_change_date,
        NEW.latest_rescind_date, NEW.latest_rescind_date_year, NEW.latest_rescind_date_month,
        NEW."🔺🔻_stats_self_affects_count", NEW."🔺_stats_affects_count",
        NEW."🔺_stats_affected_laws_count",
        NEW."🔻_stats_affected_by_count", NEW."🔻_stats_affected_by_laws_count",
        NEW."🔺_stats_rescinding_laws_count", NEW."🔻_stats_rescinded_by_laws_count",
        NEW."🔺🔻_stats_self_affects_count_per_law_detailed",
        NEW."🔺_affects_stats_per_law", NEW."🔺_rescinding_stats_per_law",
        NEW."🔻_affected_by_stats_per_law", NEW."🔻_rescinded_by_stats_per_law",
        NEW.amending_change_log, NEW.amended_by_change_log, NEW.record_change_log,
        NEW.duty_type, NEW.duty_type_article, NEW.article_duty_type,
        NEW.duties, NEW.rights, NEW.responsibilities, NEW.powers,
        NEW.fitness_person, NEW.fitness_process, NEW.fitness_place, NEW.fitness_plant,
        NEW.fitness_property, NEW.fitness_sector, NEW.fitness,
        COALESCE(NEW.lat_count, 0), NEW.latest_lat_updated_at,
        NEW.leg_gov_uk_url
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION uk_lrt_view_update() RETURNS trigger AS $$
    BEGIN
      UPDATE legal_register SET
        family = NEW.family, family_ii = NEW.family_ii,
        name = NEW.name, title_en = NEW.title_en,
        year = NEW.year, number = NEW.number,
        acronym = NEW.acronym, old_style_number = NEW.old_style_number,
        type_desc = NEW.type_desc, type_code = NEW.type_code, type_class = NEW.type_class,
        domain = NEW.domain,
        live = NEW.live, live_description = NEW.live_description,
        live_from_changes = NEW.live_from_changes,
        geo_extent = NEW.geo_extent, geo_region = NEW.geo_region,
        geo_detail = NEW.geo_detail, md_restrict_extent = NEW.md_restrict_extent,
        duty_holder = NEW.duty_holder, power_holder = NEW.power_holder,
        rights_holder = NEW.rights_holder, responsibility_holder = NEW.responsibility_holder,
        purpose = NEW.purpose, function = NEW.function,
        popimar = NEW.popimar, popimar_details = NEW.popimar_details,
        si_code = NEW.si_code, enacted_si_codes = NEW.enacted_si_codes,
        enacted_families = NEW.enacted_families, md_subjects = NEW.md_subjects,
        role = NEW.role, role_gvt = NEW.role_gvt,
        role_details = NEW.role_details, role_gvt_details = NEW.role_gvt_details,
        tags = NEW.tags,
        md_description = NEW.md_description,
        md_total_paras = NEW.md_total_paras, md_body_paras = NEW.md_body_paras,
        md_schedule_paras = NEW.md_schedule_paras,
        md_attachment_paras = NEW.md_attachment_paras, md_images = NEW.md_images,
        amending = NEW.amending, amended_by = NEW.amended_by,
        rescinding = NEW.rescinding, rescinded_by = NEW.rescinded_by,
        enacting = NEW.enacting, enacted_by = NEW.enacted_by,
        enacted_by_meta = NEW.enacted_by_meta,
        is_amending = NEW.is_amending, is_rescinding = NEW.is_rescinding,
        is_enacting = NEW.is_enacting, is_making = NEW.is_making,
        is_commencing = NEW.is_commencing,
        making_confidence = NEW.making_confidence,
        making_classification = NEW.making_classification,
        making_detection_tier = NEW.making_detection_tier,
        making_detection_signals = NEW.making_detection_signals,
        making_review = NEW.making_review, making_review_at = NEW.making_review_at,
        updated_at = COALESCE(NEW.updated_at, now() AT TIME ZONE 'utc'),
        md_date = NEW.md_date, md_date_year = NEW.md_date_year,
        md_date_month = NEW.md_date_month,
        md_made_date = NEW.md_made_date, md_enactment_date = NEW.md_enactment_date,
        md_coming_into_force_date = NEW.md_coming_into_force_date,
        md_dct_valid_date = NEW.md_dct_valid_date, md_modified = NEW.md_modified,
        md_restrict_start_date = NEW.md_restrict_start_date,
        latest_amend_date = NEW.latest_amend_date,
        latest_amend_date_year = NEW.latest_amend_date_year,
        latest_amend_date_month = NEW.latest_amend_date_month,
        latest_change_date = NEW.latest_change_date,
        latest_rescind_date = NEW.latest_rescind_date,
        latest_rescind_date_year = NEW.latest_rescind_date_year,
        latest_rescind_date_month = NEW.latest_rescind_date_month,
        "🔺🔻_stats_self_affects_count" = NEW."🔺🔻_stats_self_affects_count",
        "🔺_stats_affects_count" = NEW."🔺_stats_affects_count",
        "🔺_stats_affected_laws_count" = NEW."🔺_stats_affected_laws_count",
        "🔻_stats_affected_by_count" = NEW."🔻_stats_affected_by_count",
        "🔻_stats_affected_by_laws_count" = NEW."🔻_stats_affected_by_laws_count",
        "🔺_stats_rescinding_laws_count" = NEW."🔺_stats_rescinding_laws_count",
        "🔻_stats_rescinded_by_laws_count" = NEW."🔻_stats_rescinded_by_laws_count",
        "🔺🔻_stats_self_affects_count_per_law_detailed" = NEW."🔺🔻_stats_self_affects_count_per_law_detailed",
        "🔺_affects_stats_per_law" = NEW."🔺_affects_stats_per_law",
        "🔺_rescinding_stats_per_law" = NEW."🔺_rescinding_stats_per_law",
        "🔻_affected_by_stats_per_law" = NEW."🔻_affected_by_stats_per_law",
        "🔻_rescinded_by_stats_per_law" = NEW."🔻_rescinded_by_stats_per_law",
        amending_change_log = NEW.amending_change_log,
        amended_by_change_log = NEW.amended_by_change_log,
        record_change_log = NEW.record_change_log,
        duty_type = NEW.duty_type, duty_type_article = NEW.duty_type_article,
        article_duty_type = NEW.article_duty_type,
        duties = NEW.duties, rights = NEW.rights,
        responsibilities = NEW.responsibilities, powers = NEW.powers,
        fitness_person = NEW.fitness_person, fitness_process = NEW.fitness_process,
        fitness_place = NEW.fitness_place, fitness_plant = NEW.fitness_plant,
        fitness_property = NEW.fitness_property, fitness_sector = NEW.fitness_sector,
        fitness = NEW.fitness,
        lat_count = NEW.lat_count, latest_lat_updated_at = NEW.latest_lat_updated_at,
        source_url = NEW.leg_gov_uk_url
      WHERE id = OLD.id AND country = 'uk';
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION uk_lrt_view_delete() RETURNS trigger AS $$
    BEGIN
      DELETE FROM legal_register WHERE id = OLD.id AND country = 'uk';
      RETURN OLD;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute "CREATE TRIGGER trg_uk_lrt_view_insert INSTEAD OF INSERT ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_insert();"

    execute "CREATE TRIGGER trg_uk_lrt_view_update INSTEAD OF UPDATE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_update();"

    execute "CREATE TRIGGER trg_uk_lrt_view_delete INSTEAD OF DELETE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_delete();"

    # LAT view triggers
    execute """
    CREATE OR REPLACE FUNCTION lat_view_insert() RETURNS trigger AS $$
    BEGIN
      INSERT INTO legal_articles (
        section_id, country, law_name, sort_key, position, section_type,
        hierarchy_path, depth, part, chapter, heading_group,
        provision, paragraph, sub_paragraph, schedule,
        text, language, extent_code,
        amendment_count, modification_count, commencement_count,
        extent_count, editorial_count,
        embedding, embedding_model, embedded_at,
        token_ids, tokenizer_model, legacy_id,
        created_at, updated_at, law_id
      ) VALUES (
        NEW.section_id, 'uk', NEW.law_name, NEW.sort_key, NEW.position, NEW.section_type,
        NEW.hierarchy_path, NEW.depth, NEW.part, NEW.chapter, NEW.heading_group,
        NEW.provision, NEW.paragraph, NEW.sub_paragraph, NEW.schedule,
        NEW.text, COALESCE(NEW.language, 'en'), NEW.extent_code,
        NEW.amendment_count, NEW.modification_count, NEW.commencement_count,
        NEW.extent_count, NEW.editorial_count,
        NEW.embedding, NEW.embedding_model, NEW.embedded_at,
        NEW.token_ids, NEW.tokenizer_model, NEW.legacy_id,
        COALESCE(NEW.created_at, now() AT TIME ZONE 'utc'),
        COALESCE(NEW.updated_at, now() AT TIME ZONE 'utc'),
        NEW.law_id
      );
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION lat_view_update() RETURNS trigger AS $$
    BEGIN
      UPDATE legal_articles SET
        law_name = NEW.law_name, sort_key = NEW.sort_key,
        position = NEW.position, section_type = NEW.section_type,
        hierarchy_path = NEW.hierarchy_path, depth = NEW.depth,
        part = NEW.part, chapter = NEW.chapter, heading_group = NEW.heading_group,
        provision = NEW.provision, paragraph = NEW.paragraph,
        sub_paragraph = NEW.sub_paragraph, schedule = NEW.schedule,
        text = NEW.text, language = NEW.language, extent_code = NEW.extent_code,
        amendment_count = NEW.amendment_count, modification_count = NEW.modification_count,
        commencement_count = NEW.commencement_count,
        extent_count = NEW.extent_count, editorial_count = NEW.editorial_count,
        embedding = NEW.embedding, embedding_model = NEW.embedding_model,
        embedded_at = NEW.embedded_at,
        token_ids = NEW.token_ids, tokenizer_model = NEW.tokenizer_model,
        legacy_id = NEW.legacy_id,
        updated_at = COALESCE(NEW.updated_at, now() AT TIME ZONE 'utc'),
        law_id = NEW.law_id
      WHERE section_id = OLD.section_id AND country = 'uk';
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION lat_view_delete() RETURNS trigger AS $$
    BEGIN
      DELETE FROM legal_articles WHERE section_id = OLD.section_id AND country = 'uk';
      RETURN OLD;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute "CREATE TRIGGER trg_lat_view_insert INSTEAD OF INSERT ON lat FOR EACH ROW EXECUTE FUNCTION lat_view_insert();"

    execute "CREATE TRIGGER trg_lat_view_update INSTEAD OF UPDATE ON lat FOR EACH ROW EXECUTE FUNCTION lat_view_update();"

    execute "CREATE TRIGGER trg_lat_view_delete INSTEAD OF DELETE ON lat FOR EACH ROW EXECUTE FUNCTION lat_view_delete();"

    # =========================================================================
    # STEP 9: Recreate indexes on new tables
    # =========================================================================

    # legal_register indexes (on partition, PostgreSQL creates them automatically
    # when defined on parent — but we define on parent for clarity)
    execute "CREATE INDEX idx_lr_family ON legal_register (family);"
    execute "CREATE INDEX idx_lr_family_ii ON legal_register (family_ii);"
    execute "CREATE INDEX idx_lr_year ON legal_register (year);"
    execute "CREATE INDEX idx_lr_live ON legal_register (live);"
    execute "CREATE INDEX idx_lr_geo_extent ON legal_register (geo_extent);"
    execute "CREATE INDEX idx_lr_type_code ON legal_register (type_code);"
    execute "CREATE INDEX idx_lr_name ON legal_register (name);"
    execute "CREATE UNIQUE INDEX idx_lr_unique_name ON legal_register (name, country);"
    execute "CREATE INDEX idx_lr_live_family_geo ON legal_register (live, family, geo_extent);"
    execute "CREATE INDEX idx_lr_is_making ON legal_register (is_making) WHERE is_making = true;"
    execute "CREATE INDEX idx_lr_country ON legal_register (country);"

    # GIN indexes
    execute "CREATE INDEX idx_lr_duty_holder_gin ON legal_register USING gin (duty_holder);"
    execute "CREATE INDEX idx_lr_purpose_gin ON legal_register USING gin (purpose);"
    execute "CREATE INDEX idx_lr_function_gin ON legal_register USING gin (function);"

    execute "CREATE INDEX idx_lr_function_making ON legal_register USING gin (function) WHERE function ? 'Making';"

    execute "CREATE INDEX idx_lr_function_composite ON legal_register (family, geo_extent, live) WHERE function ? 'Making';"

    execute "CREATE INDEX idx_lr_role_gin ON legal_register USING gin (role);"
    execute "CREATE INDEX idx_lr_tags_gin ON legal_register USING gin (tags);"
    execute "CREATE INDEX idx_lr_amended_by_gin ON legal_register USING gin (amended_by);"
    execute "CREATE INDEX idx_lr_rescinded_by_gin ON legal_register USING gin (rescinded_by);"

    execute "CREATE INDEX idx_lr_duties_holders_gin ON legal_register USING gin ((duties -> 'holders'));"

    execute "CREATE INDEX idx_lr_rights_holders_gin ON legal_register USING gin ((rights -> 'holders'));"

    execute "CREATE INDEX idx_lr_responsibilities_holders_gin ON legal_register USING gin ((responsibilities -> 'holders'));"

    execute "CREATE INDEX idx_lr_powers_holders_gin ON legal_register USING gin ((powers -> 'holders'));"

    execute "CREATE INDEX idx_lr_role_details_gin ON legal_register USING gin (role_details);"

    execute "CREATE INDEX idx_lr_role_gvt_details_gin ON legal_register USING gin (role_gvt_details);"

    execute "CREATE INDEX idx_lr_popimar_categories ON legal_register USING gin ((popimar_details -> 'categories')) WHERE popimar_details IS NOT NULL;"

    execute "CREATE INDEX idx_lr_popimar_entries ON legal_register USING gin ((popimar_details -> 'entries') jsonb_path_ops) WHERE popimar_details IS NOT NULL;"

    # legal_articles indexes
    execute "CREATE INDEX idx_la_law_name ON legal_articles (law_name);"
    execute "CREATE INDEX idx_la_law_id ON legal_articles (law_id);"
    execute "CREATE INDEX idx_la_sort_order ON legal_articles (law_name, sort_key);"
    execute "CREATE INDEX idx_la_section_type ON legal_articles (section_type);"
    execute "CREATE INDEX idx_la_language ON legal_articles (language);"

    execute "CREATE INDEX idx_la_provision ON legal_articles (law_name, provision) WHERE provision IS NOT NULL;"

    # amendment_annotations indexes
    execute "CREATE INDEX idx_aa_law_name ON amendment_annotations (law_name);"
    execute "CREATE INDEX idx_aa_code_type ON amendment_annotations (code_type);"
    execute "CREATE INDEX idx_aa_law_id ON amendment_annotations (law_id);"

    # law_edges indexes
    execute "CREATE INDEX idx_le_target ON law_edges (target_law, edge_type);"
    execute "CREATE INDEX idx_le_source_family ON law_edges (source_family);"
    execute "CREATE INDEX idx_le_target_family ON law_edges (target_family);"
    execute "CREATE INDEX idx_le_edge_type ON law_edges (edge_type);"
    execute "CREATE INDEX idx_le_country ON law_edges (country);"

    # si_code_families indexes
    execute "CREATE INDEX idx_scf_family ON si_code_families (family);"
    execute "CREATE INDEX idx_scf_country ON si_code_families (country);"

    # =========================================================================
    # STEP 10: Recreate trigger functions for new table names
    # =========================================================================

    # Update trigger functions to reference legal_register instead of uk_lrt
    execute """
    CREATE OR REPLACE FUNCTION update_latest_amend_date() RETURNS trigger AS $$
    BEGIN
        IF NEW.amended_by IS NOT NULL AND array_length(NEW.amended_by, 1) > 0 THEN
            NEW.latest_amend_date := (
                SELECT MAX(amender.md_date)
                FROM legal_register amender
                WHERE amender.name = ANY(NEW.amended_by)
                  AND amender.country = NEW.country
            );
            NEW.latest_amend_date_year := EXTRACT(YEAR FROM NEW.latest_amend_date)::integer;
            NEW.latest_amend_date_month := EXTRACT(MONTH FROM NEW.latest_amend_date)::integer;
        ELSE
            NEW.latest_amend_date := NULL;
            NEW.latest_amend_date_year := NULL;
            NEW.latest_amend_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_amend_date_change() RETURNS trigger AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            UPDATE legal_register target
            SET
                latest_amend_date = (
                    SELECT MAX(amender.md_date)
                    FROM legal_register amender
                    WHERE amender.name = ANY(target.amended_by)
                      AND amender.country = target.country
                ),
                latest_amend_date_year = EXTRACT(YEAR FROM (
                    SELECT MAX(amender.md_date)
                    FROM legal_register amender
                    WHERE amender.name = ANY(target.amended_by)
                      AND amender.country = target.country
                ))::integer,
                latest_amend_date_month = EXTRACT(MONTH FROM (
                    SELECT MAX(amender.md_date)
                    FROM legal_register amender
                    WHERE amender.name = ANY(target.amended_by)
                      AND amender.country = target.country
                ))::integer
            WHERE target.amended_by @> ARRAY[NEW.name]::text[]
              AND target.country = NEW.country;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_latest_rescind_date() RETURNS trigger AS $$
    BEGIN
        IF NEW.rescinded_by IS NOT NULL AND array_length(NEW.rescinded_by, 1) > 0 THEN
            NEW.latest_rescind_date := (
                SELECT MAX(rescinder.md_date)
                FROM legal_register rescinder
                WHERE rescinder.name = ANY(NEW.rescinded_by)
                  AND rescinder.country = NEW.country
            );
            NEW.latest_rescind_date_year := EXTRACT(YEAR FROM NEW.latest_rescind_date)::integer;
            NEW.latest_rescind_date_month := EXTRACT(MONTH FROM NEW.latest_rescind_date)::integer;
        ELSE
            NEW.latest_rescind_date := NULL;
            NEW.latest_rescind_date_year := NULL;
            NEW.latest_rescind_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_rescind_date_change() RETURNS trigger AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            UPDATE legal_register target
            SET
                latest_rescind_date = (
                    SELECT MAX(rescinder.md_date)
                    FROM legal_register rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                      AND rescinder.country = target.country
                ),
                latest_rescind_date_year = EXTRACT(YEAR FROM (
                    SELECT MAX(rescinder.md_date)
                    FROM legal_register rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                      AND rescinder.country = target.country
                ))::integer,
                latest_rescind_date_month = EXTRACT(MONTH FROM (
                    SELECT MAX(rescinder.md_date)
                    FROM legal_register rescinder
                    WHERE rescinder.name = ANY(target.rescinded_by)
                      AND rescinder.country = target.country
                ))::integer
            WHERE target.rescinded_by @> ARRAY[NEW.name]::text[]
              AND target.country = NEW.country;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_lat_stats() RETURNS trigger AS $$
    BEGIN
        SELECT COUNT(*), MAX(updated_at)
        INTO NEW.lat_count, NEW.latest_lat_updated_at
        FROM legal_articles
        WHERE legal_articles.law_id = NEW.id
          AND legal_articles.country = NEW.country;

        IF NEW.lat_count IS NULL THEN
            NEW.lat_count := 0;
        END IF;

        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_lat_stats() RETURNS trigger AS $$
    DECLARE
        target_law_id uuid;
        target_country text;
    BEGIN
        target_law_id := COALESCE(NEW.law_id, OLD.law_id);
        target_country := COALESCE(NEW.country, OLD.country);

        UPDATE legal_register
        SET lat_count = COALESCE((SELECT COUNT(*) FROM legal_articles WHERE law_id = target_law_id AND country = target_country), 0),
            latest_lat_updated_at = (SELECT MAX(updated_at) FROM legal_articles WHERE law_id = target_law_id AND country = target_country),
            updated_at = NOW()
        WHERE id = target_law_id AND country = target_country;

        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    """

    # populate_md_date_derived is already generic (no table reference)

    # =========================================================================
    # STEP 11: Create triggers on new tables
    # =========================================================================
    execute "CREATE TRIGGER trg_populate_md_date_derived BEFORE INSERT OR UPDATE OF md_date ON legal_register FOR EACH ROW EXECUTE FUNCTION populate_md_date_derived();"

    execute "CREATE TRIGGER trg_update_latest_amend_date BEFORE INSERT OR UPDATE OF amended_by ON legal_register FOR EACH ROW EXECUTE FUNCTION update_latest_amend_date();"

    execute "CREATE TRIGGER trg_propagate_amend_date AFTER UPDATE OF md_date ON legal_register FOR EACH ROW EXECUTE FUNCTION propagate_amend_date_change();"

    execute "CREATE TRIGGER trg_update_latest_rescind_date BEFORE INSERT OR UPDATE OF rescinded_by ON legal_register FOR EACH ROW EXECUTE FUNCTION update_latest_rescind_date();"

    execute "CREATE TRIGGER trg_propagate_rescind_date AFTER UPDATE OF md_date ON legal_register FOR EACH ROW EXECUTE FUNCTION propagate_rescind_date_change();"

    execute "CREATE TRIGGER trg_update_lat_stats BEFORE INSERT OR UPDATE ON legal_register FOR EACH ROW EXECUTE FUNCTION update_lat_stats();"

    execute "CREATE TRIGGER trg_propagate_lat_stats AFTER INSERT OR UPDATE OR DELETE ON legal_articles FOR EACH ROW EXECUTE FUNCTION propagate_lat_stats();"

    # =========================================================================
    # STEP 12: REPLICA IDENTITY for ElectricSQL
    # =========================================================================
    execute "ALTER TABLE legal_register_uk REPLICA IDENTITY FULL;"
    execute "ALTER TABLE legal_articles_uk REPLICA IDENTITY FULL;"
    execute "ALTER TABLE amendment_annotations REPLICA IDENTITY FULL;"
  end

  def down do
    # Drop views and their triggers
    execute "DROP TRIGGER IF EXISTS trg_uk_lrt_view_insert ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_uk_lrt_view_update ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_uk_lrt_view_delete ON uk_lrt;"
    execute "DROP TRIGGER IF EXISTS trg_lat_view_insert ON lat;"
    execute "DROP TRIGGER IF EXISTS trg_lat_view_update ON lat;"
    execute "DROP TRIGGER IF EXISTS trg_lat_view_delete ON lat;"
    execute "DROP VIEW IF EXISTS uk_lrt;"
    execute "DROP VIEW IF EXISTS lat;"

    # Drop view trigger functions
    execute "DROP FUNCTION IF EXISTS uk_lrt_view_insert();"
    execute "DROP FUNCTION IF EXISTS uk_lrt_view_update();"
    execute "DROP FUNCTION IF EXISTS uk_lrt_view_delete();"
    execute "DROP FUNCTION IF EXISTS lat_view_insert();"
    execute "DROP FUNCTION IF EXISTS lat_view_update();"
    execute "DROP FUNCTION IF EXISTS lat_view_delete();"

    # Drop triggers on new tables
    execute "DROP TRIGGER IF EXISTS trg_populate_md_date_derived ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_update_latest_amend_date ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_amend_date ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_update_latest_rescind_date ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_rescind_date ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_update_lat_stats ON legal_register;"
    execute "DROP TRIGGER IF EXISTS trg_propagate_lat_stats ON legal_articles;"

    # Drop new tables
    execute "DROP TABLE IF EXISTS si_code_families;"
    execute "DROP TABLE IF EXISTS law_edges;"
    execute "DROP TABLE IF EXISTS amendment_annotations;"
    execute "DROP TABLE IF EXISTS legal_articles_uk;"
    execute "DROP TABLE IF EXISTS legal_articles;"
    execute "DROP TABLE IF EXISTS legal_register_uk;"
    execute "DROP TABLE IF EXISTS legal_register;"

    # Restore old tables
    execute "ALTER TABLE uk_lrt_old RENAME TO uk_lrt;"
    execute "ALTER TABLE lat_old RENAME TO lat;"
    execute "ALTER TABLE amendment_annotations_old RENAME TO amendment_annotations;"
    execute "ALTER TABLE law_edges_old RENAME TO law_edges;"
    execute "ALTER TABLE si_code_families_old RENAME TO si_code_families;"

    # Restore FK constraints
    execute "ALTER TABLE lat ADD CONSTRAINT lat_law_id_fkey FOREIGN KEY (law_id) REFERENCES uk_lrt(id);"

    execute "ALTER TABLE amendment_annotations ADD CONSTRAINT amendment_annotations_law_id_fkey FOREIGN KEY (law_id) REFERENCES uk_lrt(id);"

    # Restore triggers on original tables
    execute "CREATE TRIGGER trg_populate_md_date_derived BEFORE INSERT OR UPDATE OF md_date ON uk_lrt FOR EACH ROW EXECUTE FUNCTION populate_md_date_derived();"

    execute "CREATE TRIGGER trg_update_latest_amend_date BEFORE INSERT OR UPDATE OF amended_by ON uk_lrt FOR EACH ROW EXECUTE FUNCTION update_latest_amend_date();"

    execute "CREATE TRIGGER trg_propagate_amend_date AFTER UPDATE OF md_date ON uk_lrt FOR EACH ROW EXECUTE FUNCTION propagate_amend_date_change();"

    execute "CREATE TRIGGER trg_update_latest_rescind_date BEFORE INSERT OR UPDATE OF rescinded_by ON uk_lrt FOR EACH ROW EXECUTE FUNCTION update_latest_rescind_date();"

    execute "CREATE TRIGGER trg_propagate_rescind_date AFTER UPDATE OF md_date ON uk_lrt FOR EACH ROW EXECUTE FUNCTION propagate_rescind_date_change();"

    execute "CREATE TRIGGER trg_update_lat_stats BEFORE INSERT OR UPDATE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION update_lat_stats();"

    execute "CREATE TRIGGER trg_propagate_lat_stats AFTER INSERT OR UPDATE OR DELETE ON lat FOR EACH ROW EXECUTE FUNCTION propagate_lat_stats();"

    # Restore trigger functions to reference uk_lrt
    execute """
    CREATE OR REPLACE FUNCTION update_latest_amend_date() RETURNS trigger AS $$
    BEGIN
        IF NEW.amended_by IS NOT NULL AND array_length(NEW.amended_by, 1) > 0 THEN
            NEW.latest_amend_date := (
                SELECT MAX(amender.md_date) FROM uk_lrt amender
                WHERE amender.name = ANY(NEW.amended_by)
            );
            NEW.latest_amend_date_year := EXTRACT(YEAR FROM NEW.latest_amend_date)::integer;
            NEW.latest_amend_date_month := EXTRACT(MONTH FROM NEW.latest_amend_date)::integer;
        ELSE
            NEW.latest_amend_date := NULL;
            NEW.latest_amend_date_year := NULL;
            NEW.latest_amend_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_amend_date_change() RETURNS trigger AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            UPDATE uk_lrt target SET
                latest_amend_date = (SELECT MAX(amender.md_date) FROM uk_lrt amender WHERE amender.name = ANY(target.amended_by)),
                latest_amend_date_year = EXTRACT(YEAR FROM (SELECT MAX(amender.md_date) FROM uk_lrt amender WHERE amender.name = ANY(target.amended_by)))::integer,
                latest_amend_date_month = EXTRACT(MONTH FROM (SELECT MAX(amender.md_date) FROM uk_lrt amender WHERE amender.name = ANY(target.amended_by)))::integer
            WHERE target.amended_by @> ARRAY[NEW.name]::text[];
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_latest_rescind_date() RETURNS trigger AS $$
    BEGIN
        IF NEW.rescinded_by IS NOT NULL AND array_length(NEW.rescinded_by, 1) > 0 THEN
            NEW.latest_rescind_date := (
                SELECT MAX(rescinder.md_date) FROM uk_lrt rescinder
                WHERE rescinder.name = ANY(NEW.rescinded_by)
            );
            NEW.latest_rescind_date_year := EXTRACT(YEAR FROM NEW.latest_rescind_date)::integer;
            NEW.latest_rescind_date_month := EXTRACT(MONTH FROM NEW.latest_rescind_date)::integer;
        ELSE
            NEW.latest_rescind_date := NULL;
            NEW.latest_rescind_date_year := NULL;
            NEW.latest_rescind_date_month := NULL;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_rescind_date_change() RETURNS trigger AS $$
    BEGIN
        IF OLD.md_date IS DISTINCT FROM NEW.md_date THEN
            UPDATE uk_lrt target SET
                latest_rescind_date = (SELECT MAX(rescinder.md_date) FROM uk_lrt rescinder WHERE rescinder.name = ANY(target.rescinded_by)),
                latest_rescind_date_year = EXTRACT(YEAR FROM (SELECT MAX(rescinder.md_date) FROM uk_lrt rescinder WHERE rescinder.name = ANY(target.rescinded_by)))::integer,
                latest_rescind_date_month = EXTRACT(MONTH FROM (SELECT MAX(rescinder.md_date) FROM uk_lrt rescinder WHERE rescinder.name = ANY(target.rescinded_by)))::integer
            WHERE target.rescinded_by @> ARRAY[NEW.name]::text[];
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION update_lat_stats() RETURNS trigger AS $$
    BEGIN
        SELECT COUNT(*), MAX(updated_at)
        INTO NEW.lat_count, NEW.latest_lat_updated_at
        FROM lat WHERE lat.law_id = NEW.id;
        IF NEW.lat_count IS NULL THEN NEW.lat_count := 0; END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION propagate_lat_stats() RETURNS trigger AS $$
    DECLARE target_law_id uuid;
    BEGIN
        target_law_id := COALESCE(NEW.law_id, OLD.law_id);
        UPDATE uk_lrt SET
            lat_count = COALESCE((SELECT COUNT(*) FROM lat WHERE law_id = target_law_id), 0),
            latest_lat_updated_at = (SELECT MAX(updated_at) FROM lat WHERE law_id = target_law_id),
            updated_at = NOW()
        WHERE id = target_law_id;
        RETURN COALESCE(NEW, OLD);
    END;
    $$ LANGUAGE plpgsql;
    """

    # Restore REPLICA IDENTITY
    execute "ALTER TABLE uk_lrt REPLICA IDENTITY FULL;"
    execute "ALTER TABLE lat REPLICA IDENTITY FULL;"
    execute "ALTER TABLE amendment_annotations REPLICA IDENTITY FULL;"
  end
end
