defmodule SertantaiLegal.Architecture.AmendmentReadStampsTest do
  @moduledoc """
  The Amending-law reader's stamps hold exactly the code each depends on
  (the Amending-law reader stamps session, 2026-11-26; until then globs,
  missing the read path's own files and listing three it never reached):

  - `ReaderVersion`: what the read pass's reading reaches
    (`Amendment.ReadLaw`: the provisions read, the rules), recorded in
    each amending law's index;
  - `CatalogueVersion`: what the catalogue's reading reaches
    (`Amendment.CatalogueRead`), its cache's key.

  Reach as in `ExtentReadStampsTest`: the IO modules, the store, the
  index, the read pass, the cache and every stamp are where a path ends.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach
  alias SertantaiLegal.Scraper.Amendment.{CatalogueVersion, ReaderVersion}

  @a "lib/sertantai_legal/scraper/amendment/"
  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
    lib/sertantai_legal/scraper/lat_staged_parser.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
    lib/sertantai_legal/scraper/source_version.ex
  )

  defp stamps do
    {:ok, mods} = :application.get_key(:sertantai_legal, :modules)

    for m <- mods, function_exported?(m, :fresh?, 0) do
      m.module_info(:compile)[:source] |> to_string() |> Path.relative_to_cwd()
    end
  end

  defp stops, do: @io ++ ReaderVersion.boundaries() ++ stamps()

  defp files(version), do: version.files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()

  defp reach(entries),
    do:
      entries
      |> Enum.map(&(@a <> &1))
      |> ModuleReach.reach(stops())
      |> MapSet.difference(MapSet.new(stops()))

  defp diff(a, b), do: a |> MapSet.difference(b) |> Enum.sort()

  defp exact(version, reached) do
    # reached, not stamped: add to its list
    assert {version, diff(reached, files(version))} == {version, []}
    # stamped, never reached: take out of its list
    assert {version, diff(files(version), reached)} == {version, []}
  end

  test "the reader's stamp is exactly what the read pass's reading reaches" do
    exact(ReaderVersion, reach(["read_law.ex"]))
  end

  test "the catalogue's stamp is exactly what its reading reaches" do
    exact(CatalogueVersion, reach(["catalogue_read.ex"]))
  end

  test "no tool, store or check file is in the reader's stamp" do
    tools =
      ~w(read_pass.ex index.ex store.ex disagreement.ex check_strata.ex check_sample.ex read_report.ex catalogue_read.ex patterns.ex)

    assert for(t <- tools, (@a <> t) in files(ReaderVersion), do: t) == []
  end

  test "the index reaches no file of the reading, so the build can ask it" do
    index = @a <> "index.ex"
    stops = List.delete(stops(), index)
    reached = [index] |> ModuleReach.reach(stops) |> MapSet.difference(MapSet.new(stops))
    assert diff(MapSet.intersection(reached, files(ReaderVersion)), MapSet.new()) == []
  end

  test "the stamps list files by name, never a glob" do
    for version <- [ReaderVersion, CatalogueVersion] do
      assert {version, Enum.filter(version.patterns(), &String.contains?(&1, "*"))} ==
               {version, []}
    end
  end
end
