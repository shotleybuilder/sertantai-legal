defmodule Mix.Tasks.Lat.ExtentCensus do
  @moduledoc """
  The whole-reader census (CV-S05d) as one task (#192), in place of the
  run folders' `dump.exs` → `census.py` → `bench.py` (and `rdiff.py`).
  Writes, to `--out DIR`:

  - `input.jsonl.gz`: every held law's stored extent reading
    (`Checks.ExtentCensus.Dump`), unless `--from`;
  - `sentences.tsv`, `scope.tsv`, `unnamed.tsv`, `stats.json`: each
    sentence's verdicts, apply statements of scope, stored refs no
    statement names, and the counts (`Checks.ExtentCensus`);
  - `bench.txt`: the recall bench (`ExtentCensus.Bench`);
  - `reading_diff.txt` with `--diff OLD`: per law, how the reading
    changed from an older dump (`ExtentCensus.ReadingDiff`).

  `--from FILE` reads a dump (`.jsonl` or `.jsonl.gz`) in place of a
  fresh one. `--laws A,B` dumps only those laws. `--structures FILE`
  reads the laws' structures from a frozen JSON file in place of the
  CLML store. The outputs are the Python scripts', byte for byte
  (`ExtentCensusTest`). Read-only but for DIR.

      mix lat.extent_census --out data/reports/extent-census/run-08
      mix lat.extent_census --out DIR --from data/experiments/cv-s05d-whole-reader-census/run-07/input.jsonl.gz
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Checks.ExtentCensus
  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{Bench, Dump, ReadingDiff, Structure}

  @shortdoc "Whole-reader extent census: verdicts, scope, unnamed refs, recall bench"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [out: :string, from: :string, laws: :string, diff: :string, structures: :string]
      )

    out =
      opts[:out] ||
        Mix.raise(
          "usage: mix lat.extent_census --out DIR [--from FILE] [--laws A,B] [--diff OLD] [--structures FILE]"
        )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)
    File.mkdir_p!(out)

    lines = timed("dump", fn -> input(opts, out) end)
    laws = Enum.map(lines, &Jason.decode!/1)
    structure = structures(opts[:structures])

    r = timed("census", fn -> ExtentCensus.run(laws, structure) end)
    for k <- [:sentences, :scope, :unnamed], do: write(out, "#{k}.tsv", r[k])
    write(out, "stats.json", r.stats)
    Mix.shell().info(r.stats)

    by_law = Map.new(laws, &{&1["law"], &1})
    bench(by_law, structure, out)
    if old = opts[:diff], do: diff(old, by_law, out)
  end

  defp input(opts, out) do
    case opts[:from] do
      nil ->
        laws = if l = opts[:laws], do: String.split(l, ",", trim: true)
        {lines, n} = Dump.run(laws)
        write(out, "input.jsonl.gz", :zlib.gzip(Enum.map(lines, &[&1, "\n"])))
        Mix.shell().info("#{n} laws, #{length(lines)} read")
        lines

      path ->
        read_lines(path)
    end
  end

  defp read_lines(path), do: path |> read() |> String.split("\n", trim: true)

  defp read(path) do
    bin = File.read!(path)
    if String.ends_with?(path, ".gz"), do: :zlib.gunzip(bin), else: bin
  end

  defp structures(nil), do: :store

  defp structures(path),
    do:
      path
      |> read()
      |> Jason.decode!()
      |> Map.new(fn {law, m} -> {law, Structure.from_map(m)} end)

  defp bench(by_law, structure, out) do
    case Enum.reject(Bench.laws(), &Map.has_key?(by_law, &1)) do
      [] ->
        text = timed("bench", fn -> Bench.run(by_law, structure) end)
        write(out, "bench.txt", text)
        Mix.shell().info(text)

      missing ->
        Mix.shell().info("bench skipped: #{Enum.join(missing, ", ")} not in the dump")
    end
  end

  defp diff(old, by_law, out) do
    old =
      old |> read_lines() |> Map.new(&(&1 |> Jason.decode!() |> then(fn d -> {d["law"], d} end)))

    {text, n} = ReadingDiff.run(old, by_law)
    write(out, "reading_diff.txt", text)
    Mix.shell().info("#{n} laws changed of #{map_size(by_law)}")
  end

  # each phase's wall time, for the record (#192)
  defp timed(phase, fun) do
    {us, result} = :timer.tc(fun)
    Mix.shell().info("#{phase}: #{Float.round(us / 1_000_000, 1)} s")
    result
  end

  defp write(dir, name, iodata), do: File.write!(Path.join(dir, name), iodata)
end
