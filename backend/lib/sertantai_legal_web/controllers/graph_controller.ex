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

    # Staleness: count uk_lrt records modified after the most recent law_edges rebuild.
    # law_edges has no timestamp, so we use the max updated_at across all source laws
    # that contribute edges vs the max updated_at across laws already in law_edges.
    {:ok, %{rows: [[stale_count]]}} =
      Repo.query("""
      SELECT COUNT(*)
      FROM uk_lrt u
      WHERE u.updated_at > (
        SELECT COALESCE(MAX(u2.updated_at), '1970-01-01')
        FROM law_edges e
        JOIN uk_lrt u2 ON u2.name = e.source_law
        WHERE e.edge_type = 'enacted_by'
      )
      AND (
        u.enacted_by IS NOT NULL AND array_length(u.enacted_by, 1) > 0
        OR u.amending IS NOT NULL AND array_length(u.amending, 1) > 0
        OR u.amended_by IS NOT NULL AND array_length(u.amended_by, 1) > 0
        OR u.rescinding IS NOT NULL AND array_length(u.rescinding, 1) > 0
        OR u.rescinded_by IS NOT NULL AND array_length(u.rescinded_by, 1) > 0
      )
      """)

    json(conn, %{
      total_edges: edge_count,
      edge_types: edge_types,
      laws_with_edges: inference_stats["laws_with_edges"],
      laws_with_classified_parents: inference_stats["laws_with_classified_parents"],
      potential_mismatches: inference_stats["potential_mismatches"],
      stale_count: stale_count
    })
  end

  # ── Enacted By: all enacted_by edges with QA signals ──────────────

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
    AND t.family IS NOT NULL
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
    AND p.family IS NOT NULL
    AND u.family != p.family
    AND split_part(u.family, ':', 1) != split_part(p.family, ':', 1)
  ORDER BY e.source_law
  """

  # Load si_code → compatible families from derived table (refreshed by mix law_edges.rebuild)
  defp load_si_code_families do
    case Repo.query("SELECT si_code, family FROM si_code_families") do
      {:ok, %{rows: rows}} ->
        Enum.group_by(rows, fn [code, _] -> code end, fn [_, fam] -> fam end)

      _ ->
        %{}
    end
  end

  defp parent_type(name) when is_binary(name) do
    cond do
      name =~ ~r/_ukpga_|_ukla_|_asp_|_anaw_|_nia_|_apni_|_aep_/ -> "act"
      name =~ ~r/_nisi_/ -> "ni_order"
      name =~ ~r/_uksi_|_ssi_|_wsi_|_nisr_|_ukdsi_/ -> "si"
      true -> "other"
    end
  end

  defp parent_type(_), do: "other"

  defp compute_outlier(assigned_family, enacted_families)
       when is_binary(assigned_family) and is_map(enacted_families) and
              map_size(enacted_families) > 0 do
    total = enacted_families |> Map.values() |> Enum.sum()
    count = Map.get(enacted_families, assigned_family, 0)
    pct = if total > 0, do: Float.round(count / total * 100, 1), else: 0.0
    {pct < 5.0 and count > 0, pct}
  end

  defp compute_outlier(_, _), do: {false, 0.0}

  def family_mismatches(conn, %{"type" => "enacted_by"}) do
    {:ok, %{columns: cols, rows: rows}} = Repo.query(@enacted_by_sql)
    si_code_map = load_si_code_families()

    items =
      rows
      |> Enum.map(fn row -> Enum.zip(cols, row) |> Map.new() end)
      |> Enum.map(fn r ->
        si_values =
          case r["si_code"] do
            %{"values" => v} when is_list(v) -> v
            _ -> []
          end

        assigned = r["assigned_family"]
        enacted_fams = r["enacted_families"] || %{}
        p_type = parent_type(r["parent_law"])

        # SI code cross-validation: check if assigned family is in the
        # si_code_families compatible list (derived from corpus data)
        compatible_families =
          si_values
          |> Enum.flat_map(fn code -> Map.get(si_code_map, code, []) end)
          |> Enum.uniq()

        si_code_family =
          if compatible_families != [], do: hd(compatible_families), else: nil

        si_code_mismatch =
          compatible_families != [] and assigned != nil and
            assigned not in compatible_families

        # Outlier detection: child's family % within parent's enacted_families
        {outlier, outlier_pct} = compute_outlier(assigned, enacted_fams)

        %{
          law_name: r["law_name"],
          law_id: r["law_id"],
          title: r["title"],
          si_code: si_values,
          md_description: r["md_description"],
          assigned_family: assigned,
          family_ii: r["family_ii"],
          parent_law: r["parent_law"],
          parent_id: r["parent_id"],
          parent_title: r["parent_title"],
          parent_enacted_si_codes: r["enacted_si_codes"] || %{},
          parent_enacted_families: enacted_fams,
          parent_family: r["parent_family"],
          parent_family_ii: r["parent_family_ii"],
          title_confirmed: FamilyRules.title_confirms_family?(r["title"], assigned),
          si_code_family: si_code_family,
          si_code_mismatch: si_code_mismatch,
          outlier: outlier,
          outlier_pct: outlier_pct,
          parent_type: p_type,
          si_enacts_si: p_type == "si"
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

  @count_base "SELECT COUNT(DISTINCT source_law) FROM law_edges WHERE source_family IS NOT NULL AND target_family IS NOT NULL AND source_family != target_family AND split_part(source_family, ':', 1) != split_part(target_family, ':', 1)"

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
  Rebuild the law_edges table and derived data (enacted_si_codes, enacted_families, si_code_families).
  Equivalent to running `mix law_edges.rebuild` from the admin UI.
  """
  def rebuild_edges(conn, _params) do
    t0 = System.monotonic_time(:millisecond)
    Mix.Task.rerun("law_edges.rebuild")
    t1 = System.monotonic_time(:millisecond)

    {:ok, %{rows: [[edge_count]]}} = Repo.query("SELECT COUNT(*) FROM law_edges")

    json(conn, %{
      status: "ok",
      total_edges: edge_count,
      duration_ms: t1 - t0
    })
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
