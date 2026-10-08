defmodule SertantaiLegal.Repo.Migrations.RenameRepealedExtentToExcludedExtent do
  @moduledoc """
  LAT parser coverage II (Jason, 2026-10-08): `repealed_extent` becomes
  `excluded_extent` — the territories where a row's text does not apply,
  covering rows wholly repealed in some territories (Repeal RetainText) and
  rows wholly inserted for a narrower territory. A view column can't be
  renamed by CREATE OR REPLACE, so the `lat` view is recreated (nothing
  depends on it). Not part of lat_hash / struct_hash.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE legal_articles RENAME COLUMN repealed_extent TO excluded_extent")
    execute("DROP VIEW lat")

    execute("""
    CREATE VIEW lat AS
     SELECT section_id,
        country,
        law_name,
        sort_key,
        "position",
        section_type,
        hierarchy_path,
        depth,
        part,
        chapter,
        heading_group,
        provision,
        paragraph,
        sub_paragraph,
        schedule,
        text,
        language,
        extent_code,
        amendment_count,
        modification_count,
        commencement_count,
        extent_count,
        editorial_count,
        embedding,
        embedding_model,
        embedded_at,
        token_ids,
        tokenizer_model,
        legacy_id,
        created_at,
        updated_at,
        law_id,
        drrp_types,
        governed_actors,
        government_actors,
        duty_family,
        duty_sub_type,
        clause_refined,
        purposes,
        popimar,
        taxa_confidence,
        taxa_enriched_at,
        actors,
        extraction_method,
        holder_inferred_from,
        ancestor_distance,
        significance_scope_duty_bearer,
        significance_scope_protected_class,
        significance_gravity,
        significance_strength,
        significance_hierarchy,
        significance_confidence,
        significance_overall,
        sub_provision,
        status,
        effective_from,
        changed_by,
        title,
        excluded_extent
       FROM legal_articles_uk;
    """)
  end

  def down do
    execute("ALTER TABLE legal_articles RENAME COLUMN excluded_extent TO repealed_extent")
    execute("DROP VIEW lat")

    execute("""
    CREATE VIEW lat AS
     SELECT section_id,
        country,
        law_name,
        sort_key,
        "position",
        section_type,
        hierarchy_path,
        depth,
        part,
        chapter,
        heading_group,
        provision,
        paragraph,
        sub_paragraph,
        schedule,
        text,
        language,
        extent_code,
        amendment_count,
        modification_count,
        commencement_count,
        extent_count,
        editorial_count,
        embedding,
        embedding_model,
        embedded_at,
        token_ids,
        tokenizer_model,
        legacy_id,
        created_at,
        updated_at,
        law_id,
        drrp_types,
        governed_actors,
        government_actors,
        duty_family,
        duty_sub_type,
        clause_refined,
        purposes,
        popimar,
        taxa_confidence,
        taxa_enriched_at,
        actors,
        extraction_method,
        holder_inferred_from,
        ancestor_distance,
        significance_scope_duty_bearer,
        significance_scope_protected_class,
        significance_gravity,
        significance_strength,
        significance_hierarchy,
        significance_confidence,
        significance_overall,
        sub_provision,
        status,
        effective_from,
        changed_by,
        title,
        repealed_extent
       FROM legal_articles_uk;
    """)
  end
end
