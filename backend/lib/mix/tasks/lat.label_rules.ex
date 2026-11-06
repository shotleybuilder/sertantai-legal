defmodule Mix.Tasks.Lat.LabelRules do
  @moduledoc """
  The switch-over's rules over every row of a family (CV-06,
  `ChangeVocabulary.LabelRules`): breaches by rule, the known-limit rows
  apart (`backend/data/reports/change-vocabulary/cv-06a-known-limits.md`) and
  the named date gaps (`cv-06-date-gaps.md`).
  `--list RULE` names each breach of one rule. Read-only.

      mix lat.label_rules --family "OH&S: Occupational" [--list before_amender]
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelPeriods, LabelRules, LabelSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.LabelRules.Context

  @shortdoc "The switch-over's rules over a family's rows (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [family: :string, list: :string])
    family = opts[:family] || Mix.raise("usage: mix lat.label_rules --family F [--list RULE]")
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    known = known()

    rows =
      for law <- PatternSource.family_laws(family),
          rs = LabelSource.rows(law),
          is_list(rs),
          r <- rs,
          do: Map.put(r, :law, law)

    ctx = Context.for_rows(rows)

    breaches =
      for r <- rows,
          not MapSet.member?(known, r.sid),
          # the labels as compliance gets them (`LabelPeriods`)
          b <-
            LabelRules.breaches(
              LabelPeriods.periods(r.law, r.sid, r.periods, r.reaching),
              r.reaching,
              ctx.(r)
            ),
          do: {r, b}

    by_rule = Enum.group_by(breaches, fn {_, {rule, _}} -> rule end)

    Mix.shell().info(
      "#{length(rows)} rows; breaching #{breaches |> Enum.reject(&(elem(elem(&1, 1), 0) in LabelRules.informational())) |> Enum.map(&elem(&1, 0).sid) |> Enum.uniq() |> length()} (#{Enum.join(LabelRules.informational(), ", ")} listed apart)"
    )

    for {rule, bs} <- Enum.sort(by_rule),
        do:
          Mix.shell().info(
            "  #{rule}: #{bs |> Enum.map(&elem(&1, 0).sid) |> Enum.uniq() |> length()} rows"
          )

    failing = Map.drop(by_rule, LabelRules.informational())

    if Enum.empty?(failing), do: Mix.shell().info("PASSED"), else: Mix.shell().info("NOT PASSED")

    if name = opts[:list] do
      for {r, {_rule, why}} <- Map.get(by_rule, String.to_atom(name), []),
          do: Mix.shell().info("#{r.sid}\t#{why}")
    end
  end

  defp known, do: SertantaiLegal.Scraper.ChangeVocabulary.KnownLimits.sids()
end
