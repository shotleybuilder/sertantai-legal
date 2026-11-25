defmodule SertantaiLegal.Architecture.ExtentReadStampsTest do
  @moduledoc """
  The extent reader's stamps hold exactly the code each depends on (the
  Extent reader stamps session; until then `extent/*.ex` by glob, so a
  tool's or catalogue's edit staled every reading and every build):

  - `ReadVersion.Document`: what `Extent.Reader` reaches, the document
    reading (`Extent.ReadCache`'s key);
  - `ReadVersion.Catalogue`: what the catalogue's own code reaches beyond
    it (`Patterns.Example`, `Sweep`; the cache's key too);
  - `ReadVersion`: what the stored rules depend on, the document reading
    and the powers' placement (`Extent.Powers`), stamped on `extent_rules`,
    with the powers parser (`EnablingCache.ParserVersion`), whose cache
    entries record it.

  Reach as in `CommencementReadStampsTest`: the store, the write, the
  cache, the stamps and the IO modules are where a path ends.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion.{Catalogue, Document}
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache.ParserVersion

  @e "lib/sertantai_legal/scraper/amending_law/extent/"
  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
    lib/sertantai_legal/scraper/source_version.ex
  )
  @stops @io ++ ReadVersion.boundaries()

  defp files(version), do: version.files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()

  defp reach(entries),
    do:
      entries
      |> Enum.map(&(@e <> &1))
      |> ModuleReach.reach(@stops)
      |> MapSet.difference(MapSet.new(@stops))

  defp diff(a, b), do: a |> MapSet.difference(b) |> Enum.sort()

  defp exact(version, reached) do
    # reached, not stamped: add to its list
    assert {version, diff(reached, files(version))} == {version, []}
    # stamped, never reached: take out of its list
    assert {version, diff(files(version), reached)} == {version, []}
  end

  test "the document reading's stamp is exactly what Extent.Reader reaches" do
    exact(Document, reach(["reader.ex"]))
  end

  test "the catalogue's stamp is exactly what its own code reaches beyond the reading" do
    beyond = reach(["patterns/example.ex", "sweep.ex"]) |> MapSet.difference(files(Document))
    exact(Catalogue, beyond)
  end

  test "the stored rules' stamp is exactly the document reading, the powers' placement and the parser" do
    exact(ReadVersion, MapSet.union(reach(["reader.ex", "powers.ex"]), files(ParserVersion)))
  end

  test "the powers parser's stamp is exactly what the cache's parse reaches" do
    # the cache's fetch (`EnactedBy`, with the register's matchers) is IO here
    stops = @io -- ["lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex"]

    stops =
      stops ++
        ~w(lib/sertantai_legal/scraper/enacted_by.ex lib/sertantai_legal/scraper/enacted_by/enabling_cache/parser_version.ex)

    reached =
      ParserVersion.patterns()
      |> ModuleReach.reach(stops)
      |> MapSet.difference(MapSet.new(stops))

    exact(ParserVersion, reached)
  end

  test "no tool, catalogue or store file is in the stored rules' stamp" do
    tools =
      ~w(check.ex withheld.ex sweep.ex patterns/example.ex) ++
        Enum.map(ReadVersion.boundaries(), &Path.relative_to(&1, @e))

    held = for t <- tools, (@e <> t) in files(ReadVersion), do: t
    assert held == []
  end
end
