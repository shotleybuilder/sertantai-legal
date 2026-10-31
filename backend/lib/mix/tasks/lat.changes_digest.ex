defmodule Mix.Tasks.Lat.ChangesDigest do
  @moduledoc """
  Each law's stored changes as a digest (CV-S11, `ChangeDigest`), for "same
  input, same output": write the digests, rebuild, write them again and
  compare the files (`cmp`). One line per law, sorted: the law, its digest
  and its number of changes. Read-only.

      mix lat.changes_digest --family "OH&S: Occupational" --golden --out A.tsv
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeDigest
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source

  @shortdoc "Each law's stored changes as a digest, to compare two builds (read-only)"

  @usage "usage: mix lat.changes_digest [--family F] [--golden] --out FILE"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [family: :string, golden: :boolean, out: :string])

    out = opts[:out] || Mix.raise(@usage)
    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws =
      ((opts[:family] && Source.family_laws(opts[:family])) || [])
      |> Enum.concat(if opts[:golden], do: Source.golden_laws(), else: [])
      |> Enum.uniq()
      |> Enum.sort()

    if laws == [], do: Mix.raise(@usage)

    lines =
      for law <- laws do
        changes = Source.changes(law)
        "#{law}\t#{ChangeDigest.of(changes)}\t#{length(changes)}\n"
      end

    File.write!(out, lines)
    Mix.shell().info("#{length(laws)} laws' digests written to #{out}")
  end
end
