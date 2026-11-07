defmodule Mix.Tasks.Lat.ExtentShapes do
  @moduledoc """
  Extent shape mining (CV-S05c) as one task (#192), in place of the
  run folders' `dump.exs` → `mine.py` → `verdicts.exs` → `review.py` →
  `overreach.exs` → `defaults.exs`. Writes, to `--out DIR`:

  - `sentences.tsv`: every held law's extent sentences with the reader's
    class (`Checks.ExtentShapes.Dump`);
  - `items.tsv`, `shapes.tsv`, `stats.json`: each sentence's lead and
    lettered items masked into shapes, ranked and counted (`Mine`);
  - `verdicts.tsv`: whether the reader holds what each list item names
    (`Verdicts`);
  - `review.tsv`, `review.json`: each shape's bucket for review (`Review`);
  - `overreach.tsv`: held provisions an item excludes, qualifies or
    scopes (`Overreach`);
  - `defaults.tsv`: default sentences' items whose provisions no list
    holds (`Defaults`).

  `--from DIR` takes DIR's `sentences.tsv` in place of a fresh dump.
  `--laws A,B` dumps only those laws. The outputs are the Python
  pipeline's, byte for byte (`ExtentShapesTest`). Read-only but for DIR.

      mix lat.extent_shapes --out data/reports/extent-shapes/run-04
      mix lat.extent_shapes --out DIR --from data/experiments/cv-s05c-shape-mining/run-03
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Checks.ExtentShapes.{
    Defaults,
    Dump,
    Mine,
    Overreach,
    Review,
    Verdicts
  }

  @shortdoc "Extent shape mining: sentences, shapes, verdicts, review, over-reach, defaults"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [out: :string, from: :string, laws: :string])

    out =
      opts[:out] || Mix.raise("usage: mix lat.extent_shapes --out DIR [--from DIR] [--laws A,B]")

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)
    File.mkdir_p!(out)

    sentences = timed("dump", fn -> sentences(opts) end)
    write(out, "sentences.tsv", sentences)

    mined = timed("mine", fn -> Mine.run(sentences) end)
    write(out, "items.tsv", mined.items)
    write(out, "shapes.tsv", mined.shapes)
    write(out, "stats.json", mined.stats)
    Mix.shell().info(IO.iodata_to_binary(mined.stats))

    items = IO.iodata_to_binary(mined.items)
    {verdicts, laws, n} = timed("verdicts", fn -> Verdicts.run(items) end)
    write(out, "verdicts.tsv", verdicts)
    Mix.shell().info("#{laws} laws, #{n} items")

    reviewed = timed("review", fn -> Review.run(items, verdicts) end)
    write(out, "review.tsv", reviewed.review)
    write(out, "review.json", reviewed.summary)
    Mix.shell().info(IO.iodata_to_binary(reviewed.summary))

    {overreach, laws, n} = timed("overreach", fn -> Overreach.run(items) end)
    write(out, "overreach.tsv", overreach)
    Mix.shell().info("#{laws} laws, #{n} over-reach findings")

    {defaults, sents, n} = timed("defaults", fn -> Defaults.run(sentences) end)
    write(out, "defaults.tsv", defaults)

    Mix.shell().info(
      "#{sents} default sentences with a dash; #{n} items with provisions in no list"
    )
  end

  defp sentences(opts) do
    case opts[:from] do
      nil ->
        laws = if l = opts[:laws], do: String.split(l, ",", trim: true)
        {tsv, n} = Dump.run(laws)
        Mix.shell().info("#{n} laws dumped")
        tsv

      dir ->
        File.read!(Path.join(dir, "sentences.tsv"))
    end
  end

  # each phase's wall time, for the record (#192)
  defp timed(phase, fun) do
    {us, result} = :timer.tc(fun)
    Mix.shell().info("#{phase}: #{Float.round(us / 1_000_000, 1)} s")
    result
  end

  defp write(dir, name, iodata), do: File.write!(Path.join(dir, name), iodata)
end
