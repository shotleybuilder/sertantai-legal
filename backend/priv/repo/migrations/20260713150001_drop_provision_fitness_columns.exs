defmodule SertantaiLegal.Repo.Migrations.DropProvisionFitnessColumns do
  @moduledoc """
  Drop legacy fitness P-dimension columns from legal_articles (provision level).
  Fractalaw no longer publishes these per-provision.
  Recreates the `lat` view (simple view, no triggers).
  """
  use Ecto.Migration

  def up do
    # 1. Drop lat view (simple view, no triggers)
    execute("DROP VIEW IF EXISTS lat")

    # 2. Drop legacy columns from parent table
    alter table(:legal_articles) do
      remove :fitness_polarity
      remove :fitness_person
      remove :fitness_process
      remove :fitness_place
      remove :fitness_plant
      remove :fitness_property
      remove :fitness_sector
    end

    # 3. Recreate lat view without fitness columns
    execute("""
    CREATE VIEW lat AS
    SELECT
      section_id, country, law_name, sort_key, position, section_type,
      hierarchy_path, depth,
      part, chapter, heading_group, provision, paragraph, sub_paragraph, schedule,
      text, language, extent_code,
      amendment_count, modification_count, commencement_count,
      extent_count, editorial_count,
      embedding, embedding_model, embedded_at,
      token_ids, tokenizer_model,
      legacy_id, created_at, updated_at, law_id,
      drrp_types, governed_actors, government_actors,
      duty_family, duty_sub_type, clause_refined, purposes, popimar,
      taxa_confidence, taxa_enriched_at,
      actors, extraction_method, holder_inferred_from, ancestor_distance,
      significance_scope_duty_bearer, significance_scope_protected_class,
      significance_gravity, significance_strength, significance_hierarchy,
      significance_confidence, significance_overall
    FROM legal_articles_uk
    """)
  end

  def down do
    execute("DROP VIEW IF EXISTS lat")

    alter table(:legal_articles) do
      add :fitness_polarity, {:array, :text}
      add :fitness_person, {:array, :text}
      add :fitness_process, {:array, :text}
      add :fitness_place, {:array, :text}
      add :fitness_plant, {:array, :text}
      add :fitness_property, {:array, :text}
      add :fitness_sector, {:array, :text}
    end

    # Recreate view with fitness columns — omitted for brevity
  end
end
