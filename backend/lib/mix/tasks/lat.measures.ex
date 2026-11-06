defmodule Mix.Tasks.Lat.Measures do
  @moduledoc """
  The change vocabulary's coverage figures for a family or the golden
  laws, from the stored changes (CV-S10; `ChangeVocabulary.Measures`):

  - who states each text change (CV-07: `stated_by_law_and_derived`,
    law only, derived only);
  - the law-text coverage table (CV-S06);
  - what dates each text change (CV-S08).

  The territory table (CV-S05) is printed by `mix lat.extent_check`; the
  pass bounds by `mix lat.verdicts`. Read-only.

      mix lat.measures --family "OH&S: Occupational"
      mix lat.measures --golden [--extended]
      mix lat.measures --family F --sample FILE --n 50 --seed S   # the hand-check sample

  `--sample` writes the hand-check sample (`Measures.HandSample`): text
  changes drawn on the seed, each with the classes the measures give it.
  """
  use Mix.Task

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.{Coverage, HandSample, Source}

  @shortdoc "The change vocabulary's coverage figures for a family or the golden laws (read-only)"

  @usage "usage: mix lat.measures --family F | --golden [--extended] [--sample FILE --n N --seed S]"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          family: :string,
          golden: :boolean,
          extended: :boolean,
          sample: :string,
          n: :integer,
          seed: :integer
        ]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    {what, laws} =
      cond do
        opts[:family] -> {"family #{opts[:family]}", Source.family_laws(opts[:family])}
        opts[:golden] -> {"golden laws", Source.golden_laws(opts[:extended] || false)}
        true -> Mix.raise(@usage)
      end

    by_law =
      Enum.map(laws, fn law ->
        changes = Source.changes(law)
        {law, changes, Source.conflicts(changes)}
      end)

    changes = Enum.flat_map(by_law, &elem(&1, 1))
    conflicts = Enum.flat_map(by_law, &elem(&1, 2))

    split = Coverage.stated_by_split(changes)
    table = Coverage.law_text_coverage(changes, conflicts)
    dating = Coverage.dating(changes)

    IO.puts("""
    #{what}: #{length(laws)} laws, #{length(changes)} stored changes, #{split.total} text changes

    who states a text change (from its operation's claims):
    #{rows(split, ~w(law_and_derived law_only derived_only none)a, split.total)}

    law-text coverage (CV-S06's table):
    #{rows(table, ~w(law_and_derived law_only read_no_rule_schedule read_no_rule_eu_article read_no_rule_body not_read other)a, table.total)}

    what dates a text change (CV-S08):
    #{rows(dating, ~w(undated dated_no_commenced_by commenced_by_named)a, dating.total)}\
    """)

    if path = opts[:sample], do: sample(by_law, path, opts)
  end

  defp sample(by_law, path, opts) do
    seed = opts[:seed] || 1
    population = HandSample.population(by_law)
    items = HandSample.draw(population, opts[:n] || 50, seed)
    File.write!(path, Jason.encode!(items, pretty: true))

    IO.puts(
      "\nsample: #{length(items)} of #{length(population)} text changes (seed #{seed}) → #{path}"
    )
  end

  defp rows(counts, keys, total) do
    Enum.map_join(keys, "\n", fn k ->
      n = Map.fetch!(counts, k)
      "  #{String.pad_leading(to_string(n), 6)}  #{pct(n, total)}  #{k}"
    end)
  end

  defp pct(_n, 0), do: "   n/a"

  defp pct(n, total),
    do: String.pad_leading(:erlang.float_to_binary(100 * n / total, decimals: 1) <> "%", 6)
end
