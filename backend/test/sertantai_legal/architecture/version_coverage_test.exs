defmodule SertantaiLegal.Architecture.VersionCoverageTest do
  @moduledoc """
  A version hash (`SourceVersion`) says when stored results are stale, so
  it must cover every module its files reach that shapes what they read —
  else a change to that module leaves stale results looking current
  (run time, 2026-10-25: `ChangeVocabulary.Version` missed the LawStart
  readers). Reach is followed through module references in the compiled
  code; I/O modules (the repo, the HTTP client, the CLML store, the staged
  parser's effects loading, the enabling cache) are allowed, the inputs
  they serve being fingerprinted on their own (`FeedCache`, the stores).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach

  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
    lib/sertantai_legal/scraper/lat_staged_parser.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
  )

  for version <- [
        SertantaiLegal.Scraper.ChangeVocabulary.Version,
        SertantaiLegal.Scraper.Amendment.ReaderVersion,
        SertantaiLegal.Scraper.LegislationGovUk.FeedVersion,
        SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion
      ] do
    test "#{inspect(version)} covers every module its files reach" do
      covered = unquote(version).files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()

      missing =
        covered
        |> MapSet.to_list()
        |> ModuleReach.reach(@io)
        |> MapSet.difference(covered)
        |> Enum.reject(&(&1 in @io))

      assert missing == [],
             "#{inspect(unquote(version))} misses (add to its patterns, or to @io if it only fetches or stores):\n  " <>
               Enum.join(missing, "\n  ")
    end
  end
end
