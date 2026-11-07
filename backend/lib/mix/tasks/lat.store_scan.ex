defmodule Mix.Tasks.Lat.StoreScan do
  @moduledoc """
  A scan of every stored changes-feed effect for one form (`Checks.StoreScan`,
  #192), in place of the store scans written fresh in each session. Prints
  the effects read, and per class the effects and laws; `--examples N`
  prints the first N of each class; `--list FILE` writes every match,
  sorted, one per line (law, effect id, type, class, provisions text).
  `--laws A,B` scans only those laws. Read-only.

      mix lat.store_scan --form bracketed_container
      mix lat.store_scan --form bracketed_container --list data/reports/store-scan/list.tsv

  Forms: #{Enum.map_join(["bracketed_container"], ", ", & &1)}. A form is a
  module under `Checks.StoreScan.Forms` (`Checks.StoreScan.Form`).
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.Checks.StoreScan
  alias SertantaiLegal.Scraper.Checks.StoreScan.Forms.BracketedContainer

  @forms Map.new([BracketedContainer], &{&1.name(), &1})

  @shortdoc "Every stored feed effect through one named form (read-only)"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          form: :string,
          list: :string,
          examples: :integer,
          laws: :string,
          workers: :integer
        ]
      )

    form =
      @forms[opts[:form]] ||
        Mix.raise(
          "usage: mix lat.store_scan --form #{Enum.join(Map.keys(@forms), "|")} [--list FILE]"
        )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    {us, result} =
      :timer.tc(fn ->
        StoreScan.run(form,
          laws: opts[:laws] && String.split(opts[:laws], ",", trim: true),
          workers: opts[:workers]
        )
      end)

    report(result, opts[:examples] || 0)
    Mix.shell().info("scanned in #{Float.round(us / 1_000_000, 1)} s")

    if path = opts[:list] do
      File.write!(path, StoreScan.listing(result.matches))
      Mix.shell().info("#{length(result.matches)} matches → #{path}")
    end
  end

  defp report(result, examples) do
    shell = Mix.shell()
    shell.info("#{result.effects} effects")

    for {class, {n, laws}} <- Enum.sort(result.classes) do
      shell.info("  #{class}: #{n} effects in #{laws} laws")

      for m <- result.matches |> Enum.filter(&(elem(&1, 3) == class)) |> Enum.take(examples),
          do: shell.info("    " <> (m |> Tuple.to_list() |> Enum.join(" | ")))
    end

    for {law, why} <- result.failed, do: shell.info("  not read: #{law} #{inspect(why)}")
  end
end
