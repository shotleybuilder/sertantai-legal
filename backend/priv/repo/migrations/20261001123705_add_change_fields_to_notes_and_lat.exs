defmodule SertantaiLegal.Repo.Migrations.AddChangeFieldsToNotesAndLat do
  @moduledoc """
  Structured amendment notes (#167, L8.2), parsed by `AmendmentNote`:

  - amendment_annotations: effect, effective_dates (date[]), effective_from,
    changed_by (law name of the amending instrument), change_id (stable hash of
    law + normalised note; indexed for the L8.5 change log)
  - legal_articles: effective_from + changed_by per row (the latest dated
    amendment/commencement note on the row or an ancestor), appended to the
    `lat` view (LatPersister inserts through it; see 20260925160400)

  Not part of lat_hash / struct_hash.
  """

  use Ecto.Migration

  def up do
    alter table(:amendment_annotations) do
      add :effect, :text
      add :effective_dates, {:array, :date}
      add :effective_from, :date
      add :changed_by, :text
      add :change_id, :text
    end

    create index(:amendment_annotations, [:change_id])

    execute("ALTER TABLE legal_articles ADD COLUMN effective_from date")
    execute("ALTER TABLE legal_articles ADD COLUMN changed_by text")

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
        changed_by
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
        status
       FROM legal_articles_uk;
    """)

    execute("ALTER TABLE legal_articles DROP COLUMN changed_by")
    execute("ALTER TABLE legal_articles DROP COLUMN effective_from")

    drop index(:amendment_annotations, [:change_id])

    alter table(:amendment_annotations) do
      remove :change_id
      remove :changed_by
      remove :effective_from
      remove :effective_dates
      remove :effect
    end
  end
end
