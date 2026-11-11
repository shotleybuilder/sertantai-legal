defmodule Mix.Tasks.Lat.Sources do
  @moduledoc """
  Sources held (LAT Change Pipeline, step: Sources): for a scope, the documents its
  labels need against what the local store holds — sliced by the gap the
  feed leaves (read from the feed and the stored changes: re-run after a
  rebuild), every missing or stale document named with its status, and each
  law's feed against the register's change statistics. Read-only unless
  `--fetch`, which fetches only the documents the check failed.

      mix lat.sources --family "OH&S: Occupational"
      mix lat.sources --laws UK_uksi_2010_404,UK_ukpga_1974_37
      mix lat.sources --family "OH&S: Occupational" --all   # every failure listed
      mix lat.sources --family "OH&S: Occupational" --fetch # then fetch only what failed (ask first)

  Statuses: `held` (fresh), `absent` (legislation.gov.uk has none: a stored
  404), `not_fetched`, `incomplete` (a feed missing pages), `stale` (older
  than a version the register could know of: `Sources.stale?/4`). The
  rules are `Sources`'; the facts are read by `Sources.Held`.

  A feed that differs from the register's statistics fails until it is
  explained in `test/fixtures/sources/explained.json` (law → reason, each
  reviewed; e.g. the register's own count capped).
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source, as: Scope
  alias SertantaiLegal.Scraper.Sources
  alias SertantaiLegal.Scraper.Sources.Held
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache
  alias SertantaiLegal.Scraper.LegislationGovUk.{ChangesFeed, Client}

  @shortdoc "Sources a scope's labels need, against what is held (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, laws: :string, all: :boolean, fetch: :boolean]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = scope(opts)
    Mix.shell().info("#{length(laws)} laws in scope")

    facts = Enum.map(laws, &Held.law/1)
    amenders = facts |> Enum.flat_map(& &1.amenders) |> Enum.uniq()
    clauses = ExtentStore.for_laws(amenders)
    amending = Map.new(amenders, &{&1, Held.amending(&1, clauses)})

    needs =
      facts |> Enum.flat_map(&Sources.needs(&1, amending)) |> Enum.uniq_by(&{&1.law, &1.part})

    valid = Held.valid_dates(Enum.map(needs, & &1.law))
    statuses = Enum.map(needs, &{&1, Held.status(&1, valid)})

    # each feed counted as the register counts it
    comparisons =
      for f <- facts,
          do:
            f.law
            |> Sources.register_counts(f.effects)
            |> Map.merge(%{law: f.law, register: f.register})

    report = Sources.report(statuses, comparisons, explained: explained())
    print(report, opts)

    if opts[:fetch], do: fetch(report.failures)
    Step.new("Sources", report.pass, length(report.failures))
  end

  # --fetch: only the documents the check failed — a missing one fetched, a
  # stale one or an incomplete feed fetched again (CV-S01; asked for first)
  defp fetch(failures) do
    Mix.shell().info("\nfetching #{length(failures)} documents the check failed …")

    results =
      for {f, i} <- Enum.with_index(failures, 1) do
        r = fetch_one(f)
        if rem(i, 20) == 0, do: Mix.shell().info("  #{i}/#{length(failures)}")
        {f, r}
      end

    failed = for {f, r} <- results, r != :ok, do: {f, r}
    Mix.shell().info("fetched #{length(results) - length(failed)}, failed #{length(failed)}")

    for {f, r} <- failed,
        do: Mix.shell().info("  #{f.law} #{inspect(f.part)}: #{inspect(r)}")
  end

  defp fetch_one(%{part: :introduction, law: law}) do
    EnablingCache.get(law, retry_empty: true)
    if EnablingCache.cached(law) != :none, do: :ok, else: :failed
  end

  defp fetch_one(%{part: :feed, law: law, status: status}) do
    [_, type, year, number] = String.split(law, "_", parts: 4)
    mode = if status == :not_fetched, do: :write, else: :refresh

    case ChangesFeed.fetch(type, year, number, store: mode) do
      {:ok, _} -> :ok
      {:error, reason} -> if reason =~ "404", do: :ok, else: {:error, reason}
    end
  end

  defp fetch_one(%{part: part, law: law, status: status}) do
    path = Sources.doc_path(law, part)
    mode = if status == :stale, do: :refresh, else: :prefer

    case Client.fetch_xml(path, store: mode) do
      {:ok, _} -> :ok
      {:ok, _, _} -> :ok
      # a 404 is stored as missing: legislation.gov.uk has none
      {:error, 404, _} -> :ok
      other -> other
    end
  end

  @explained "test/fixtures/sources/explained.json"

  # the register differences reviewed and explained, law → reason
  defp explained do
    case File.read(@explained) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp scope(opts) do
    cond do
      opts[:family] ->
        Scope.family_laws(opts[:family])

      opts[:laws] ->
        String.split(opts[:laws], ",", trim: true)

      true ->
        Mix.raise("usage: mix lat.sources --family F | --laws A,B [--all]")
    end
  end

  defp print(r, opts) do
    Mix.shell().info("\nneeded against held, by category:")

    for c <- r.order, counts = r.counts[c], counts != nil do
      total = counts |> Map.values() |> Enum.sum()

      Mix.shell().info(
        "  #{c}: #{total} — " <>
          Enum.map_join(Enum.sort(counts), ", ", fn {s, n} -> "#{s} #{n}" end)
      )
    end

    needed =
      for c <- r.order, counts = r.counts[c], counts != nil, reduce: 0 do
        acc -> acc + (counts |> Map.values() |> Enum.sum())
      end

    Mix.shell().info("  needed, all categories: #{needed}")
    Mix.shell().info("\nfailures: #{length(r.failures)}")

    for f <- if(opts[:all], do: r.failures, else: Enum.take(r.failures, 20)),
        do:
          Mix.shell().info(
            "  #{f.status}  #{f.category}  #{f.law} #{inspect(f.part)}  (for #{f.for})"
          )

    Mix.shell().info(
      "\nfeeds differing from the register's change statistics: #{length(r.register_differences)}"
    )

    for d <-
          if(opts[:all], do: r.register_differences, else: Enum.take(r.register_differences, 20)),
        do:
          Mix.shell().info(
            "  #{d.law}: effects #{d.effects} vs register #{d.register.effects}; laws #{d.laws} vs #{d.register.laws}"
          )

    Mix.shell().info("\n#{if r.pass, do: "PASS", else: "FAIL"}")
  end
end
