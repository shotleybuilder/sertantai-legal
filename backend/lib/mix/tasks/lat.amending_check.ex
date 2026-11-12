defmodule Mix.Tasks.Lat.AmendingCheck do
  @moduledoc """
  The amendment reader's precision check (change vocabulary CV-S06): how
  many of a family's stored changes the amending law's text states (alone,
  or with legislation.gov.uk), and with `--sample FILE` a reproducible
  random sample of them with the words behind each (`Amendment.CheckSample`)
  for the `amending-reader-check` agent. `--strata` counts the strata
  (agreeing, disagreeing, law text only; `Amendment.CheckStrata`) and the
  agreement with legislation.gov.uk over every both-sourced change;
  `--stratum A|D|L` samples one stratum, `--skip N` the next batch of the
  same draw. `--gate` is the family gate (Decision 1, Jason 2026-11-06,
  Maritime Safety: Amending-law reader): every D and L change grouped by
  cause and amending law (`Amendment.Disagreement`), each with its reviewed
  status (`test/fixtures/amendment_patterns/disagreements.json`); PASS only
  when every group is named `known:`. Read-only.

      mix lat.amending_check --family "OH&S: Occupational" --strata
      mix lat.amending_check --family F --gate [--all]
      mix lat.amending_check --family F --sample FILE --n 50 --seed N [--stratum A] [--skip 50]

  The gate's review (Amending-law reader: review tooling):

      mix lat.amending_check --family F --gate --dump FILE [--per 10]
      mix lat.amending_check --family F --gate --name-standard --review REPORT [--write]

  `--dump` writes each group with up to `--per` of its changes as
  checkable items (`Amendment.Review.GateDump`; `--per 0` every change),
  unnamed groups first. `--name-standard` proposes the standard status
  for each unnamed group whose cause has one, citing the review report
  the groups were read in (`Amendment.Review.StandardStatus`), and lists
  the groups left to name by hand: a dry run. `--write` adds the
  proposals to the reviewed statuses, only once Jason has decided.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  alias SertantaiLegal.Scraper.Amendment.{CheckSample, CheckStrata, Disagreement, PatternSource}
  alias SertantaiLegal.Scraper.Amendment.Review.{GateDump, StandardStatus}
  alias SertantaiLegal.Scraper.Amendment.Store, as: Rules
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store

  @shortdoc "The amendment reader's precision sample for a family (read-only)"

  @usage "usage: mix lat.amending_check --family F [--strata] [--gate [--all] [--dump FILE --per N] [--name-standard --review R [--write]]] " <>
           "[--sample FILE --n N --seed S --stratum A|D|L --skip K]"

  @reviewed "test/fixtures/amendment_patterns/disagreements.json"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          sample: :string,
          n: :integer,
          seed: :integer,
          strata: :boolean,
          stratum: :string,
          skip: :integer,
          gate: :boolean,
          all: :boolean,
          dump: :string,
          per: :integer,
          name_standard: :boolean,
          review: :string,
          write: :boolean
        ]
      )

    family = opts[:family] || Mix.raise(@usage)
    stratum = stratum(opts[:stratum])

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = PatternSource.family_laws(family)
    by_law = Map.new(laws, &{&1, Store.for_law(&1)})

    classified =
      for {law, changes} <- by_law, {c, s} <- CheckStrata.classify(changes), do: {law, c, s}

    stated = Enum.frequencies_by(classified, fn {_, c, _} -> CheckSample.stated_by(c) end)

    Mix.shell().info(
      "#{length(laws)} laws; changes the law's text states: #{length(classified)} #{inspect(stated)}"
    )

    if opts[:strata], do: strata(classified, by_law)
    step = if opts[:gate], do: gate(classified, opts)

    if path = opts[:sample], do: sample(path, opts, classified, stratum)
    step
  end

  defp sample(path, opts, classified, stratum) do
    seed = opts[:seed] || 1

    items =
      for({law, c, s} <- classified, stratum in [nil, s], do: {law, c})
      |> CheckSample.draw(length(classified), seed)
      |> Enum.drop(opts[:skip] || 0)
      |> Enum.take(opts[:n] || 50)
      |> Enum.with_index(1)
      |> Enum.map(fn {lc, i} -> CheckSample.item(lc, i) end)

    File.write!(path, Jason.encode!(items, pretty: true))

    Mix.shell().info(
      "sample: #{length(items)} changes (seed #{seed}, stratum #{stratum || "all"}, " <>
        "skip #{opts[:skip] || 0}) → #{path}"
    )
  end

  defp strata(classified, by_law) do
    counts = Enum.frequencies_by(classified, &elem(&1, 2))
    total = length(classified)

    Mix.shell().info("\nstrata:")

    for {s, label} <- [A: "agreeing", D: "disagreeing", L: "law text only"] do
      n = Map.get(counts, s, 0)
      Mix.shell().info("  #{s}  #{label}: #{n} (#{pct(n, total)})")
    end

    agreement =
      by_law
      |> Map.values()
      |> Enum.map(&CheckStrata.agreement/1)
      |> Enum.reduce(%{}, &Map.merge(&2, &1, fn _, {a1, n1}, {a2, n2} -> {a1 + a2, n1 + n2} end))

    Mix.shell().info("\nagreement with legislation.gov.uk over both-sourced changes:")

    for {attribute, {a, n}} <- Enum.sort(agreement),
        do: Mix.shell().info("  #{attribute}: #{a}/#{n} (#{pct(a, n)})")
  end

  # the family gate: each D and L change by cause and amending law, reviewed
  # in disagreements.json (Decision 1, 2026-11-06)
  defp gate(classified, opts) do
    all? = opts[:all]
    shell = Mix.shell()
    rows = for {law, c, s} <- classified, s in [:D, :L], do: {law, c, s}
    rules = rows |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Map.new(&{&1, Rules.for_law(&1)})
    items = Disagreement.items(rows, rules, reviewed())
    gate = Disagreement.gate(items)
    review(opts, rows, rules, gate)

    counts = Enum.map_join(gate.counts, ", ", fn {k, n} -> "#{k} #{n}" end)
    shell.info("\nD and L changes by cause (#{@reviewed}): #{length(items)} groups; #{counts}")

    for {cause, n} <-
          items
          |> Enum.group_by(& &1.shape, & &1.reach)
          |> Enum.map(fn {k, ns} -> {k, Enum.sum(ns)} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: shell.info("  #{pad(n)}  #{cause}")

    shown = if all?, do: Enum.sort_by(items, &{-&1.reach, &1.law, &1.shape}), else: gate.failing

    shell.info(
      "\n#{if all?, do: "every group", else: "not named"} (widest reach first): #{length(shown)}"
    )

    for i <- shown do
      shell.info("  #{pad(i.reach)}  #{i.shape} @ #{i.law}  [#{i.status || "no status"}]")
      for w <- Enum.take(i.words, 4), do: shell.info("           #{w}")
    end

    shell.info(
      "\n#{if gate.pass?, do: "PASS", else: "FAIL"} (groups not named: #{length(gate.failing)})"
    )

    Step.new("Amending-law reader", gate.pass?, length(gate.failing))
  end

  # the gate's review tools: the dump, the standard statuses
  defp review(opts, rows, rules, gate) do
    if path = opts[:dump], do: dump(path, Disagreement.groups(rows, rules), opts[:per])
    if opts[:name_standard], do: name_standard(gate.failing, opts)
  end

  defp dump(path, groups, per) do
    per = if per == 0, do: :all, else: per || 10
    out = GateDump.dump(groups, reviewed(), &CheckSample.item/2, per)
    File.write!(path, Jason.encode!(out, pretty: true))
    named = Enum.count(out, & &1["named"])

    Mix.shell().info(
      "\ndump: #{length(out)} groups (#{named} named), up to #{per} changes each → #{path}"
    )
  end

  # the standard statuses proposed for the unnamed groups; written only on --write
  defp name_standard(failing, opts) do
    review =
      opts[:review] ||
        Mix.raise("--name-standard needs --review REPORT (where the groups were read)")

    %{proposed: proposed, by_hand: by_hand} = StandardStatus.proposals(failing, review)

    words = Map.new(failing, &{"#{&1.shape} @ #{&1.law}", Enum.take(&1.words, 3)})

    # each proposal beside its group's words: a standard is read, never stamped
    Mix.shell().info(
      "\nstandard statuses proposed (read each group's words first): #{length(proposed)}"
    )

    for {k, v} <- proposed do
      Mix.shell().info("  #{k}\n      #{v}")
      for w <- words[k], do: Mix.shell().info("        #{w}")
    end

    Mix.shell().info("\nleft to name by hand: #{length(by_hand)}")
    for k <- by_hand, do: Mix.shell().info("  #{k}")

    if opts[:write] do
      File.write!(@reviewed, StandardStatus.write(reviewed(), proposed))
      Mix.shell().info("\nwrote #{length(proposed)} statuses → #{@reviewed}")
    else
      Mix.shell().info("\ndry run: nothing written (--write, once decided)")
    end
  end

  defp reviewed do
    case File.read(@reviewed) do
      {:ok, body} -> Jason.decode!(body)
      _ -> %{}
    end
  end

  defp pad(n), do: String.pad_leading(to_string(n), 5)

  defp stratum(nil), do: nil
  defp stratum(s) when s in ~w(A D L), do: String.to_atom(s)
  defp stratum(_), do: Mix.raise(@usage)

  defp pct(_, 0), do: "–"
  defp pct(a, n), do: :erlang.float_to_binary(100 * a / n, decimals: 1) <> "%"
end
