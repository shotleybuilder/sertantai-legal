defmodule Mix.Tasks.Lat.FetchEffects do
  @moduledoc """
  Fetch the changes-affected feed (every effect) of each law holding LAT into
  the local store, so the effects layer is measured and applied offline
  (lat-refactor LR-03). One request per law (5,000 effects a page); a law
  already stored and fresh (fetched within 30 days) is not fetched again.

      mix lat.fetch_effects                      # every law holding LAT
      mix lat.fetch_effects --laws UK_ukpga_1990_43,UK_uksi_1996_972
      mix lat.fetch_effects --store refresh      # re-fetch even when fresh

  Written as it goes: one line per law to `--log` (default
  `data/reports/lat-refactor/fetch-effects.log`): law, effects, result.
  Re-running resumes — stored laws come from the store.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @shortdoc "Fetch changes-affected feeds of LAT laws into the local store"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [laws: :string, store: :string, log: :string])
    Mix.Task.run("app.start")

    log = opts[:log] || Path.join(["data", "reports", "lat-refactor", "fetch-effects.log"])
    File.mkdir_p!(Path.dirname(log))

    store =
      case opts[:store] || "prefer" do
        m when m in ~w(prefer refresh only) -> String.to_atom(m)
        m -> Mix.raise("--store must be prefer, refresh or only, got #{m}")
      end

    laws = if opts[:laws], do: String.split(opts[:laws], ",", trim: true), else: laws_with_lat()
    Mix.shell().info("#{length(laws)} laws (store: #{store}) → #{log}")

    totals =
      Enum.reduce(laws, %{ok: 0, error: 0, effects: 0}, fn law, acc ->
        [_uk, type, year, number] = String.split(law, "_", parts: 4)

        case ChangesFeed.fetch(type, year, number, store: store) do
          {:ok, effects} ->
            File.write!(log, "#{law}\t#{length(effects)}\tok\n", [:append])
            %{acc | ok: acc.ok + 1, effects: acc.effects + length(effects)}

          {:error, reason} ->
            File.write!(log, "#{law}\t0\terror: #{reason}\n", [:append])
            Mix.shell().error("  #{law}: #{reason}")
            %{acc | error: acc.error + 1}
        end
      end)

    Mix.shell().info("#{totals.ok} laws, #{totals.effects} effects, #{totals.error} errors")
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("""
      SELECT name FROM legal_register
      WHERE country = 'uk' AND lat_count > 0 AND NOT coalesce((lat_scope->>'excluded')::boolean, false)
      ORDER BY name
      """)

    List.flatten(rows)
  end
end
