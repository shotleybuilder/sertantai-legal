defmodule SertantaiLegalWeb.GraphController do
  @moduledoc """
  Admin endpoints for graph-informed family inference and law relationships.

  ## Endpoints

    - `GET /api/graph/stats` — Summary statistics for edge table + mismatches
    - `GET /api/graph/family-mismatches` — Laws where graph suggests different family
    - `GET /api/graph/family-inference/:law_name` — Detailed inference for one law
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Legal.FamilyInference
  alias SertantaiLegal.Repo

  def stats(conn, _params) do
    inference_stats = FamilyInference.summary_stats()

    {:ok, %{rows: [[edge_count]]}} = Repo.query("SELECT COUNT(*) FROM law_edges")

    {:ok, %{rows: type_rows}} =
      Repo.query(
        "SELECT edge_type, COUNT(*) FROM law_edges GROUP BY edge_type ORDER BY count DESC"
      )

    edge_types = Map.new(type_rows, fn [type, count] -> {type, count} end)

    json(conn, %{
      total_edges: edge_count,
      edge_types: edge_types,
      laws_with_edges: inference_stats["laws_with_edges"],
      laws_with_classified_parents: inference_stats["laws_with_classified_parents"],
      potential_mismatches: inference_stats["potential_mismatches"]
    })
  end

  @mismatches_sql """
  SELECT
    e.source_law AS law_name,
    e.source_family AS assigned_family,
    e.edge_type,
    e.target_family AS suggested_family,
    COUNT(*) AS edge_count
  FROM law_edges e
  WHERE e.source_family IS NOT NULL
    AND e.source_family != '🖤 X: No Family'
    AND e.source_family != '_todo'
    AND e.target_family IS NOT NULL
    AND e.target_family != '🖤 X: No Family'
    AND e.target_family != '_todo'
    AND e.source_family != e.target_family
    AND e.edge_type IN ('enacted_by', 'amends')
  GROUP BY e.source_law, e.source_family, e.edge_type, e.target_family
  ORDER BY e.source_law, edge_count DESC
  """

  def family_mismatches(conn, _params) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@mismatches_sql)

    # Group by law_name, pick the top suggested family per law
    grouped =
      rows
      |> Enum.map(fn row -> Enum.zip(cols, row) |> Map.new() end)
      |> Enum.group_by(& &1["law_name"])

    # Fetch metadata (title, si_code) for all mismatch laws in one query
    law_names = Map.keys(grouped)

    metadata =
      if law_names != [] do
        {:ok, %{rows: meta_rows}} =
          Repo.query(
            "SELECT name, title_en, si_code FROM uk_lrt WHERE name = ANY($1)",
            [law_names]
          )

        Map.new(meta_rows, fn [name, title, si_code] ->
          si_values =
            case si_code do
              %{"values" => v} when is_list(v) -> v
              _ -> []
            end

          {name, %{title: title, si_code: si_values}}
        end)
      else
        %{}
      end

    mismatches =
      grouped
      |> Enum.map(fn {law_name, edges} ->
        assigned = hd(edges)["assigned_family"]
        meta = Map.get(metadata, law_name, %{title: nil, si_code: []})

        # Group evidence by type
        parent_edges = Enum.filter(edges, &(&1["edge_type"] == "enacted_by"))
        target_edges = Enum.filter(edges, &(&1["edge_type"] == "amends"))

        parent_families =
          Enum.map(parent_edges, fn e -> [e["suggested_family"], e["edge_count"]] end)

        target_families =
          Enum.map(target_edges, fn e -> [e["suggested_family"], e["edge_count"]] end)

        # Pick suggestion: parent > target consensus
        {suggested, confidence} =
          cond do
            parent_families != [] ->
              {hd(parent_edges)["suggested_family"], "parent_inferred"}

            target_families != [] ->
              {hd(target_edges)["suggested_family"], "target_consensus"}

            true ->
              {nil, "unknown"}
          end

        %{
          law_name: law_name,
          title: meta.title,
          si_code: meta.si_code,
          assigned_family: assigned,
          suggested_family: suggested,
          confidence: confidence,
          parent_families: parent_families,
          target_families: target_families
        }
      end)
      |> Enum.sort_by(& &1.law_name)

    json(conn, %{
      mismatches: mismatches,
      count: length(mismatches),
      total: length(mismatches)
    })
  end

  def family_inference(conn, %{"law_name" => law_name}) do
    inference = FamilyInference.infer(law_name)
    json(conn, inference)
  end
end
