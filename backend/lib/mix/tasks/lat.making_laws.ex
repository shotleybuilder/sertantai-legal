defmodule Mix.Tasks.Lat.MakingLaws do
  @moduledoc """
  Making laws (LAT Change Pipeline, step: Making laws): each live law of a
  family (in force or part revoked) decided making or not from its own text
  (`Scraper.MakingLaws`), against the `is_making` stored and the tier that
  decided it. Read-only unless `--fetch` or `--apply` (ask Jason first).

      mix lat.making_laws --family "Maritime Safety"
      mix lat.making_laws --family "Maritime Safety" --fetch   # fetch bodies and Schedules not held
      mix lat.making_laws --family "Maritime Safety" --apply   # record the verdicts (Making.record/4)

  Writes `data/reports/making-laws/<family>.csv` (`--out` to change), one row
  per law in name order, and prints the verdicts, the disagreements with the
  stored `is_making` by its source, and the laws with no verdict (Jason's
  list). `--apply` records each verdict as the resolver's `law_text` tier:
  below a human review and fractalaw's enrichment, above every estimate.
  """
  use Mix.Task

  alias SertantaiLegal.Legal.{LegalRegister, Making}
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{MakingLaws, Sources}
  alias SertantaiLegal.Scraper.Amendment.ReadLaw
  alias SertantaiLegal.Scraper.LegislationGovUk.{Client, ClmlStore}

  @shortdoc "Decide a family's making laws from their own text"

  @columns ~w(law verdict reason change requirement power standard is_making is_making_source has_rows title)a

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, fetch: :boolean, apply: :boolean, out: :string]
      )

    family = opts[:family] || Mix.raise("--family is required")
    Mix.Task.run("app.start")

    laws = laws(family)
    if opts[:fetch], do: fetch(laws)

    rows = Enum.map(laws, &row/1)
    out = opts[:out] || "data/reports/making-laws/#{slug(family)}.csv"
    write_csv(out, rows)
    report(rows, out)
    if opts[:apply], do: apply_verdicts(rows)
  end

  # ── laws and their text ────────────────────────────────────────────────

  defp laws(family) do
    Repo.query!(
      """
      SELECT r.id, r.name, r.title_en, r.is_making, coalesce(r.is_making_source, ''),
             EXISTS (SELECT 1 FROM legal_articles a WHERE a.law_name = r.name)
        FROM legal_register r
       WHERE r.family LIKE '%' || $1 || '%' AND r.live NOT LIKE '❌%'
       ORDER BY r.name
      """,
      [family]
    ).rows
    |> Enum.map(fn [id, name, title, making, source, rows?] ->
      %{id: id, law: name, title: title, is_making: making, source: source, has_rows: rows?}
    end)
  end

  defp row(law), do: Map.merge(law, MakingLaws.classify(ReadLaw.doc(law.law)))

  # ── --fetch ────────────────────────────────────────────────────────────

  defp fetch(laws) do
    missing = Enum.filter(laws, &(ClmlStore.law_files(&1.law) == []))
    Mix.shell().info("fetching the body and Schedules of #{length(missing)} laws not held …")

    failed =
      for law <- missing, part <- [:body, :schedules], fetch_one(law.law, part) != :ok do
        "#{law.law} #{part}"
      end

    Mix.shell().info("fetched; #{length(failed)} failed: #{Enum.join(failed, ", ")}")
  end

  # a 404 is stored as missing: legislation.gov.uk has none (no Schedules,
  # or no XML at all)
  defp fetch_one(law, part) do
    case Client.fetch_xml(Sources.doc_path(law, part), store: :prefer) do
      {:ok, _} -> :ok
      {:ok, _, _} -> :ok
      {:error, 404, _} -> :ok
      _ -> :failed
    end
  end

  # ── report ─────────────────────────────────────────────────────────────

  defp write_csv(out, rows) do
    File.mkdir_p!(Path.dirname(out))
    lines = Enum.map(rows, &csv_line(csv_values(&1)))
    File.write!(out, Enum.join([csv_line(@columns) | lines], "\n") <> "\n")
  end

  defp csv_values(r) do
    counts = r.counts

    [
      r.law,
      r.verdict,
      r.reason,
      counts[:change] || 0,
      counts[:requirement] || 0,
      counts[:power] || 0,
      counts[:standard] || 0,
      r.is_making,
      r.source,
      r.has_rows,
      r.title
    ]
  end

  defp csv_line(values), do: Enum.map_join(values, ",", &csv_cell/1)

  defp csv_cell(v) do
    s = to_string(v)
    if s =~ ~r/[",\n]/, do: ~s("#{String.replace(s, "\"", "\"\"")}"), else: s
  end

  defp report(rows, out) do
    shell = Mix.shell()
    shell.info("\n#{length(rows)} live laws → #{out}\n")
    shell.info("verdicts:")
    for {v, n} <- tally(rows, &verdict_key/1), do: shell.info("  #{n}  #{label(v)}")

    disagree = Enum.filter(rows, &(&1.verdict != nil and &1.verdict == :making != &1.is_making))
    shell.info("\ndisagreeing with the stored is_making (#{length(disagree)}), by its source:")

    for r <- disagree,
        do:
          shell.info(
            "  #{r.law}  stored #{r.is_making} (#{r.source}) → #{r.verdict}: #{r.reason}"
          )

    none = Enum.filter(rows, &(&1.verdict == nil))
    shell.info("\nno verdict, for Jason (#{length(none)}, #{percent(none, rows)} of the family):")
    for r <- none, do: shell.info("  #{r.law}  #{r.reason}  #{r.title}")
  end

  defp tally(rows, key), do: rows |> Enum.frequencies_by(key) |> Enum.sort_by(&(-elem(&1, 1)))

  # making laws together, whatever their count of requirements
  defp verdict_key(%{verdict: :making}), do: {:making, nil}
  defp verdict_key(r), do: {r.verdict, r.reason}

  defp label({:making, _}), do: "making"
  defp label({nil, reason}), do: "no verdict: #{reason}"
  defp label({verdict, reason}), do: "#{verdict}: #{reason}"

  defp percent(part, whole), do: "#{round(100 * length(part) / max(length(whole), 1))}%"

  # ── --apply ────────────────────────────────────────────────────────────

  defp apply_verdicts(rows) do
    results = for r <- rows, r.verdict != nil, do: record(r)
    errors = Enum.reject(results, &match?({:ok, _}, &1))

    Mix.shell().info(
      "\nrecorded #{length(results) - length(errors)} verdicts; #{length(errors)} errors"
    )

    for e <- errors, do: Mix.shell().error("  #{inspect(e)}")
  end

  defp record(r) do
    evidence = %{making_text_verdict: Atom.to_string(r.verdict), making_text_reason: r.reason}

    with {:ok, law} <- Ash.get(LegalRegister, Ecto.UUID.cast!(r.id)),
         {:ok, _} = ok <- Making.record(law, evidence, "lat.making_laws") do
      ok
    else
      error -> {r.law, error}
    end
  end

  defp slug(family) do
    family
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end
end
