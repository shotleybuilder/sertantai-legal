defmodule SertantaiLegal.Architecture.LatWritePathTest do
  @moduledoc """
  One LAT parse path (lat-refactor LR-28): a parse reaches `legal_articles`
  and `amendment_annotations` only through `LatStagedParser`, so what must
  follow every parse (cause, notes, LR-25's collect + timeline) happens in
  one place.
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)

  # the persisters' own files (their @moduledoc examples) and the one path
  @allowed ~w(
    sertantai_legal/scraper/lat_staged_parser.ex
    sertantai_legal/scraper/lat_persister.ex
    sertantai_legal/scraper/commentary_persister.ex
  )

  defp callers(call) do
    Path.wildcard(Path.join(@lib, "**/*.ex"))
    |> Enum.filter(&(File.read!(&1) =~ call))
    |> Enum.map(&Path.relative_to(&1, @lib))
    |> Enum.reject(&(&1 in @allowed))
  end

  test "only LatStagedParser persists LAT rows" do
    assert callers("LatPersister.persist(") == []
  end

  test "only LatStagedParser persists a parse's notes" do
    assert callers("CommentaryPersister.persist(") == []
  end
end
