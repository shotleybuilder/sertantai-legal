defmodule Mix.Tasks.Lat.LabelRules do
  @moduledoc """
  The switch-over's rules over every row of a family (CV-06,
  `ChangeVocabulary.LabelRules`): breaches by rule, the known-limit rows
  apart (`backend/data/reports/change-vocabulary/cv-06a-known-limits.md`).
  `--list RULE` names each breach of one rule. Read-only.

      mix lat.label_rules --family "OH&S: Occupational" [--list before_amender]
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelPeriods, LabelRules, LabelSource, Windsor}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Existence

  @shortdoc "The switch-over's rules over a family's rows (read-only)"
  @known "data/reports/change-vocabulary/cv-06a-known-limits.md"

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

    made_of = made_of(rows)

    breaches =
      for r <- rows,
          not MapSet.member?(known, r.sid),
          # the labels as compliance gets them (`LabelPeriods`)
          b <-
            LabelRules.breaches(
              LabelPeriods.periods(r.law, r.sid, r.periods, r.reaching),
              r.reaching,
              ctx(r, made_of)
            ),
          do: {r, b}

    by_rule = Enum.group_by(breaches, fn {_, {rule, _}} -> rule end)

    Mix.shell().info(
      "#{length(rows)} rows; breaching #{breaches |> Enum.map(&elem(&1, 0).sid) |> Enum.uniq() |> length()}"
    )

    for {rule, bs} <- Enum.sort(by_rule),
        do:
          Mix.shell().info(
            "  #{rule}: #{bs |> Enum.map(&elem(&1, 0).sid) |> Enum.uniq() |> length()} rows"
          )

    if Enum.empty?(by_rule), do: Mix.shell().info("PASSED"), else: Mix.shell().info("NOT PASSED")

    if name = opts[:list] do
      for {r, {_rule, why}} <- Map.get(by_rule, String.to_atom(name), []),
          do: Mix.shell().info("#{r.sid}\t#{why}")
    end
  end

  defp ctx(r, made_of) do
    base = String.replace(r.id, ~r/\[[^\]]+\]$/, "")

    %{
      made: r.made,
      law_start: r.start,
      windsor: Windsor.listed?(r.law),
      eu: String.starts_with?(r.law, "UK_eu"),
      made_of: made_of,
      existed: &Existence.existed?(base, &1, r.changes, r.valid)
    }
  end

  # each law credited, by its making (an SI) or enactment (an Act)
  defp made_of(rows) do
    laws =
      rows
      |> Enum.flat_map(fn r -> Enum.flat_map(r.periods, &List.wrap(&1.changed_by)) end)
      |> Enum.uniq()

    %{rows: found} =
      Repo.query!(
        "SELECT name, coalesce(md_made_date, md_enactment_date) FROM uk_lrt WHERE name = ANY($1)",
        [laws]
      )

    Map.new(found, fn [l, d] -> {l, d} end)
  end

  defp known do
    case File.read(@known) do
      {:ok, text} ->
        ~r/^\| (UK_[^ |]+) \|/m |> Regex.scan(text) |> Enum.map(&List.last/1) |> MapSet.new()

      _ ->
        MapSet.new()
    end
  end
end
