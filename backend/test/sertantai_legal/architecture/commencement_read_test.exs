defmodule SertantaiLegal.Architecture.CommencementReadTest do
  @moduledoc """
  One commencement path (commencement-rules CR-06): a law's commencement
  words are read only by the ruleset's readers — `LawStart` (its clause,
  LR-33) and `Commencement` (the law's own clause, its orders, its
  effects) — and every consumer asks the evaluator. A new regex for "comes
  into force" anywhere else fails this test; read it as a rule instead.
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)

  # where commencement words may be read, by path prefix → why
  @readers %{
    "sertantai_legal/scraper/law_start" => "the law's own clause (LR-33, LR-34)",
    "sertantai_legal/scraper/commencement/" => "the ruleset's readers (CR-03, CR-04)",
    # the feed's effect type "coming into force", not law text
    "sertantai_legal/scraper/effect_kind.ex" => "the feed's effect kind",
    # the feed's effect type "coming into operation" (CV-S02b review D), not law text
    "sertantai_legal/scraper/change_vocabulary/effect_verb.ex" => "the feed reader's effect verb"
  }

  test "only the commencement readers match commencement words" do
    offenders =
      for path <- Path.wildcard(Path.join(@lib, "**/*.ex")),
          rel = Path.relative_to(path, @lib),
          not Enum.any?(Map.keys(@readers), &String.starts_with?(rel, &1)),
          File.read!(path) =~ ~r/~r[\/"|][^\n]*into[^\n]*(?:force|operation)/,
          do: rel

    assert offenders == []
  end
end
