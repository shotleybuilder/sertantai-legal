defmodule Mix.Tasks.Lat.LabelSwitch do
  @shortdoc "A family's switch to the change vocabulary's labels: dry run (default) or apply"
  @moduledoc """
  The CV-06 switch-over for one family (`ChangeVocabulary.LabelSwitch`).

      mix lat.label_switch --family "OH&S: Occupational / Personal Safety"            # dry run: writes nothing
      mix lat.label_switch --family F --out PATH                                      # dry run, its per-law csv to PATH
      mix lat.label_switch --family F --stored                                        # after the apply: against the stored timeline
      mix lat.label_switch --family F --stored --rows PATH                            # and each moved provision to PATH (tsv)
      mix lat.label_switch --family F --laws L1,L2 [--apply]                          # only these of the family's laws
      mix lat.label_switch --family "OH&S: Occupational / Personal Safety" --apply    # write (restore point of lat_label_timeline first)

  The dry run folds each law's stored changes (`mix lat.vocabulary --build`
  first) and compares them with the register's timeline
  (`LabelSwitchReport`): periods each way, rows differing, today's status
  counts, any law that can't be folded or breaks the table's rules. Its
  per-law lines go to `--out`, else
  `data/reports/change-vocabulary/dry-run-<family>.csv` (one file a family:
  CV-06's committed `cv-06-dry-run.csv` is never overwritten).

  `--stored` compares the switch's rows with the stored timeline
  (`LabelSwitch.stored/1`) instead of the old register, every field the
  switch writes (`changed_by_all`, `commenced_by` too): after the apply,
  each law written shows 0 differing, known limits included (they keep
  their stored rows). Its csv is `dry-run-<family>-stored.csv`.

  `--rows PATH` writes each moved provision as a tab-separated line
  (`LabelSwitchReport.rows/5`, `tsv/1`): the law, the provision, today's
  status each way, the fields that differ, and both periods (Fire and
  OH&S, Labels side by side: a switched family's refold explained group
  by group). `--laws` keeps only the named laws of the family.

  `--apply` refreshes each law through `LabelRefresh.run/2` with the family
  switched — the one write path — and needs the family in the
  `:label_families` setting (config), so later parses keep it.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.{LabelProjection, LabelRefresh, LabelTimeline, LawRunner}
  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelSwitch, LabelSwitchReport}

  @csv_dir "data/reports/change-vocabulary"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          apply: :boolean,
          out: :string,
          stored: :boolean,
          rows: :string,
          laws: :string
        ]
      )

    family = opts[:family] || Mix.raise("usage: mix lat.label_switch --family F [--apply]")
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)
    laws = family |> PatternSource.family_laws() |> only(opts[:laws])

    if opts[:apply],
      do: apply_switch(family, laws),
      else: dry_run(laws, opts[:out] || csv(family, opts[:stored]), opts)
  end

  # `--laws`: the named laws, each one of the family's
  defp only(laws, nil), do: laws

  defp only(laws, names) do
    named = names |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
    missing = named -- laws
    missing == [] || Mix.raise("not in the family: #{Enum.join(missing, ", ")}")
    Enum.filter(laws, &(&1 in named))
  end

  # the family's own dry-run file: "OH&S: Occupational / Personal Safety" →
  # dry-run-oh-s-occupational-personal-safety.csv
  defp csv(family, stored?) do
    slug = family |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    Path.join(@csv_dir, "dry-run-#{slug}#{if stored?, do: "-stored"}.csv")
  end

  defp dry_run(laws, csv, opts) do
    results = fold_all(laws, opts[:stored] == true)
    reports = for {:ok, {r, _moved}} <- results, do: r
    errors = for {:error, law, why} <- results, do: {law, why}
    t = LabelSwitchReport.total(reports)

    Mix.shell().info(
      "#{t.laws} laws folded, #{length(errors)} not; #{t.rows} rows, #{t.differ} differ; " <>
        "periods #{t.periods_old} → #{t.periods_new}"
    )

    Mix.shell().info("today (old): #{inspect(t.today_old)}")
    Mix.shell().info("today (new): #{inspect(t.today_new)}")
    for {law, why} <- errors, do: Mix.shell().info("  not folded: #{law} #{inspect(why)}")

    File.mkdir_p!(Path.dirname(csv))

    File.write!(
      csv,
      [
        "law,rows,periods_old,periods_new,differ\n"
        | for(
            r <- reports,
            do: "#{r.law},#{r.rows},#{r.periods_old},#{r.periods_new},#{r.differ}\n"
          )
      ]
    )

    Mix.shell().info("per law: #{csv}")
    write_rows(opts[:rows], for({:ok, {_r, moved}} <- results, do: moved))
  end

  # several laws at once (`LawRunner`'s guard), the results in the laws'
  # order (#191); a law that raises is not folded, as `{:error, why}` is
  defp fold_all(laws, stored?) do
    today = LabelProjection.uk_today()
    by_law = LawRunner.run(laws, &dry_run_law(&1, today, stored?), fn _, _ -> :ok end)

    for law <- laws do
      case by_law[law] do
        {:ok, _} = ok -> ok
        {:error, ^law, _} = error -> error
        {:error, why} -> {:error, law, why}
      end
    end
  end

  defp write_rows(nil, _moved), do: :ok

  defp write_rows(path, moved) do
    File.mkdir_p!(Path.dirname(path))
    rows = List.flatten(moved)
    File.write!(path, LabelSwitchReport.tsv(rows))
    Mix.shell().info("#{length(rows)} moved rows: #{path}")
  end

  defp dry_run_law(law, today, stored?) do
    {old, compared} = against(law, today, stored?)

    case LabelSwitch.timeline(law, old) do
      {:ok, new} ->
        {:ok,
         {LabelSwitchReport.law(law, old, new, today, compared),
          LabelSwitchReport.rows(law, old, new, today, compared)}}

      {:error, why} ->
        {:error, law, why}
    end
  end

  # the stored timeline (after the apply), else the old register's
  defp against(law, _today, true), do: {LabelSwitch.stored(law), :written}

  defp against(law, today, false) do
    %{periods: old} = LabelTimeline.build(law, today)
    {old, :register}
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
