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
      mix lat.label_shadow --family F --strata --sample DIR --seed N   # the check's draw (CV-06)

  `--strata` draws the switch-over check's sample (Jason 2026-10-31): `--per`
  rows (15) of each cause with at least `--min` rows (50), and `--small`
  rows (30) from the smaller causes pooled, written to DIR as agent
  batches of about `--batch` rows (30): `b1.json`, `b2.json` … The draw is
  `Measures.Draw.shuffled` per cause, in cause order, after one seed.
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
        strict: [
          family: :string,
          cause: :string,
          sample: :string,
          n: :integer,
          seed: :integer,
          strata: :boolean,
          per: :integer,
          min: :integer,
          small: :integer,
          batch: :integer
        ]
      )

    family = opts[:family] || Mix.raise(@usage)
    if opts[:sample] && !opts[:cause] && !opts[:strata], do: Mix.raise(@usage)

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

    cond do
      opts[:strata] && opts[:sample] -> strata(rows, opts[:sample], opts)
      path = opts[:sample] -> sample(rows, opts[:cause], path, opts)
      true -> :ok
    end
  end

  defp strata(rows, dir, opts) do
    {per, min, small} = {opts[:per] || 15, opts[:min] || 50, opts[:small] || 30}
    seed = opts[:seed] || 1
    Draw.seed({seed, 6, 6})

    by_cause =
      rows
      |> Enum.filter(fn {_, _, _, c} -> c != nil end)
      |> Enum.group_by(fn {_, _, _, c} -> c end)

    {big, little} = Enum.split_with(by_cause, fn {_, rs} -> length(rs) >= min end)
    key = fn {law, r, _, _} -> {law, r.id} end

    drawn =
      Enum.flat_map(Enum.sort(big), fn {_, rs} -> Draw.shuffled(rs, per, key) end) ++
        (little |> Enum.flat_map(&elem(&1, 1)) |> Draw.shuffled(small, key))

    File.mkdir_p!(dir)

    drawn
    |> Enum.with_index(1)
    |> Enum.map(fn {{law, r, new, c}, i} -> item(i, law, r, new, c) end)
    |> Enum.chunk_every(opts[:batch] || 30)
    |> Enum.with_index(1)
    |> Enum.each(fn {items, b} ->
      File.write!(Path.join(dir, "b#{b}.json"), Jason.encode!(items, pretty: true))
    end)

    Mix.shell().info(
      "strata: #{length(drawn)} rows (#{length(big)} causes × #{per}, #{small} from #{length(little)} small causes; seed #{seed}) → #{dir}"
    )
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
