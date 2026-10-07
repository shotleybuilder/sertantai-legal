defmodule Mix.Tasks.Clml.Fetch do
  @moduledoc """
  Fill the local CLML store (#175, `LegislationGovUk.ClmlStore`) with the
  documents LAT is parsed from: each law's body, or its scoped fragments
  (`LatScope`). Excluded laws are skipped.

      mix clml.fetch                       # every law holding LAT
      mix clml.fetch --laws A,B
      mix clml.fetch --limit 50
      mix clml.fetch --refresh             # re-fetch even when a fresh copy is stored

  Fetches go through `Client.fetch_xml/2` with `store: :prefer`, so a law
  whose stored copy is fresh (stored dct:valid ≥ its `md_dct_valid_date`)
  makes no request: a re-run resumes where an interrupted one stopped.
  Each document is written as soon as it arrives.
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{IdField, LatScope, LatStagedParser}
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @shortdoc "Fill the local CLML store with LAT source documents"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args, strict: [laws: :string, limit: :integer, refresh: :boolean])

    Mix.Task.run("app.start")
    mode = if opts[:refresh], do: :refresh, else: :prefer

    laws =
      if(opts[:laws], do: String.split(opts[:laws], ",", trim: true), else: laws_with_lat())
      |> then(&if opts[:limit], do: Enum.take(&1, opts[:limit]), else: &1)

    Mix.shell().info(
      "#{length(laws)} laws → #{SertantaiLegal.Scraper.LegislationGovUk.ClmlStore.root()}"
    )

    totals =
      laws
      |> Enum.with_index(1)
      |> Enum.reduce(%{ok: 0, failed: 0}, fn {law, i}, acc ->
        scope = LatScope.get(law)
        store_opts = LatStagedParser.store_opts(law, store: mode)

        results =
          law
          |> IdField.normalize_to_slash_format()
          |> LatScope.paths(scope)
          |> Enum.map(&Client.fetch_xml(&1, store_opts))

        failed = Enum.count(results, &(not match?({:ok, _}, &1)))

        Mix.shell().info(
          "  [#{i}/#{length(laws)}] #{law}: #{length(results)} document(s)#{if failed > 0, do: ", #{failed} failed", else: ""}"
        )

        if failed == 0, do: %{acc | ok: acc.ok + 1}, else: %{acc | failed: acc.failed + 1}
      end)

    Mix.shell().info(
      "\n#{totals.ok} laws stored, #{totals.failed} with a failed fetch (re-run to retry)"
    )
  end

  defp laws_with_lat do
    %{rows: rows} =
      Repo.query!("""
      SELECT name FROM legal_register
      WHERE country = 'uk' AND lat_count > 0
        AND NOT coalesce((lat_scope->>'excluded')::boolean, false)
      ORDER BY name
      """)

    List.flatten(rows)
  end
end
