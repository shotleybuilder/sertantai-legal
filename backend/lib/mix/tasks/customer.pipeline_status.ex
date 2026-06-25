defmodule Mix.Tasks.Customer.PipelineStatus do
  @shortdoc "Pipeline status report for a customer's applicable law corpus"

  @moduledoc """
  Reports where a customer's applicable laws stand in the data pipeline:
  applicability, LAT parsing, taxa enrichment, fractalaw processing,
  and Baserow-ready governed duties.

  ## Usage

      mix customer.pipeline_status [options]

  ## Options

    * `--org-id UUID` — Organization UUID (defaults to QQ)
    * `--verbose` — Show per-law detail table
    * `--flags` — Show only flagged laws (issues needing attention)
    * `--help` — Show this help text

  ## Examples

      mix customer.pipeline_status
      mix customer.pipeline_status --verbose
      mix customer.pipeline_status --flags
      mix customer.pipeline_status --org-id c075d56b-8420-4408-b695-ccfbc1ba15ec
  """

  use Mix.Task

  alias SertantaiLegal.Repo

  @qq_org_id "c075d56b-8420-4408-b695-ccfbc1ba15ec"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [org_id: :string, verbose: :boolean, flags: :boolean, help: :boolean]
      )

    if opts[:help] do
      Mix.shell().info(@moduledoc)
      System.halt(0)
    end

    Mix.Task.run("app.start")

    org_id = opts[:org_id] || @qq_org_id

    info("── Pipeline Status: #{org_id} ──")
    info("")

    laws = fetch_applicable_laws(org_id)

    if laws == [] do
      info("No applicable laws found for this organization.")
      System.halt(0)
    end

    # Phase 1-2: Live status
    live_stats = classify_live_status(laws)

    # Phase 3: LAT coverage
    lat_stats = classify_lat_coverage(laws)

    # Phase 4: Taxa enrichment
    law_ids = laws |> Enum.filter(&(&1.lat_count > 0)) |> Enum.map(& &1.law_id)
    taxa_map = fetch_taxa_coverage(law_ids)

    taxa_stats = summarise_taxa(taxa_map, length(law_ids))

    # Phase 5: Governed duties
    duty_map = fetch_governed_duties(law_ids)
    total_duties = duty_map |> Map.values() |> Enum.sum()

    # Phase 6: Fractalaw status (optional)
    fractalaw_map = fetch_fractalaw_status(Enum.map(laws, & &1.law_name))

    # Print summary
    print_summary(laws, live_stats, lat_stats, taxa_stats, total_duties, fractalaw_map)

    # Enrich laws with computed fields
    enriched =
      Enum.map(laws, fn law ->
        taxa = Map.get(taxa_map, law.law_id, {0, 0})
        duties = Map.get(duty_map, law.law_id, 0)
        fl_stage = Map.get(fractalaw_map, law.law_name)

        Map.merge(law, %{
          taxa_total: elem(taxa, 0),
          taxa_enriched: elem(taxa, 1),
          duties: duties,
          fractalaw_stage: fl_stage
        })
      end)

    if opts[:verbose] do
      info("")
      print_per_law_table(enriched)
    end

    if opts[:flags] do
      info("")
      print_flags(enriched)
    end
  end

  # ── Phase 1: Fetch applicable laws ──

  defp fetch_applicable_laws(org_id) do
    {:ok, org_bin} = Ecto.UUID.dump(org_id)

    sql = """
    SELECT oa.law_name, lr.id, lr.title_en, lr.live, lr.lat_count, lr.family, lr.year
    FROM org_applicabilities oa
    JOIN legal_register lr ON lr.name = oa.law_name
    WHERE oa.organization_id = $1 AND oa.status = 'yes'
    ORDER BY lr.family NULLS LAST, lr.year, lr.name
    """

    case Repo.query(sql, [org_bin]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [law_name, id, title, live, lat_count, family, year] ->
          %{
            law_name: law_name,
            law_id: id,
            title: title || "(no title)",
            live: live,
            lat_count: lat_count || 0,
            family: family,
            year: year
          }
        end)

      {:error, reason} ->
        info("ERROR fetching laws: #{inspect(reason)}")
        []
    end
  end

  # ── Phase 2: Live status ──

  defp classify_live_status(laws) do
    Enum.reduce(laws, %{in_force: 0, part_revoked: 0, revoked: 0}, fn law, acc ->
      cond do
        is_binary(law.live) and String.contains?(law.live, "Revoked") ->
          %{acc | revoked: acc.revoked + 1}

        is_binary(law.live) and String.contains?(law.live, "Repealed") ->
          %{acc | revoked: acc.revoked + 1}

        is_binary(law.live) and String.contains?(law.live, "Abolished") ->
          %{acc | revoked: acc.revoked + 1}

        is_binary(law.live) and String.contains?(law.live, "Part") ->
          %{acc | part_revoked: acc.part_revoked + 1}

        true ->
          %{acc | in_force: acc.in_force + 1}
      end
    end)
  end

  # ── Phase 3: LAT coverage ──

  defp classify_lat_coverage(laws) do
    Enum.reduce(laws, %{parsed: 0, zero_result: 0, not_parsed: 0}, fn law, acc ->
      cond do
        law.lat_count > 0 -> %{acc | parsed: acc.parsed + 1}
        law.lat_count == 0 -> %{acc | zero_result: acc.zero_result + 1}
        true -> %{acc | not_parsed: acc.not_parsed + 1}
      end
    end)
  end

  # ── Phase 4: Taxa enrichment ──

  defp fetch_taxa_coverage(law_ids) when law_ids == [], do: %{}

  defp fetch_taxa_coverage(law_ids) do
    sql = """
    SELECT la.law_id,
           COUNT(*) as total,
           COUNT(*) FILTER (WHERE la.taxa_enriched_at IS NOT NULL) as enriched
    FROM legal_articles_uk la
    WHERE la.law_id = ANY($1) AND la.provision IS NOT NULL
    GROUP BY la.law_id
    """

    case Repo.query(sql, [law_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [law_id, total, enriched] -> {law_id, {total, enriched}} end)

      {:error, _} ->
        %{}
    end
  end

  defp summarise_taxa(taxa_map, parsed_count) do
    {fully, partially, none} =
      Enum.reduce(taxa_map, {0, 0, 0}, fn {_id, {total, enriched}}, {f, p, n} ->
        cond do
          enriched == 0 -> {f, p, n + 1}
          enriched >= total -> {f + 1, p, n}
          true -> {f, p + 1, n}
        end
      end)

    awaiting = parsed_count - map_size(taxa_map)

    %{fully: fully, partially: partially, none: none, awaiting: awaiting}
  end

  # ── Phase 5: Governed duties ──

  defp fetch_governed_duties(law_ids) when law_ids == [], do: %{}

  defp fetch_governed_duties(law_ids) do
    sql = """
    SELECT agg.law_id, COUNT(*) as duties
    FROM (
      SELECT la.law_id, la.provision,
        bool_or(a->>'position' = 'active'
          AND a->>'label' NOT LIKE 'Gvt:%'
          AND a->>'label' NOT LIKE 'EU:%') as has_gov
      FROM legal_articles_uk la
      LEFT JOIN LATERAL unnest(la.actors) a ON true
      WHERE la.law_id = ANY($1)
        AND la.provision IS NOT NULL
        AND la.drrp_types && ARRAY['Obligation']
      GROUP BY la.law_id, la.provision
    ) agg
    WHERE agg.has_gov = true
    GROUP BY agg.law_id
    """

    case Repo.query(sql, [law_ids]) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [law_id, count] -> {law_id, count} end)

      {:error, _} ->
        %{}
    end
  end

  # ── Phase 6: Fractalaw status ──

  defp fetch_fractalaw_status(law_names) do
    tenant =
      Application.get_env(:sertantai_legal, :zenoh, [])
      |> Keyword.get(:tenant, "dev")

    case SertantaiLegal.Zenoh.Session.session_id() do
      {:ok, session_id} ->
        selector = "fractalaw/@#{tenant}/status?laws=#{Enum.join(law_names, ",")}"

        case Zenohex.Session.get(session_id, selector, 10_000) do
          {:ok, [%{payload: payload} | _]} ->
            case Jason.decode(payload) do
              {:ok, statuses} when is_list(statuses) ->
                Map.new(statuses, fn s -> {s["law_name"], s["stage"]} end)

              _ ->
                %{}
            end

          _ ->
            %{}
        end

      {:error, _} ->
        %{}
    end
  end

  # ── Output: Summary ──

  defp print_summary(laws, live, lat, taxa, duties, fl_map) do
    total = length(laws)
    fl_status = if fl_map == %{}, do: "unavailable", else: "connected"

    info("  Applicable laws:       #{pad(total)}")
    info("    In-force:            #{pad(live.in_force)}   (#{pct(live.in_force, total)})")

    info(
      "    Part-revoked:        #{pad(live.part_revoked)}   (#{pct(live.part_revoked, total)})"
    )

    info("    Fully revoked:       #{pad(live.revoked)}   (#{pct(live.revoked, total)})")
    info("")
    info("  LAT coverage:")
    info("    Parsed (lat > 0):    #{pad(lat.parsed)}   (#{pct(lat.parsed, total)})")
    info("    Zero result:         #{pad(lat.zero_result)}   (#{pct(lat.zero_result, total)})")
    info("")
    info("  Taxa enrichment (of #{lat.parsed} parsed):")
    info("    Fully enriched:      #{pad(taxa.fully)}   (#{pct(taxa.fully, lat.parsed)})")
    info("    Partially enriched:  #{pad(taxa.partially)}   (#{pct(taxa.partially, lat.parsed)})")
    info("    No enrichment:       #{pad(taxa.none)}   (#{pct(taxa.none, lat.parsed)})")
    info("    Awaiting fractalaw:  #{pad(taxa.awaiting)}   (#{pct(taxa.awaiting, lat.parsed)})")
    info("")
    info("  Governed duties:       #{pad(duties)}   (Baserow-ready)")
    info("  Fractalaw status:      #{fl_status}")

    if fl_map != %{} do
      stage_counts =
        fl_map
        |> Enum.group_by(fn {_name, stage} -> stage end)
        |> Enum.map(fn {stage, entries} -> {stage, length(entries)} end)
        |> Enum.sort_by(fn {_s, c} -> -c end)

      info("")
      info("  Fractalaw stages:")

      for {stage, count} <- stage_counts do
        info("    #{String.pad_trailing(stage, 20)} #{pad(count)}")
      end
    end
  end

  # ── Output: Per-law table ──

  defp print_per_law_table(laws) do
    header =
      "  #{rpad("LAW NAME", 22)} #{rpad("TITLE", 35)} #{rpad("LIVE", 8)} #{lpad("LAT", 5)} #{lpad("TAXA%", 6)} #{rpad("FRACTALAW", 18)} #{lpad("DUTIES", 6)}"

    info(header)
    info("  #{String.duplicate("-", String.length(header) - 2)}")

    for law <- laws do
      taxa_pct =
        if law.taxa_total > 0,
          do: "#{round(law.taxa_enriched / law.taxa_total * 100)}%",
          else: "-"

      live_short =
        cond do
          is_binary(law.live) and String.contains?(law.live, "Revoked") -> "revoked"
          is_binary(law.live) and String.contains?(law.live, "Part") -> "partial"
          true -> "active"
        end

      fl = law.fractalaw_stage || "-"
      duties = if law.duties > 0, do: "#{law.duties}", else: "-"

      info(
        "  #{rpad(law.law_name, 22)} #{rpad(truncate(law.title, 35), 35)} #{rpad(live_short, 8)} #{lpad("#{law.lat_count}", 5)} #{lpad(taxa_pct, 6)} #{rpad(fl, 18)} #{lpad(duties, 6)}"
      )
    end
  end

  # ── Output: Flags ──

  defp print_flags(laws) do
    revoked =
      Enum.filter(laws, fn l ->
        is_binary(l.live) and
          (String.contains?(l.live, "Revoked") or String.contains?(l.live, "Repealed") or
             String.contains?(l.live, "Abolished"))
      end)

    lat_no_taxa =
      Enum.filter(laws, fn l ->
        l.lat_count > 0 and l.taxa_enriched == 0
      end)

    not_published =
      Enum.filter(laws, fn l ->
        l.fractalaw_stage != nil and l.fractalaw_stage != "published"
      end)

    if revoked != [] do
      info("  FLAGS: Applicable but revoked (#{length(revoked)})")

      for l <- revoked do
        info("    #{l.law_name}  #{truncate(l.title, 50)}")
      end

      info("")
    end

    if lat_no_taxa != [] do
      info("  FLAGS: LAT parsed but 0 enriched provisions (#{length(lat_no_taxa)})")

      for l <- lat_no_taxa do
        info("    #{l.law_name}  lat=#{l.lat_count}  #{truncate(l.title, 50)}")
      end

      info("")
    end

    if not_published != [] do
      info("  FLAGS: Fractalaw not published (#{length(not_published)})")

      for l <- not_published do
        info("    #{l.law_name}  stage=#{l.fractalaw_stage}  #{truncate(l.title, 50)}")
      end

      info("")
    end

    if revoked == [] and lat_no_taxa == [] and not_published == [] do
      info("  No flags - all clear!")
    end
  end

  # ── Helpers ──

  defp info(msg), do: Mix.shell().info(msg)
  defp truncate(nil, _max), do: ""
  defp truncate(s, max) when byte_size(s) <= max, do: s
  defp truncate(s, max), do: String.slice(s, 0, max - 3) <> "..."
  defp pad(n), do: n |> Integer.to_string() |> String.pad_leading(5)
  defp lpad(s, w), do: String.pad_leading(s, w)
  defp rpad(s, w), do: String.pad_trailing(s, w)

  defp pct(_n, 0), do: "  -  "
  defp pct(n, total), do: :io_lib.format("~5.1f%", [n / total * 100]) |> to_string()
end
