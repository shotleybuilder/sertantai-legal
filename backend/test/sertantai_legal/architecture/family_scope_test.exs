defmodule SertantaiLegal.Architecture.FamilyScopeTest do
  @moduledoc """
  One family scope (Tooling: round scope, 2026-11-13): the pipeline's
  tasks and change-vocabulary code scope a family only through
  `Amendment.PatternSource` (`family_laws/1`, `family_filter/2`), so a
  round's name (`ChangeVocabulary.Rounds`) means exactly its families
  everywhere. A new `family LIKE` elsewhere fails this test; use
  `family_filter/2` instead.
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)

  test "only PatternSource matches a family name in SQL" do
    paths =
      Path.wildcard(Path.join(@lib, "mix/tasks/lat.*.ex")) ++
        Path.wildcard(Path.join(@lib, "sertantai_legal/scraper/change_vocabulary/**/*.ex"))

    offenders =
      for path <- paths,
          File.read!(path) =~ ~r/family\s+I?LIKE\b/i,
          do: Path.relative_to(path, @lib)

    assert offenders == []
  end
end
