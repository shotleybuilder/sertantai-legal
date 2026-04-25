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

  # ── Enacted By: parent family mismatches ──────────────────────────

  @enacted_by_sql """
  SELECT
    e.source_law AS law_name,
    u.title_en AS title,
    u.si_code,
    e.source_family AS assigned_family,
    e.target_law AS parent_law,
    p.title_en AS parent_title,
    e.target_family AS parent_family
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt p ON p.name = e.target_law
  WHERE e.edge_type = 'enacted_by'
    AND e.source_family IS NOT NULL
    AND e.source_family != '🖤 X: No Family'
    AND e.source_family != '_todo'
    AND e.target_family IS NOT NULL
    AND e.target_family != '🖤 X: No Family'
    AND e.target_family != '_todo'
    AND e.source_family != e.target_family
    AND split_part(e.source_family, ':', 1) != split_part(e.target_family, ':', 1)
  ORDER BY e.source_law
  """

  # ── Amends: target consensus mismatches ─────────────────────────

  @amends_sql """
  SELECT
    e.source_law AS law_name,
    e.source_family AS assigned_family,
    e.target_family,
    COUNT(*) AS edge_count
  FROM law_edges e
  WHERE e.edge_type = 'amends'
    AND e.source_family IS NOT NULL
    AND e.source_family != '🖤 X: No Family'
    AND e.source_family != '_todo'
    AND e.target_family IS NOT NULL
    AND e.target_family != '🖤 X: No Family'
    AND e.target_family != '_todo'
    AND e.source_family != e.target_family
    AND split_part(e.source_family, ':', 1) != split_part(e.target_family, ':', 1)
  GROUP BY e.source_law, e.source_family, e.target_family
  ORDER BY e.source_law, edge_count DESC
  """

  # ── Rescinds: replacement family mismatches ─────────────────────

  @rescinds_sql """
  SELECT
    e.source_law AS law_name,
    u.title_en AS title,
    e.source_family AS assigned_family,
    e.target_law AS rescinded_law,
    p.title_en AS rescinded_title,
    e.target_family AS rescinded_family
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt p ON p.name = e.target_law
  WHERE e.edge_type = 'rescinds'
    AND e.source_family IS NOT NULL
    AND e.source_family != '🖤 X: No Family'
    AND e.source_family != '_todo'
    AND e.target_family IS NOT NULL
    AND e.target_family != '🖤 X: No Family'
    AND e.target_family != '_todo'
    AND e.source_family != e.target_family
    AND split_part(e.source_family, ':', 1) != split_part(e.target_family, ':', 1)
  ORDER BY e.source_law
  """

  # Family → title keywords that confirm the assignment is correct.
  # If the law's title contains these keywords AND the family matches,
  # the mismatch is noise (law is correctly classified, parent is just different).
  @title_confirms %{
    "💚 GMOs" => ["genetically modified"],
    "💙 FIRE" => ["fire"],
    "💙 FIRE: Dangerous and Explosive Substances" => [
      "explosive",
      "petroleum",
      "dangerous substance"
    ],
    "💚 CLIMATE CHANGE" => ["climate change", "greenhouse gas", "carbon"],
    "💙 HEALTH: Coronavirus" => ["coronavirus", "covid"],
    "💙 HEALTH: Drug & Medicine Safety" => ["medicine", "pharmaceutical", "drug"],
    "💙 HEALTH: Patient Safety" => ["patient safety", "medical device"],
    "💙 HEALTH: Public" => ["public health"],
    "💙 OH&S: Gas & Electrical Safety" => ["gas safety", "electrical safety", "electricity"],
    "💙 OH&S: Mines & Quarries" => ["mines", "quarries"],
    "💙 OH&S: Occupational / Personal Safety" => ["health and safety", "workplace"],
    "💙 OH&S: Offshore Safety" => ["offshore"],
    "💙 PUBLIC: Building Safety" => ["building"],
    "💙 PUBLIC: Consumer / Product Safety" => ["consumer", "product safety"],
    "💙 TRANSPORT: Air Safety" => ["aviation", "air navigation", "aircraft"],
    "💙 TRANSPORT: Rail Safety" => ["railway", "rail"],
    "💙 TRANSPORT: Road Safety" => ["road traffic", "motor vehicle", "road safety"],
    "💙 TRANSPORT: Maritime Safety" => ["merchant shipping", "maritime"],
    "💚 AGRICULTURE" => ["agriculture", "agricultural"],
    "💚 AGRICULTURE: Pesticides" => ["pesticide"],
    "💚 AIR QUALITY" => ["air quality", "clean air", "emission"],
    "💚 ANIMALS & ANIMAL HEALTH" => ["animal health", "animal welfare"],
    "💚 BUILDINGS" => ["building regulation"],
    "💚 ENERGY" => ["energy efficiency", "renewable energy"],
    "💚 ENVIRONMENTAL PROTECTION" => ["environmental protection", "environment act"],
    "💚 FISHERIES & FISHING" => ["fisheries", "fishing", "sea fish"],
    "💚 MARINE & RIVERINE" => ["marine", "coastal"],
    "💚 NOISE" => ["noise"],
    "💚 NUCLEAR & RADIOLOGICAL" => ["nuclear", "radioactive", "radiological"],
    "💚 PLANNING & INFRASTRUCTURE" => ["planning", "infrastructure"],
    "💚 PLANT HEALTH" => ["plant health"],
    "💚 POLLUTION" => ["pollution", "contaminated land"],
    "💚 WASTE" => ["waste"],
    "💚 WATER & WASTEWATER" => ["water supply", "water industry", "wastewater", "sewerage"],
    "💚 WILDLIFE & COUNTRYSIDE" => ["wildlife", "countryside", "conservation"],
    "💜 HR: Employment" => ["employment"],
    "💜 HR: Working Time" => ["working time"]
  }

  defp title_confirms_family?(nil, _family), do: false
  defp title_confirms_family?(_title, nil), do: false

  defp title_confirms_family?(title, family) do
    keywords = Map.get(@title_confirms, family, [])
    lower_title = String.downcase(title)
    Enum.any?(keywords, fn kw -> String.contains?(lower_title, kw) end)
  end

  def family_mismatches(conn, %{"type" => "enacted_by"}) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@enacted_by_sql)

    items =
      rows
      |> Enum.map(fn row -> Enum.zip(cols, row) |> Map.new() end)
      |> Enum.map(fn r ->
        si_values =
          case r["si_code"] do
            %{"values" => v} when is_list(v) -> v
            _ -> []
          end

        %{
          law_name: r["law_name"],
          title: r["title"],
          si_code: si_values,
          assigned_family: r["assigned_family"],
          parent_law: r["parent_law"],
          parent_title: r["parent_title"],
          parent_family: r["parent_family"],
          title_confirmed: title_confirms_family?(r["title"], r["assigned_family"])
        }
      end)

    json(conn, %{items: items, count: length(items)})
  end

  def family_mismatches(conn, %{"type" => "amends"}) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@amends_sql)

    # Group by law, compute consensus
    items =
      rows
      |> Enum.map(fn row -> Enum.zip(cols, row) |> Map.new() end)
      |> Enum.group_by(& &1["law_name"])
      |> Enum.map(fn {law_name, edges} ->
        assigned = hd(edges)["assigned_family"]
        total_edges = edges |> Enum.map(& &1["edge_count"]) |> Enum.sum()

        target_families =
          Enum.map(edges, fn e ->
            %{family: e["target_family"], count: e["edge_count"]}
          end)

        top = hd(target_families)

        consensus_pct =
          if total_edges > 0, do: Float.round(top.count / total_edges * 100, 0), else: 0

        %{
          law_name: law_name,
          assigned_family: assigned,
          suggested_family: top.family,
          consensus_pct: consensus_pct,
          total_amends: total_edges,
          target_families: target_families
        }
      end)
      |> Enum.sort_by(& &1.consensus_pct, :desc)

    json(conn, %{items: items, count: length(items)})
  end

  def family_mismatches(conn, %{"type" => "rescinds"}) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@rescinds_sql)

    items =
      rows
      |> Enum.map(fn row -> Enum.zip(cols, row) |> Map.new() end)
      |> Enum.map(fn r ->
        %{
          law_name: r["law_name"],
          title: r["title"],
          assigned_family: r["assigned_family"],
          rescinded_law: r["rescinded_law"],
          rescinded_title: r["rescinded_title"],
          rescinded_family: r["rescinded_family"]
        }
      end)

    json(conn, %{items: items, count: length(items)})
  end

  @count_base "SELECT COUNT(DISTINCT source_law) FROM law_edges WHERE source_family != target_family AND source_family NOT IN ('🖤 X: No Family', '_todo') AND target_family NOT IN ('🖤 X: No Family', '_todo') AND split_part(source_family, ':', 1) != split_part(target_family, ':', 1)"

  def family_mismatches(conn, _params) do
    {:ok, %{rows: [[enacted]]}} =
      Repo.query(@count_base <> " AND edge_type = 'enacted_by'")

    {:ok, %{rows: [[amends]]}} =
      Repo.query(@count_base <> " AND edge_type = 'amends'")

    {:ok, %{rows: [[rescinds]]}} =
      Repo.query(@count_base <> " AND edge_type = 'rescinds'")

    json(conn, %{enacted_by: enacted, amends: amends, rescinds: rescinds})
  end

  def family_inference(conn, %{"law_name" => law_name}) do
    inference = FamilyInference.infer(law_name)
    json(conn, inference)
  end
end
