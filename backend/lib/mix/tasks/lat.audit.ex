defmodule Mix.Tasks.Lat.Audit do
  @shortdoc "Run LAT parse quality diagnostics across all parsed laws"

  @moduledoc """
  Audits LAT rows in the database for parse quality issues.

  Checks for structural blob duplication, text size anomalies, empty
  sections, and other indicators of novel legal structures that the
  parser may not handle correctly.

  ## Usage

      mix lat.audit [options]

  ## Options

    * `--help` — Show this help text
    * `--law NAME` — Audit a single law by name (e.g. UK_ukpga_2023_50)
    * `--family FAMILY` — Audit laws in a specific family. Exact match first,
      then falls back to LIKE. Use `--family "💙 PUBLIC"` for exact or
      `--family "PUBLIC: Building"` for substring match.
    * `--limit N` — Only audit the first N laws (for testing)
    * `--verbose` — Show per-law diagnostics, not just summary
    * `--errors-only` — Only show laws with errors (severity: error)

  ## Checks

    * **structural_blob** (error) — Part/Chapter/Schedule row >1KB when sections exist
    * **text_overlap** (warning) — >50% structural text found in child sections
    * **empty_section** (warning) — section-level row with no text
    * **duplicate_section_id** (warning) — same section_id on multiple rows
    * **text_size_outlier** (warning) — single row >50KB
    * **missing_provisions** (error) — structural rows but zero section-level rows
    * **unknown_section_type** (warning) — section_type not in known set

  ## Examples

      # Audit all laws
      mix lat.audit

      # Audit a specific law
      mix lat.audit --law UK_ukpga_2023_50

      # Audit all FIRE family laws
      mix lat.audit --family FIRE --verbose

      # Quick check on first 50 laws with verbose output
      mix lat.audit --limit 50 --verbose

      # Show only laws with critical errors
      mix lat.audit --errors-only
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LatParser.Diagnostics

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          help: :boolean,
          law: :string,
          family: :string,
          limit: :integer,
          verbose: :boolean,
          errors_only: :boolean
        ]
      )

    if Keyword.get(opts, :help, false) do
      Mix.shell().info(@moduledoc)
    else
      do_run(opts)
    end
  end

  defp do_run(opts) do
    Mix.Task.run("app.start")

    repo = SertantaiLegal.Repo

    law_names = fetch_law_names(repo, opts)

    Mix.shell().info("Auditing #{length(law_names)} law(s)...\n")

    results =
      law_names
      |> Enum.map(fn law_name ->
        rows = fetch_lat_rows(repo, law_name)

        if rows == [] do
          {law_name, :no_rows, [], nil}
        else
          {result, warnings} = Diagnostics.validate(rows)
          summary = Diagnostics.summary(rows)
          {law_name, result, warnings, summary}
        end
      end)

    # Print results
    errors_only = Keyword.get(opts, :errors_only, false)
    verbose = Keyword.get(opts, :verbose, false)

    {clean, with_warnings, with_errors, no_rows} = classify_results(results)

    if verbose or errors_only do
      print_detailed_results(results, errors_only)
    end

    Mix.shell().info("\n── Summary ────────────────────────────────────")
    Mix.shell().info("  Total laws audited:  #{length(results)}")
    Mix.shell().info("  Clean (no issues):   #{length(clean)}")
    Mix.shell().info("  Warnings only:       #{length(with_warnings)}")
    Mix.shell().info("  Errors:              #{length(with_errors)}")
    Mix.shell().info("  No LAT rows:         #{length(no_rows)}")

    if with_errors != [] do
      Mix.shell().info("\n── Laws with Errors ───────────────────────────")

      for {law_name, _result, warnings, summary} <- with_errors do
        errors = Enum.filter(warnings, &(&1.severity == :error))

        Mix.shell().info(
          "  #{law_name}  (#{summary.total_rows} rows, #{summary.structural_text_pct}% structural text)"
        )

        for e <- errors do
          Mix.shell().info("    ✗ #{e.message}")
        end
      end
    end

    # Corpus-wide stats
    all_summaries = results |> Enum.map(&elem(&1, 3)) |> Enum.reject(&is_nil/1)
    print_corpus_stats(all_summaries)
  end

  defp fetch_law_names(repo, opts) do
    import Ecto.Query

    {names, family_label} =
      cond do
        law_name = Keyword.get(opts, :law) ->
          q =
            from(l in "lat",
              where: l.law_name == ^law_name,
              select: l.law_name,
              distinct: true
            )

          {repo.all(apply_limit(q, opts)), nil}

        family = Keyword.get(opts, :family) ->
          {fetch_family_names(repo, family, opts), family}

        true ->
          q =
            from(l in "lat",
              select: l.law_name,
              distinct: true,
              order_by: l.law_name
            )

          {repo.all(apply_limit(q, opts)), nil}
      end

    if family_label do
      Mix.shell().info("Family filter: #{family_label} (#{length(names)} laws)")
    end

    names
  end

  defp apply_limit(query, opts) do
    import Ecto.Query

    case Keyword.get(opts, :limit) do
      nil -> query
      n -> from(q in query, limit: ^n)
    end
  end

  # Try exact match on family first. If no results, fall back to LIKE.
  # This prevents "--family PUBLIC" from matching all PUBLIC sub-families
  # when the user means the top-level "💙 PUBLIC" family.
  defp fetch_family_names(repo, family, opts) do
    import Ecto.Query

    exact_q =
      from(l in "lat",
        join: lrt in "uk_lrt",
        on: l.law_name == lrt.name,
        where: lrt.family == ^family,
        select: l.law_name,
        distinct: true,
        order_by: l.law_name
      )
      |> apply_limit(opts)

    case repo.all(exact_q) do
      [] ->
        pattern = "%#{family}%"

        like_q =
          from(l in "lat",
            join: lrt in "uk_lrt",
            on: l.law_name == lrt.name,
            where: like(lrt.family, ^pattern),
            select: l.law_name,
            distinct: true,
            order_by: l.law_name
          )
          |> apply_limit(opts)

        repo.all(like_q)

      names ->
        names
    end
  end

  defp fetch_lat_rows(repo, law_name) do
    import Ecto.Query

    from(l in "lat",
      where: l.law_name == ^law_name,
      select: %{
        section_id: l.section_id,
        section_type: l.section_type,
        text: l.text,
        part: l.part,
        chapter: l.chapter,
        schedule: l.schedule,
        heading_group: l.heading_group,
        provision: l.provision,
        paragraph: l.paragraph,
        sub_paragraph: l.sub_paragraph,
        position: l.position
      },
      order_by: l.position
    )
    |> repo.all()
  end

  defp classify_results(results) do
    no_rows = Enum.filter(results, fn {_, r, _, _} -> r == :no_rows end)
    clean = Enum.filter(results, fn {_, r, w, _} -> r == :ok and w == [] end)

    with_warnings =
      Enum.filter(results, fn {_, r, w, _} ->
        r == :ok and w != [] and Enum.all?(w, &(&1.severity == :warning))
      end)

    with_errors = Enum.filter(results, fn {_, r, _, _} -> r == :error end)

    {clean, with_warnings, with_errors, no_rows}
  end

  defp print_detailed_results(results, errors_only) do
    for {law_name, result, warnings, summary} <- results,
        result != :no_rows,
        not (errors_only and result == :ok) do
      status = if result == :ok, do: "⚠", else: "✗"
      rows_info = if summary, do: " (#{summary.total_rows} rows)", else: ""
      Mix.shell().info("\n#{status} #{law_name}#{rows_info}")

      for w <- warnings do
        icon = if w.severity == :error, do: "  ✗", else: "  ⚠"
        Mix.shell().info("#{icon} [#{w.check}] #{w.message}")
      end
    end
  end

  defp print_corpus_stats(summaries) when summaries == [], do: :ok

  defp print_corpus_stats(summaries) do
    total_rows = summaries |> Enum.map(& &1.total_rows) |> Enum.sum()
    total_structural = summaries |> Enum.map(& &1.structural_rows) |> Enum.sum()
    total_section = summaries |> Enum.map(& &1.section_rows) |> Enum.sum()
    total_bytes = summaries |> Enum.map(& &1.total_text_bytes) |> Enum.sum()
    structural_bytes = summaries |> Enum.map(& &1.structural_text_bytes) |> Enum.sum()

    Mix.shell().info("\n── Corpus Statistics ──────────────────────────")
    Mix.shell().info("  Total LAT rows:          #{format_number(total_rows)}")
    Mix.shell().info("  Structural rows:         #{format_number(total_structural)}")
    Mix.shell().info("  Section-level rows:      #{format_number(total_section)}")
    Mix.shell().info("  Total text:              #{format_bytes(total_bytes)}")
    Mix.shell().info("  Structural text:         #{format_bytes(structural_bytes)}")

    pct =
      if total_bytes > 0,
        do: Float.round(structural_bytes / total_bytes * 100, 1),
        else: 0.0

    Mix.shell().info("  Structural text %:       #{pct}%")

    # Top 5 largest max rows
    top5 =
      summaries
      |> Enum.sort_by(& &1.max_row_text_bytes, :desc)
      |> Enum.take(5)

    Mix.shell().info("\n  Top 5 largest single rows:")

    for s <- top5 do
      Mix.shell().info(
        "    #{format_bytes(s.max_row_text_bytes)} — #{s.max_row_section_id || "?"}"
      )
    end
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

  defp format_bytes(bytes) when bytes < 1024, do: "#{bytes} B"
  defp format_bytes(bytes) when bytes < 1_048_576, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{Float.round(bytes / 1_048_576, 1)} MB"
end
