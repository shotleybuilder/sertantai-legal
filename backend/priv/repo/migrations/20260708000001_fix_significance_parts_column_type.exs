defmodule SertantaiLegal.Repo.Migrations.FixSignificancePartsColumnType do
  @moduledoc """
  Fix significance_parts column type from jsonb to jsonb[].

  The Ash schema declares significance_parts as {:array, :map} which maps to
  jsonb[] in PostgreSQL. Migration 20260702000002 created it as plain jsonb.
  The column has never been populated, so no data conversion is needed.

  Must drop and recreate uk_lrt view + triggers because the view depends on
  the column. See 20260703000001 for the trigger pattern.
  """

  use Ecto.Migration

  def up do
    # Drop view (triggers are dropped automatically)
    execute("DROP VIEW IF EXISTS uk_lrt")

    # Drop trigger functions
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_insert() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_update() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_delete() CASCADE")

    # Alter column type on parent table (partitions inherit)
    execute("""
    ALTER TABLE legal_register
    ALTER COLUMN significance_parts TYPE jsonb[]
    USING CASE WHEN significance_parts IS NULL THEN NULL
               ELSE ARRAY[significance_parts]
          END
    """)

    # Recreate view (same as 20260703000001 — explicit columns, no country/jurisdiction)
    execute("""
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
      source_url, number_int, has_fitness,
      significance_rating, significance_score,
      significance_high_count, significance_medium_count,
      significance_low_count, significance_total_obligations,
      significance_parts
    FROM legal_register
    WHERE country = 'uk'
    """)

    # Recreate INSTEAD OF INSERT trigger function
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_insert() RETURNS trigger AS $function$
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
        source_url,
        significance_rating, significance_score,
        significance_high_count, significance_medium_count,
        significance_low_count, significance_total_obligations,
        significance_parts
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
        NEW.source_url,
        NEW.significance_rating, NEW.significance_score,
        NEW.significance_high_count, NEW.significance_medium_count,
        NEW.significance_low_count, NEW.significance_total_obligations,
        NEW.significance_parts
      );
      RETURN NEW;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # Recreate INSTEAD OF UPDATE trigger function
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_update() RETURNS trigger AS $function$
    BEGIN
      UPDATE legal_register SET
        family = NEW.family, family_ii = NEW.family_ii,
        name = NEW.name, title_en = NEW.title_en, year = NEW.year, number = NEW.number,
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
        enacting = NEW.enacting, enacted_by = NEW.enacted_by, enacted_by_meta = NEW.enacted_by_meta,
        is_amending = NEW.is_amending, is_rescinding = NEW.is_rescinding,
        is_enacting = NEW.is_enacting, is_making = NEW.is_making, is_commencing = NEW.is_commencing,
        making_confidence = NEW.making_confidence,
        making_classification = NEW.making_classification,
        making_detection_tier = NEW.making_detection_tier,
        making_detection_signals = NEW.making_detection_signals,
        making_review = NEW.making_review, making_review_at = NEW.making_review_at,
        updated_at = COALESCE(NEW.updated_at, now() AT TIME ZONE 'utc'),
        md_date = NEW.md_date, md_date_year = NEW.md_date_year, md_date_month = NEW.md_date_month,
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
        source_url = NEW.source_url,
        significance_rating = NEW.significance_rating,
        significance_score = NEW.significance_score,
        significance_high_count = NEW.significance_high_count,
        significance_medium_count = NEW.significance_medium_count,
        significance_low_count = NEW.significance_low_count,
        significance_total_obligations = NEW.significance_total_obligations,
        significance_parts = NEW.significance_parts
      WHERE id = OLD.id;
      RETURN NEW;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # Recreate INSTEAD OF DELETE trigger function
    execute("""
    CREATE OR REPLACE FUNCTION uk_lrt_view_delete() RETURNS trigger AS $function$
    BEGIN
      DELETE FROM legal_register WHERE id = OLD.id;
      RETURN OLD;
    END;
    $function$ LANGUAGE plpgsql
    """)

    # Recreate triggers
    execute(
      "CREATE TRIGGER trg_uk_lrt_view_insert INSTEAD OF INSERT ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_insert()"
    )

    execute(
      "CREATE TRIGGER trg_uk_lrt_view_update INSTEAD OF UPDATE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_update()"
    )

    execute(
      "CREATE TRIGGER trg_uk_lrt_view_delete INSTEAD OF DELETE ON uk_lrt FOR EACH ROW EXECUTE FUNCTION uk_lrt_view_delete()"
    )
  end

  def down do
    # Revert: same dance but change jsonb[] back to jsonb
    execute("DROP VIEW IF EXISTS uk_lrt CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_insert() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_update() CASCADE")
    execute("DROP FUNCTION IF EXISTS uk_lrt_view_delete() CASCADE")

    execute("""
    ALTER TABLE legal_register
    ALTER COLUMN significance_parts TYPE jsonb
    USING significance_parts[1]
    """)

    # View and triggers would need to be recreated — but rolling back
    # should restore from the previous migration state via mix ecto.rollback
  end
end
