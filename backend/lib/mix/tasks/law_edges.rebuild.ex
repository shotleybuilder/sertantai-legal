defmodule Mix.Tasks.LawEdges.Rebuild do
  @shortdoc "Rebuild the law_edges table from linked_* arrays on uk_lrt"

  @moduledoc """
  Extracts relationship edges from uk_lrt linked_* arrays into the
  materialised `law_edges` table. Re-runnable (truncates then inserts).

  ## Usage

      mix law_edges.rebuild

  ## Edge Types

  | Source Array | Edge Type | Direction |
  |-------------|-----------|-----------|
  | linked_amending | amends | source amends target |
  | linked_amended_by | amended_by | source is amended by target |
  | linked_rescinding | rescinds | source rescinds target |
  | linked_rescinded_by | rescinded_by | source is rescinded by target |
  | linked_enacted_by | enacted_by | source is enacted by target |
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  @edge_sources [
    {"linked_amending", "amends"},
    {"linked_amended_by", "amended_by"},
    {"linked_rescinding", "rescinds"},
    {"linked_rescinded_by", "rescinded_by"},
    {"linked_enacted_by", "enacted_by"}
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    Mix.shell().info("Rebuilding law_edges table...")

    # Truncate
    Repo.query!("TRUNCATE law_edges")

    # Build a name→family lookup for all laws
    {:ok, %{rows: family_rows}} =
      Repo.query("SELECT name, family FROM uk_lrt WHERE name IS NOT NULL")

    family_map = Map.new(family_rows, fn [name, family] -> {name, family} end)

    total = 0

    total =
      Enum.reduce(@edge_sources, total, fn {column, edge_type}, acc ->
        count = insert_edges(column, edge_type, family_map)
        Mix.shell().info("  #{edge_type}: #{format_number(count)} edges")
        acc + count
      end)

    Mix.shell().info("\nTotal: #{format_number(total)} edges inserted")

    # Verify
    {:ok, %{rows: [[db_count]]}} = Repo.query("SELECT COUNT(*) FROM law_edges")
    Mix.shell().info("Verified: #{format_number(db_count)} rows in law_edges")

    # Derive enacted_si_codes for Acts
    Mix.shell().info("\nDeriving enacted_si_codes for parent Acts...")
    enacted_count = derive_enacted_si_codes()
    Mix.shell().info("Updated #{format_number(enacted_count)} Acts with enacted_si_codes")
  end

  # Aggregate si_codes from enacted child laws into the parent Act.
  # Produces a JSONB frequency map: {"HEALTH AND SAFETY": 45, "FIRE": 12}
  defp derive_enacted_si_codes do
    sql = """
    UPDATE uk_lrt parent SET enacted_si_codes = derived.codes
    FROM (
      SELECT
        e.target_law AS law_name,
        jsonb_object_agg(code, cnt) AS codes
      FROM law_edges e
      JOIN uk_lrt child ON child.name = e.source_law
      CROSS JOIN LATERAL (
        SELECT value AS code, COUNT(*) AS cnt
        FROM jsonb_array_elements_text(child.si_code->'values') AS value
        GROUP BY value
      ) codes
      WHERE e.edge_type = 'enacted_by'
        AND child.si_code IS NOT NULL
        AND child.si_code != 'null'::jsonb
      GROUP BY e.target_law
    ) derived
    WHERE parent.name = derived.law_name
    """

    {:ok, result} = Repo.query(sql)
    result.num_rows
  end

  defp insert_edges(column, edge_type, family_map) do
    sql = """
    SELECT name, #{column}
    FROM uk_lrt
    WHERE #{column} IS NOT NULL AND array_length(#{column}, 1) > 0
    """

    {:ok, %{rows: rows}} = Repo.query(sql)

    edges =
      rows
      |> Enum.flat_map(fn [source_law, targets] ->
        targets
        |> Enum.map(fn target_law ->
          [
            source_law,
            target_law,
            edge_type,
            Map.get(family_map, source_law),
            Map.get(family_map, target_law)
          ]
        end)
      end)

    # Batch insert (1000 at a time)
    edges
    |> Enum.chunk_every(1000)
    |> Enum.each(fn batch ->
      placeholders =
        batch
        |> Enum.with_index()
        |> Enum.map(fn {_, i} ->
          base = i * 5
          "($#{base + 1}, $#{base + 2}, $#{base + 3}, $#{base + 4}, $#{base + 5})"
        end)
        |> Enum.join(", ")

      params = List.flatten(batch)

      Repo.query!(
        "INSERT INTO law_edges (source_law, target_law, edge_type, source_family, target_family) VALUES #{placeholders} ON CONFLICT DO NOTHING",
        params
      )
    end)

    length(edges)
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
  end
end
