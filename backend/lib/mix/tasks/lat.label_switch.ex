defmodule Mix.Tasks.Lat.LabelSwitch do
  @shortdoc "A family's switch to the change vocabulary's labels: dry run (default) or apply"
  @moduledoc """
  The CV-06 switch-over for one family (`ChangeVocabulary.LabelSwitch`).

      mix lat.label_switch --family "OH&S: Occupational / Personal Safety"            # dry run: writes nothing
      mix lat.label_switch --family "OH&S: Occupational / Personal Safety" --apply    # write (restore point of lat_label_timeline first)

  The dry run folds each law's stored changes (`mix lat.vocabulary --build`
  first) and compares them with the register's timeline
  (`LabelSwitchReport`): periods each way, rows differing, today's status
  counts, any law that can't be folded or breaks the table's rules. Its
  per-law lines go to `data/reports/change-vocabulary/cv-06-dry-run.csv`.

  `--apply` refreshes each law through `LabelRefresh.run/2` with the family
  switched — the one write path — and needs the family in the
  `:label_families` setting (config), so later parses keep it.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.{LabelProjection, LabelRefresh, LabelTimeline}
  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelSwitch, LabelSwitchReport}

  @csv "data/reports/change-vocabulary/cv-06-dry-run.csv"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [family: :string, apply: :boolean])
    family = opts[:family] || Mix.raise("usage: mix lat.label_switch --family F [--apply]")
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)
    laws = PatternSource.family_laws(family)

    if opts[:apply], do: apply_switch(family, laws), else: dry_run(laws)
  end

  defp dry_run(laws) do
    today = LabelProjection.uk_today()

    results =
      for law <- laws do
        %{periods: old} = LabelTimeline.build(law, today)

        case LabelSwitch.timeline(law, old) do
          {:ok, new} -> {:ok, LabelSwitchReport.law(law, old, new, today)}
          {:error, why} -> {:error, law, why}
        end
      end

    reports = for {:ok, r} <- results, do: r
    errors = for {:error, law, why} <- results, do: {law, why}
    t = LabelSwitchReport.total(reports)

    Mix.shell().info(
      "#{t.laws} laws folded, #{length(errors)} not; #{t.rows} rows, #{t.differ} differ; " <>
        "periods #{t.periods_old} → #{t.periods_new}"
    )

    Mix.shell().info("today (old): #{inspect(t.today_old)}")
    Mix.shell().info("today (new): #{inspect(t.today_new)}")
    for {law, why} <- errors, do: Mix.shell().info("  not folded: #{law} #{inspect(why)}")

    File.write!(
      @csv,
      [
        "law,rows,periods_old,periods_new,differ\n"
        | for(
            r <- reports,
            do: "#{r.law},#{r.rows},#{r.periods_old},#{r.periods_new},#{r.differ}\n"
          )
      ]
    )

    Mix.shell().info("per law: #{@csv}")
  end

  defp apply_switch(family, laws) do
    LabelSwitch.family_in?(family, LabelSwitch.families()) ||
      Mix.raise("#{family} is not in the :label_families setting: set it (config) first")

    failed =
      for law <- laws, LabelRefresh.run(law) != :ok, do: law

    Mix.shell().info("#{length(laws) - length(failed)} laws written, #{length(failed)} failed")
    for law <- failed, do: Mix.shell().info("  failed: #{law}")
  end
end
