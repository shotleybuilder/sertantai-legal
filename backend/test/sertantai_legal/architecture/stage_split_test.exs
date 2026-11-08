defmodule SertantaiLegal.Architecture.StageSplitTest do
  @moduledoc """
  The two stages' versions (#194) hold exactly the code each stage runs:
  the changes stage's (`ChangeVocabulary.Version`) is what a build reaches,
  the labels stage's (`FoldVersion`) what a switched law's timeline path
  reaches, to its stores. So a fold-only edit stales no built change, a
  check's or a measure's stales nothing, and an edit to a file both reach
  stales both. Reach is followed through module references in the compiled
  code (`ModuleReach`), I/O modules aside as in `VersionCoverageTest`.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach
  alias SertantaiLegal.Scraper.ChangeVocabulary.{FoldVersion, Version}

  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
    lib/sertantai_legal/scraper/lat_staged_parser.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
    lib/sertantai_legal/scraper/source_version.ex
  )

  @build ["lib/sertantai_legal/scraper/change_vocabulary/build.ex"]
  @fold ~w(
    lib/sertantai_legal/scraper/change_vocabulary/label_switch.ex
    lib/sertantai_legal/scraper/change_vocabulary/fold.ex
  )

  defp files(version), do: version.files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()

  defp reach(entry, stop),
    do: entry |> ModuleReach.reach(stop) |> MapSet.difference(MapSet.new(stop))

  defp diff(a, b), do: a |> MapSet.difference(b) |> Enum.sort()

  # each assertion's left side lists the files at fault
  test "the changes stage's version is exactly what a build reaches" do
    build = reach(@build, @io)
    assert diff(build, files(Version)) == []
    # in the version, never reached: add to its except:
    assert diff(files(Version), build) == []
  end

  test "the labels stage's version is exactly what the timeline path reaches" do
    fold = reach(@fold, @io ++ FoldVersion.boundaries())
    assert diff(fold, files(FoldVersion)) == []
    assert diff(files(FoldVersion), fold) == []
  end

  test "a fold-only edit stales no built change: the build reaches no fold-only file" do
    fold_only = MapSet.difference(files(FoldVersion), files(Version))
    assert "lib/sertantai_legal/scraper/change_vocabulary/label.ex" in fold_only
    assert "lib/sertantai_legal/scraper/change_vocabulary/fold.ex" in fold_only
    assert MapSet.intersection(fold_only, reach(@build, @io)) |> Enum.sort() == []
  end
end
