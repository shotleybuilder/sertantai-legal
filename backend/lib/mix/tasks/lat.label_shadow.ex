defmodule Mix.Tasks.Lat.LabelShadow do
  @moduledoc """
  The switch-over's shadow comparison (CV-06): a family's labels from the
  merged changes (`LabelSource.timeline` rows, `LabelPeriods`) against
  the stored ones, each differing row by cause (`LabelShadow.cause/5`),
  and with `--sample FILE` a reproducible draw of rows of one cause (its
  key, or a prefix of it) for the agent check: each with its old and new
  periods and the changes reaching it. Read-only.

      mix lat.label_shadow --family "OH&S: Occupational"
      mix lat.label_shadow --family F --cause "today: status" --sample FILE --n 20 --seed N
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Amendment.PatternSource
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelPeriods, LabelShadow, LabelSource}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Draw
  alias SertantaiLegal.Scraper.LabelProjection

  @shortdoc "New labels against the stored ones, by cause, with samples (read-only)"

  @usage "usage: mix lat.label_shadow --family F [--cause C --sample FILE --n N --seed S]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [family: :string, cause: :string, sample: :string, n: :integer, seed: :integer]
      )

    family = opts[:family] || Mix.raise(@usage)
    if opts[:sample] && !opts[:cause], do: Mix.raise(@usage)

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)
    today = LabelProjection.uk_today()

    rows =
      for law <- PatternSource.family_laws(family),
          rs = LabelSource.rows(law),
          is_list(rs),
          r <- rs do
        new = LabelPeriods.periods(law, r.sid, r.periods, r.reaching)
        {law, r, new, LabelShadow.cause(law, r.today, new, r.reaching, today)}
      end

    causes = for {_, _, _, c} <- rows, c != nil, do: c
    today_n = Enum.count(causes, &String.starts_with?(&1, "today"))

    Mix.shell().info(
      "#{length(rows)} rows as at #{today}: agree #{length(rows) - length(causes)}, " <>
        "differ today #{today_n}, history only #{length(causes) - today_n}"
    )

    for {c, n} <- causes |> Enum.frequencies() |> Enum.sort_by(fn {c, n} -> {-n, c} end),
        do: Mix.shell().info("  #{n}\t#{c}")

    if path = opts[:sample], do: sample(rows, opts[:cause], path, opts)
  end

  defp sample(rows, cause, path, opts) do
    seed = opts[:seed] || 1
    Draw.seed({seed, 6, 6})

    items =
      rows
      |> Enum.filter(fn {_, _, _, c} -> c != nil and String.starts_with?(c, cause) end)
      |> Draw.shuffled(opts[:n] || 20, fn {law, r, _, _} -> {law, r.id} end)
      |> Enum.with_index(1)
      |> Enum.map(fn {{law, r, new, c}, i} -> item(i, law, r, new, c) end)

    File.write!(path, Jason.encode!(items, pretty: true))
    Mix.shell().info("sample: #{length(items)} rows of \"#{cause}\" (seed #{seed}) → #{path}")
  end

  defp item(i, law, r, new, cause) do
    %{
      n: i,
      law: law,
      section_id: r.sid,
      extent: r.extent,
      law_start: r.start,
      cause: cause,
      old: r.today,
      new: Enum.map(new, &Map.drop(&1, [:law_name, :section_id, :change_ids])),
      changes:
        for c <- r.reaching do
          %{
            key: c.key,
            target: c.target,
            operation: c.resolved.operation,
            level: c.resolved.level,
            date: c.resolved.date,
            by: c.resolved.by,
            commenced_by: c.resolved.commenced_by,
            territory: c.resolved.territory,
            sources: c.claims |> Enum.map(& &1.source) |> Enum.uniq()
          }
        end
    }
  end
end
