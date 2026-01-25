defmodule SertantaiLegal.Repo.Migrations.FixStatsJsonbAffectParsing do
  @moduledoc """
  Fix migration to properly parse 'affect' from combined 'target' field.

  Uses pure SQL set-based operations for performance.
  """

  use Ecto.Migration

  @fields [
    "🔺_affects_stats_per_law",
    "🔺_rescinding_stats_per_law",
    "🔻_affected_by_stats_per_law",
    "🔻_rescinded_by_stats_per_law"
  ]

  # Affect keywords pattern for PostgreSQL regex
  @affect_pattern ~S"((?:words?\s+)?(?:substituted|inserted|omitted|added|repealed|revoked)|(?:entry\s+)?(?:substituted|inserted|omitted)|applied(?:\s*\([^)]+\))?|amended|modified|restricted|extended|excluded|repealed|revoked|ceased|expired|superseded|coming\s+into\s+force|am(?:\s*\([^)]+\))?)"

  def up do
    for field <- @fields do
      # This approach:
      # 1. Unnests the JSONB into rows (one per law entry)
      # 2. Unnests details array
      # 3. Applies regex to split target/affect
      # 4. Reaggregates back to JSONB
      execute(build_update_sql(field))
    end
  end

  def down do
    :ok
  end

  defp build_update_sql(field) do
    """
    WITH exploded AS (
      -- Explode JSONB into rows: one row per detail entry
      SELECT
        u.id,
        law.key as law_key,
        law.value as law_value,
        idx - 1 as detail_idx,
        detail
      FROM uk_lrt u,
        LATERAL jsonb_each(u."#{field}") AS law(key, value),
        LATERAL jsonb_array_elements(law.value->'details') WITH ORDINALITY AS d(detail, idx)
      WHERE u."#{field}" IS NOT NULL
    ),
    fixed_details AS (
      -- Apply regex to extract affect from target
      SELECT
        id,
        law_key,
        law_value,
        detail_idx,
        CASE
          WHEN detail->>'affect' IS NOT NULL THEN detail
          WHEN (regexp_match(detail->>'target', '^(.+?)\\s+#{@affect_pattern}\\s*$', 'i')) IS NOT NULL THEN
            jsonb_build_object(
              'target', trim((regexp_match(detail->>'target', '^(.+?)\\s+#{@affect_pattern}\\s*$', 'i'))[1]),
              'affect', trim((regexp_match(detail->>'target', '^(.+?)\\s+#{@affect_pattern}\\s*$', 'i'))[2]),
              'applied', detail->>'applied'
            )
          ELSE detail
        END as fixed_detail
      FROM exploded
    ),
    reaggregated_details AS (
      -- Reaggregate details back into arrays per law
      SELECT
        id,
        law_key,
        law_value,
        jsonb_agg(fixed_detail ORDER BY detail_idx) as details_array
      FROM fixed_details
      GROUP BY id, law_key, law_value
    ),
    rebuilt_laws AS (
      -- Rebuild law entries with fixed details
      SELECT
        id,
        jsonb_object_agg(
          law_key,
          jsonb_set(law_value, '{details}', details_array)
        ) as new_field
      FROM reaggregated_details
      GROUP BY id
    )
    UPDATE uk_lrt u
    SET "#{field}" = r.new_field
    FROM rebuilt_laws r
    WHERE u.id = r.id;
    """
  end
end
