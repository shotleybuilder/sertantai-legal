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

  def family_mismatches(conn, params) do
    limit = min(String.to_integer(params["limit"] || "100"), 500)

    mismatches =
      FamilyInference.find_mismatches()
      |> Enum.take(limit)
      |> Enum.map(fn m ->
        %{
          law_name: m.law_name,
          assigned_family: m.assigned_family,
          suggested_family: m.suggested_family,
          confidence: m.confidence,
          parent_families: m.parent_families,
          target_families: m.target_families
        }
      end)

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
