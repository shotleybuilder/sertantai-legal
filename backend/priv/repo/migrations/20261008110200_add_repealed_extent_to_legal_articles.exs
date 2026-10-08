defmodule SertantaiLegal.Repo.Migrations.AddRepealedExtentToLegalArticles do
  @moduledoc """
  Retained repeals (LAT parser coverage II): legal_articles.repealed_extent
  holds the territories where a row's text is repealed but kept (Repeal
  RetainText) — e.g. "S" for a provision revoked in Scotland, live in England
  and Wales; the row's whole extent = repealed_saved. Appended to the `lat`
  view (LatPersister inserts through it; see 20260925160400). Not part of
  lat_hash / struct_hash.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE legal_articles ADD COLUMN repealed_extent text")

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
        status,
        effective_from,
        changed_by,
        title,
        repealed_extent
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
        sub_provision,
        status,
        effective_from,
        changed_by,
        title
       FROM legal_articles_uk;
    """)

    execute("ALTER TABLE legal_articles DROP COLUMN repealed_extent")
  end
end
