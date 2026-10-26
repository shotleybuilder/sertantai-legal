defmodule Mix.Tasks.Lat.ExtentSweep do
  @moduledoc """
  The extent recall sweep (CV-S05a): every sentence of the held laws' own
  words that may say where their provisions extend or apply and that the
  extent catalogue doesn't class (`Extent.Sweep`), clustered by shape and
  counted — the wordings outside the reader's vocabulary, found by count,
  not by sampling.

  Read-only (the reading kept between runs: `Extent.ReadCache`). Writes,
  under `--out` (default `data/extent_sweep`):

  - `clusters.json`: each shape with its count, laws, nets, first guess
    (`Sweep.group/1`) and examples, most first;
  - `sentences.tsv`: every uncaught sentence (law, ref, net, group, shape,
    sentence).

  Prints the totals by group and net, and the largest clusters.

      mix lat.extent_sweep
      mix lat.extent_sweep --family "OH&S: Occupational"   # the family's amending laws only
      mix lat.extent_sweep --laws UK_ukpga_2003_39,UK_ukpga_2007_28
  """
  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ReadCache, Sweep}
  alias SertantaiLegal.Scraper.LawRunner
  alias SertantaiLegal.Scraper.LawRunner.Guard

  @shortdoc "Extent-ish sentences the extent catalogue doesn't class, clustered and counted (read-only)"

  @dir "data/extent_sweep"
  @examples 5
  @shown 40

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [laws: :string, family: :string, out: :string, workers: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    laws = laws(opts)
    Mix.shell().info("#{length(laws)} laws")
    counter = :counters.new(1, [])

    results =
      LawRunner.run(
        laws,
        fn law ->
          case ReadCache.law(law) do
            nil -> []
            r -> r.uncaught
          end
        end,
        fn _law, _ ->
          :counters.add(counter, 1, 1)
          i = :counters.get(counter, 1)
          if rem(i, 250) == 0, do: Mix.shell().info("  #{i}/#{length(laws)}")
        end,
        workers: Guard.workers(workers: opts[:workers])
      )

    rows =
      for law <- laws,
          uncaught = results[law],
          is_list(uncaught),
          {ref, s, net} <- uncaught,
          do: %{
            law: law,
            ref: ref,
            net: net,
            sentence: s,
            shape: Sweep.shape(s),
            group: Sweep.group(s)
          }

    errors = for law <- laws, not is_list(results[law]), do: law
    clusters = clusters(rows)
    dir = opts[:out] || @dir
    write(dir, rows, clusters, length(laws))
    report(rows, clusters, errors, dir)
  end

  defp laws(opts) do
    cond do
      opts[:laws] ->
        String.split(opts[:laws], ",", trim: true)

      opts[:family] ->
        held = MapSet.new(ReadCache.held())

        Repo.query!(
          """
          SELECT DISTINCT c.by FROM provision_changes c
          JOIN uk_lrt l ON l.name = c.law_name
          WHERE l.family LIKE '%' || $1 || '%' AND c.by IS NOT NULL ORDER BY 1
          """,
          [opts[:family]]
        ).rows
        |> List.flatten()
        |> Enum.filter(&MapSet.member?(held, &1))

      true ->
        ReadCache.held()
    end
  end

  # one cluster per shape, the largest first
  defp clusters(rows) do
    rows
    |> Enum.group_by(& &1.shape)
    |> Enum.map(fn {shape, rs} ->
      %{
        shape: shape,
        count: length(rs),
        laws: rs |> Enum.map(& &1.law) |> Enum.uniq() |> length(),
        nets: rs |> Enum.map(& &1.net) |> Enum.frequencies(),
        group:
          rs |> Enum.map(& &1.group) |> Enum.frequencies() |> Enum.max_by(&elem(&1, 1)) |> elem(0),
        examples: rs |> Enum.take(@examples) |> Enum.map(&Map.take(&1, [:law, :ref, :sentence]))
      }
    end)
    |> Enum.sort_by(&{-&1.count, &1.shape})
  end

  defp write(dir, rows, clusters, n_laws) do
    File.mkdir_p!(dir)

    File.write!(
      Path.join(dir, "clusters.json"),
      Jason.encode!(
        %{
          laws: n_laws,
          sentences: length(rows),
          laws_with: rows |> Enum.map(& &1.law) |> Enum.uniq() |> length(),
          clusters: clusters
        },
        pretty: true
      )
    )

    tsv =
      for r <- rows,
          into: "law\tref\tnet\tgroup\tshape\tsentence\n",
          do:
            Enum.map_join(
              [r.law, r.ref, r.net, r.group, r.shape, r.sentence],
              "\t",
              &String.replace(&1, ~r/[\t\n]/u, " ")
            ) <> "\n"

    File.write!(Path.join(dir, "sentences.tsv"), tsv)
  end

  defp report(rows, clusters, errors, dir) do
    shell = Mix.shell()
    laws_with = rows |> Enum.map(& &1.law) |> Enum.uniq() |> length()

    shell.info(
      "\nuncaught: #{length(rows)} sentences in #{laws_with} laws, #{length(clusters)} shapes"
    )

    for {label, key} <- [{"by group", :group}, {"by net", :net}] do
      shell.info("\n#{label}:")

      rows
      |> Enum.frequencies_by(&Map.fetch!(&1, key))
      |> Enum.sort_by(&(-elem(&1, 1)))
      |> Enum.each(fn {k, n} -> shell.info("  #{String.pad_leading(to_string(n), 5)}  #{k}") end)
    end

    shell.info("\nlargest clusters:")

    for c <- Enum.take(clusters, @shown) do
      shell.info(
        "  #{String.pad_leading(to_string(c.count), 4)} (#{c.laws} laws, #{c.group})  #{c.shape}"
      )
    end

    if errors != [], do: shell.info("\nerrors: #{Enum.join(errors, ", ")}")
    shell.info("\nwritten: #{dir}/clusters.json, #{dir}/sentences.tsv")
  end
end
