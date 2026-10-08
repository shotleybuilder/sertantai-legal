defmodule SertantaiLegal.Repo.Migrations.AddTitleToLegalArticles do
  @moduledoc """
  Provision headings (LAT parser coverage II): legal_articles.title holds a
  P1group's Title on its section/regulation row(s), and Part, Chapter,
  Schedule and cross-heading rows' own titles. Row text is unchanged.

  Added on the partitioned parent (partitions inherit) and appended to the
  `lat` view, which LatPersister inserts through (see 20260925160400). Not
  part of lat_hash / struct_hash.
  """

  use Ecto.Migration

  def up do
    execute("ALTER TABLE legal_articles ADD COLUMN title text")

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
        title
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
        changed_by
       FROM legal_articles_uk;
    """)

    execute("ALTER TABLE legal_articles DROP COLUMN title")
  end
end
