defmodule Mix.Tasks.Lat.HeldMoves do
  @moduledoc """
  The commencement catalogues' held answers a step's fixes move
  (`StepProcedures.HeldMoves`; WORKFLOW step 4, Settle): each held,
  non-pending example whose reading now differs from `expected.json`, with
  its words, the held reading and the new one.

      mix lat.held_moves                                # both catalogues, dry run
      mix lat.held_moves --catalogue orders             # one (commencement | orders)
      mix lat.held_moves --write                        # writes the moves into expected.json, on Jason's go
      mix lat.held_moves --new                          # the dry run's new patterns (`mix lat.commencement_patterns` / `lat.order_patterns`), dry run
      mix lat.held_moves --new --pending "PATTERN::pending: why" --write   # brings them in, one marked pending

  Writes only with `--write`: the fixtures under `test/fixtures/` (sorted
  keys). The new patterns come from the catalogues' dry-run folder
  (`data/reports/commencement-reader/dry-run/`).
  """
  use Mix.Task

  alias Mix.Tasks.Lat.FeedPatterns, as: Files
  alias SertantaiLegal.Scraper.StepProcedures.{CatalogueReadings, HeldMoves}

  @shortdoc "The commencement catalogues' held answers a step moves (dry run; --write writes)"

  @catalogues %{
    "commencement" => {"commencement_patterns", ~w(patterns examples expected laws), :own},
    "orders" => {"order_patterns", ~w(patterns examples expected), :orders}
  }
  @fixtures "test/fixtures"
  @dry_run "data/reports/commencement-reader/dry-run"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [catalogue: :string, write: :boolean, new: :boolean, pending: :keep]
      )

    Mix.Task.run("app.start")
    names = if c = opts[:catalogue], do: [c], else: ~w(commencement orders)

    for name <- names do
      {dir, files, reader} = Map.get(@catalogues, name) || Mix.raise("unknown catalogue #{name}")
      held = load(Path.join(@fixtures, dir), files)

      if opts[:new],
        do: new(name, dir, files, held, reader, opts),
        else: moves(name, dir, held, reader, opts)
    end
  end

  defp moves(name, dir, held, reader, opts) do
    read = apply(CatalogueReadings, reader, [held["laws"]])
    moves = HeldMoves.moves(held, read)

    Mix.shell().info(
      "#{name}: #{map_size(moves)} of #{map_size(held["examples"])} held answers moved"
    )

    for {id, m} <- Enum.sort(moves), do: print_move(id, held["examples"][id], m)

    if opts[:write] && moves != %{} do
      held |> HeldMoves.write_moves(moves) |> save(Path.join(@fixtures, dir), ["expected"])
      Mix.shell().info("  written: #{dir}/expected.json")
    end
  end

  defp new(name, dir, files, held, reader, opts) do
    dry = load(Path.join(@dry_run, dir), files -- ["expected"])
    statuses = opts |> Keyword.get_values(:pending) |> Map.new(&pending/1)

    {out, summary} =
      HeldMoves.add_new(held, dry, statuses, &apply(CatalogueReadings, reader, [&1]))

    Mix.shell().info(
      "#{name}: #{length(summary.new)} new patterns; emptied, dropped: #{inspect(summary.emptied)}"
    )

    for p <- summary.new, do: Mix.shell().info("  + #{out["expected"]["patterns"][p]}  #{p}")

    if opts[:write] && summary.new != [] do
      save(out, Path.join(@fixtures, dir), files)
      Mix.shell().info("  written: #{dir}/{#{Enum.join(files, ",")}}.json")
    end
  end

  defp pending(arg) do
    case String.split(arg, "::", parts: 2) do
      [p, "pending" <> _ = status] -> {p, status}
      _ -> Mix.raise(~s(--pending takes "PATTERN::pending: why"))
    end
  end

  defp print_move(id, e, %{held: held, now: now}) do
    words = e["sentence"] || get_in(e, ["unit", "text"]) || ""

    where =
      e["row"] || "#{e["order"]} #{get_in(e, ["unit", "id"])} (for #{get_in(e, ["act", "law"])})"

    shell = Mix.shell()
    shell.info("\n## #{id}\n#{where}\n> #{String.slice(words, 0, 700)}")
    shell.info("held (#{held["class"]}):")
    for r <- (held || %{})["rules"] || [], do: shell.info("  - #{inspect(r)}")
    shell.info("new  (#{now["class"]}):")
    for r <- now["rules"] || [], do: shell.info("  - #{inspect(r)}")
  end

  defp load(dir, files) do
    for f <- files, into: %{} do
      case File.read(Path.join(dir, f <> ".json")) do
        {:ok, body} -> {f, Jason.decode!(body)}
        _ -> {f, %{}}
      end
    end
  end

  defp save(out, dir, files),
    do: for(f <- files, do: File.write!(Path.join(dir, f <> ".json"), Files.encode(out[f])))
end
