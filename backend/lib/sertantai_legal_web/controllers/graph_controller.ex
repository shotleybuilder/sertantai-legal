defmodule SertantaiLegalWeb.GraphController do
  @moduledoc """
  Admin endpoints for graph-informed family inference and law relationships.

  ## Endpoints

    - `GET /api/graph/stats` — Summary statistics for edge table + mismatches
    - `GET /api/graph/family-mismatches` — Laws where graph suggests different family
    - `GET /api/graph/family-inference/:law_name` — Detailed inference for one law
  """

  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Legal.{FamilyInference, FamilyRules}
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
    u.id::text AS law_id,
    u.title_en AS title,
    u.si_code,
    u.md_description,
    u.family AS assigned_family,
    u.family_ii,
    e.target_law AS parent_law,
    p.id::text AS parent_id,
    p.title_en AS parent_title,
    p.enacted_si_codes,
    p.enacted_families,
    p.family AS parent_family,
    p.family_ii AS parent_family_ii
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt p ON p.name = e.target_law
  WHERE e.edge_type = 'enacted_by'
    AND u.family IS NOT NULL
    AND u.family != '🖤 X: No Family'
    AND u.family != '_todo'
    AND p.family IS NOT NULL
    AND p.family != '🖤 X: No Family'
    AND p.family != '_todo'
    AND u.family != p.family
    AND split_part(u.family, ':', 1) != split_part(p.family, ':', 1)
  ORDER BY e.source_law
  """

  # ── Amends: target consensus mismatches ─────────────────────────

  @amends_sql """
  SELECT
    e.source_law AS law_name,
    u.family AS assigned_family,
    t.family AS target_family,
    COUNT(*) AS edge_count
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt t ON t.name = e.target_law
  WHERE e.edge_type = 'amends'
    AND u.family IS NOT NULL
    AND u.family != '🖤 X: No Family'
    AND u.family != '_todo'
    AND t.family IS NOT NULL
    AND t.family != '🖤 X: No Family'
    AND t.family != '_todo'
    AND u.family != t.family
    AND split_part(u.family, ':', 1) != split_part(t.family, ':', 1)
  GROUP BY e.source_law, u.family, t.family
  ORDER BY e.source_law, edge_count DESC
  """

  # ── Rescinds: replacement family mismatches ─────────────────────

  @rescinds_sql """
  SELECT
    e.source_law AS law_name,
    u.title_en AS title,
    u.family AS assigned_family,
    e.target_law AS rescinded_law,
    p.title_en AS rescinded_title,
    p.family AS rescinded_family
  FROM law_edges e
  JOIN uk_lrt u ON u.name = e.source_law
  JOIN uk_lrt p ON p.name = e.target_law
  WHERE e.edge_type = 'rescinds'
    AND u.family IS NOT NULL
    AND u.family != '🖤 X: No Family'
    AND u.family != '_todo'
    AND p.family IS NOT NULL
    AND p.family != '🖤 X: No Family'
    AND p.family != '_todo'
    AND u.family != p.family
    AND split_part(u.family, ':', 1) != split_part(p.family, ':', 1)
  ORDER BY e.source_law
  """

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
          law_id: r["law_id"],
          title: r["title"],
          si_code: si_values,
          md_description: r["md_description"],
          assigned_family: r["assigned_family"],
          family_ii: r["family_ii"],
          parent_law: r["parent_law"],
          parent_id: r["parent_id"],
          parent_title: r["parent_title"],
          parent_enacted_si_codes: r["enacted_si_codes"] || %{},
          parent_enacted_families: r["enacted_families"] || %{},
          parent_family: r["parent_family"],
          parent_family_ii: r["parent_family_ii"],
          title_confirmed: FamilyRules.title_confirms_family?(r["title"], r["assigned_family"])
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

  @doc """
  Synchronous LRT rescrape — runs all 5 stages and persists the result.
  Stays on the current page (no SSE streaming, no navigation).
  """
  def rescrape_lrt(conn, %{"law_name" => law_name}) do
    alias SertantaiLegal.Scraper.{StagedParser, Persister}

    # Look up the law by name
    case Repo.query(
           "SELECT type_code, year, number, title_en, name FROM uk_lrt WHERE name = $1",
           [law_name]
         ) do
      {:ok, %{rows: [[type_code, year, number, title_en, name]]}} ->
        input = %{
          type_code: type_code,
          Year: year,
          Number: to_string(number),
          Title_EN: title_en,
          name: name
        }

        t0 = System.monotonic_time(:millisecond)

        case StagedParser.parse(input) do
          {:ok, result} ->
            t1 = System.monotonic_time(:millisecond)
            # Convert ParsedLaw struct to plain map — Persister uses Access (record[key])
            raw_law = Map.get(result, :law) || Map.get(result, :record)

            parsed_law =
              if is_struct(raw_law), do: Map.from_struct(raw_law), else: raw_law

            case Persister.persist_record(parsed_law) do
              {:ok, _} ->
                stage_statuses =
                  result
                  |> Map.get(:stages, %{})
                  |> Map.new(fn {stage, data} ->
                    {stage, if(is_map(data), do: Map.get(data, :status, :unknown), else: data)}
                  end)

                json(conn, %{
                  law_name: law_name,
                  status: if(Map.get(result, :has_errors, false), do: "partial", else: "ok"),
                  stages: stage_statuses,
                  duration_ms: t1 - t0
                })

              {:error, reason} ->
                conn
                |> put_status(:unprocessable_entity)
                |> json(%{error: "Persist failed: #{inspect(reason)}"})
            end

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{error: "Parse failed: #{inspect(reason)}"})
        end

      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Law not found: #{law_name}"})
    end
  end
end
