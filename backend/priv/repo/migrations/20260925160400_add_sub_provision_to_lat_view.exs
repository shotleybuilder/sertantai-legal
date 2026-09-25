defmodule SertantaiLegal.Repo.Migrations.AddSubProvisionToLatView do
  @moduledoc """
  Add `sub_provision` to the `lat` compatibility view.

  20260812203258 added `sub_provision` to `legal_articles` but not to the `lat`
  view. LatPersister inserts through `lat`, so every LAT persist has failed
  since (ERROR 42703 column "sub_provision" of relation "lat" does not exist).
  Found by the LAT-parse API pilot (2026-09-25).

  `lat` is a simple auto-updatable view over `legal_articles_uk` (no INSTEAD OF
  triggers), so CREATE OR REPLACE VIEW can append the column.
  """

  use Ecto.Migration

  def up do
    execute("""
    CREATE OR REPLACE VIEW lat AS
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
        sub_provision
       FROM legal_articles_uk
    """)
  end

  def down do
    execute("DROP VIEW lat")

    execute("""
    CREATE OR REPLACE VIEW lat AS
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
        significance_overall
       FROM legal_articles_uk
    """)
  end
end
