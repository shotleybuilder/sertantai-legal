defmodule Mix.Tasks.Lat.Amending do
  @moduledoc """
  A law's amendment ruleset (amendment-rules AR-01, AR-03), one readable
  line per rule — the law and targets, the operation (words-level or whole
  provisions), its treatment, and the amending provision it came from:

      mix lat.amending --law UK_uksi_2014_1638

      UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C … substitute—”

  The read pass (AR-03) reads each amending law once — the provisions our
  laws' notes and their changes feeds point to (one hop; one deduplicated
  set of pointers, CV-07), for every law they point from — and stores
  its rules (`amendment_rules`) with a small index (`Amendment.Index`:
  element ids, each repeals table's introducing section, the reader version,
  the laws read for), so the collector needs no XML:

      mix lat.amending --read                    # every amending law not read by this reader (resumable)
      mix lat.amending --read --amending A,B     # these amending laws (re-read)
      mix lat.amending --read --limit 20         # the next 20
      mix lat.amending --read --preview --amending A,B   # read, report what would change, write nothing
      mix lat.amending --read --preview --regression     # the regression set (test/fixtures/amendment_read/regression.txt + the golden laws' amending laws)

  Each changed amending law is reported (`ReadReport`: rules removed and
  added per amended law, the provisions behind them), then a summary.
  **Workflow (run time, 2026-10-25):** a reader fix is checked with
  `--preview` on the laws it concerns and on `--regression`; fixes are
  batched; one full `--read` per round, its report traced before
  accepting. Never a full pass per fix.

  An Act's own extent clause (CV-04: `extent_rules`) is read in the same
  pass; for the Acts changing a law, or named Acts, alone:

      mix lat.amending --extents --law UK_ukpga_1990_8
      mix lat.amending --extents --amending UK_ukpga_2005_15
      mix lat.amending --extents --amending A,B --cached   # the enabling cache only, never a fetch

  One amending law at a time, each in its own process: a parsed amending
  law can take gigabytes (a 5-wide run exhausted memory, 2026-10-20).
  """

  use Mix.Task

  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.Amendment.{ReadPass, ReadReport, Rule, Store}

  @shortdoc "Print a law's amendment rules; read amending laws into rules"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          law: :string,
          read: :boolean,
          amending: :string,
          limit: :integer,
          extents: :boolean,
          cached: :boolean,
          workers: :integer,
          preview: :boolean,
          regression: :boolean
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:extents] ->
        extents(opts)

      opts[:read] ->
        read(opts)

      opts[:law] ->
        for line <- opts[:law] |> Store.for_law() |> print(opts[:law]), do: Mix.shell().info(line)

      true ->
        Mix.raise(
          "usage: mix lat.amending --law X | --read [--amending A,B] [--limit N] | --extents --law X | --extents --amending A,B"
        )
    end
  end

  @doc "The printed lines for a law's rules."
  @spec print([Rule.t()], String.t()) :: [String.t()]
  def print([], law), do: ["#{law}: no amendment rules (the readers write them: AR-03)"]

  def print(rules, law) do
    groups =
      rules
      |> Enum.group_by(& &1.source.law)
      |> Enum.sort()
      |> Enum.flat_map(fn {source, rs} ->
        ["", "  from #{source}" | Enum.map(rs, &("    " <> Rule.to_text(&1)))]
      end)

    ["#{law}: #{length(rules)} rule(s)" | groups]
  end

  # ── --extents ───────────────────────────────────────────────────────

  # the extent clauses of the laws changing a law (its feed's affecting
  # laws), or of the Acts named, held in the CLML store
  defp extents(opts) do
    acts =
      case {opts[:amending], opts[:law]} do
        {nil, nil} ->
          Mix.raise("--extents needs --law X or --amending A,B")

        {nil, law} ->
          law
          |> SertantaiLegal.Scraper.LatStagedParser.law_effects(store: :only)
          |> Enum.map(& &1.affecting)
          |> Enum.uniq()

        {list, _} ->
          String.split(list, ",", trim: true)
      end
      |> Enum.filter(&(Extent.Store.reads?(&1) and ReadPass.held?(&1)))

    Mix.shell().info("#{length(acts)} laws to read for their extent clause")

    # the parent Acts the SIs' enabling powers lie in, read first (by this
    # reader), so an SI stating no extent is placed by them (CV-07) — those
    # among the laws read too: an SI never reads a parent not yet re-read
    # (several laws are read at once: run time, 2026-10-25)
    enabling_laws =
      for a <- acts,
          not Extent.Powers.act?(a),
          p <- Extent.Powers.enabling(a, opts[:cached]),
          law = p["law"],
          Extent.Store.reads?(law) and ReadPass.held?(law),
          uniq: true,
          do: law

    parents = Enum.reject(enabling_laws, &(&1 in acts))
    {first, rest} = Enum.split_with(acts, &(&1 in enabling_laws))

    Mix.shell().info("#{length(parents)} parent Acts of their enabling powers, read first")

    workers = Guard.workers(workers: opts[:workers])

    LawRunner.run(
      parents,
      fn p -> {:ok, _} = Extent.Store.write(p, Extent.ReadCache.law(p).read) end,
      fn _, _ -> :ok end,
      workers: workers
    )

    counter = :counters.new(1, [])

    # each in its own process (the parsed document goes when it exits);
    # the parents among them first
    for batch <- [first, rest] do
      LawRunner.run(
        batch,
        &extent_line(&1, opts[:cached]),
        fn law, line ->
          :counters.add(counter, 1, 1)

          Mix.shell().info(
            "  [#{:counters.get(counter, 1)}/#{length(acts)}] " <>
              if(is_binary(line), do: line, else: "#{law}: #{inspect(line)}")
          )
        end,
        workers: workers
      )
    end
  end

  defp extent_line(a, cached) do
    # the reading kept between runs (`Extent.ReadCache`, shared with the
    # catalogue and the check)
    e =
      a
      |> Extent.ReadCache.law()
      |> Map.fetch!(:read)
      |> Extent.Powers.with_powers(a, cached: cached)

    {:ok, n} = Extent.Store.write(a, e)

    stated =
      cond do
        e.default -> e.default
        e.powers -> "#{e.powers} (by its enabling powers)"
        e.competence -> "#{e.competence} (by its legislature's competence)"
        true -> "no clause"
      end

    "#{a}: #{stated} (#{n} rows)"
  end

  # ── --read ──────────────────────────────────────────────────────────

  defp read(opts) do
    Mix.shell().info("reading the changes feeds of our LAT laws for their pointers …")
    feed = ReadPass.feed_pointers()

    laws =
      cond do
        opts[:regression] ->
          regression_laws()

        opts[:amending] ->
          String.split(opts[:amending], ",", trim: true)

        true ->
          feed |> ReadPass.amending_laws() |> Enum.filter(&ReadPass.stale?(&1, Map.get(feed, &1)))
      end

    laws = if opts[:limit], do: Enum.take(laws, opts[:limit]), else: laws
    preview? = opts[:preview] == true

    Mix.shell().info(
      "#{length(laws)} amending laws to read#{if preview?, do: " (preview: nothing written)", else: ""}"
    )

    # several at once where the machine allows (`LawRunner.Guard`): each
    # amending law writes only its own rules and index; each in its own
    # process, its parsed document gone when it exits
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        laws,
        &read_one(&1, Map.get(feed, &1, %{laws: MapSet.new(), refs: []}), preview?),
        fn a, result ->
          :counters.add(counter, 1, 1)
          mem = div(:erlang.memory(:total), 1_048_576)

          line =
            case result do
              {diff, ids} -> "#{ids} provisions, #{diff.after} rules"
              other -> "FAILED #{inspect(other)}"
            end

          Mix.shell().info(
            "  [#{:counters.get(counter, 1)}/#{length(laws)}] #{a}: #{line} (#{mem} MB)"
          )
        end,
        workers: Guard.workers(workers: opts[:workers])
      )

    diffs = for {a, {diff, _ids}} <- results, into: %{}, do: {a, diff}
    changed = diffs |> Enum.sort() |> Enum.flat_map(fn {a, d} -> ReadReport.lines(a, d) end)

    Mix.shell().info("\n#{if preview?, do: "would change", else: "changed"}:")
    for line <- changed, do: Mix.shell().info("  " <> line)
    Mix.shell().info(ReadReport.summary(diffs))
  end

  # one amending law: its reading against its stored rules, stored unless a
  # preview
  defp read_one(amending, feed_entry, preview?) do
    old = Store.for_source(amending)

    case ReadPass.read(amending, feed_entry) do
      nil ->
        {ReadReport.diff(old, old), 0}

      r ->
        unless preview?, do: ReadPass.write(r)
        {ReadReport.diff(old, r.rules), length(r.ids)}
    end
  end

  # the regression set: amending laws whose reading has gone wrong before
  # (a committed list, one per line, # comments) and the golden laws'
  # amending laws
  @regression "test/fixtures/amendment_read/regression.txt"

  defp regression_laws do
    listed =
      @regression
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&(&1 |> String.replace(~r/#.*/, "") |> String.trim()))
      |> Enum.reject(&(&1 == ""))

    {golden, _} = Code.eval_file("test/fixtures/change_vocabulary/golden.exs")

    behind_golden =
      for law <- golden |> Enum.map(& &1.law) |> Enum.uniq(),
          r <- Store.for_law(law),
          uniq: true,
          do: r.source.law

    Enum.uniq(listed ++ behind_golden)
  end
end
