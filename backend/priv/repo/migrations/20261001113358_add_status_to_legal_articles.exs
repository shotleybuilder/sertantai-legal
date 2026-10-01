defmodule SertantaiLegal.Repo.Migrations.AddStatusToLegalArticles do
  @moduledoc """
  Per-row legal status of LAT rows (#167, L8.1): in_force | in_force_partial |
  repealed | repealed_saved | prospective. NULL = not yet computed (fractalaw
  falls back to today's behaviour).

  Added on the partitioned parent (partitions inherit) and appended to the
  `lat` view, which LatPersister inserts through (a simple auto-updatable view,
  so CREATE OR REPLACE can append; see 20260925160400). Not part of lat_hash /
  struct_hash; the manifest's status_hash carries it.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE legal_articles ADD COLUMN status text")

    execute("""
    ALTER TABLE legal_articles ADD CONSTRAINT legal_articles_status_check
      CHECK (status IS NULL OR status IN
        ('in_force', 'in_force_partial', 'repealed', 'repealed_saved', 'prospective'))
    """)

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
        sub_provision,
        status
       FROM legal_articles_uk;
    """)
  end

  def down do
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
        sub_provision
       FROM legal_articles_uk;
    """)

    execute("ALTER TABLE legal_articles DROP CONSTRAINT legal_articles_status_check")
    execute("ALTER TABLE legal_articles DROP COLUMN status")
  end
end
