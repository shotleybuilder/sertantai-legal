defmodule SertantaiLegal.Scraper.EffectKindTest do
  @moduledoc """
  `EffectKind` (CR-06): an effect Type as a change kind — the one part of
  the effects' facts the parse uses, so only it counts toward
  `ParserVersion` (a label-only change to `EffectFacts` no longer makes every
  law's parse stale).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{EffectFacts, EffectKind}

  test "an effect Type as a change kind" do
    assert EffectKind.kind("words substituted", nil) == "substituted"
    assert EffectKind.kind("coming into force", nil) == "commenced"
    assert EffectKind.kind("applied (with modifications)", nil) == "other"
    assert EffectKind.kind("words inserted", "commencement") == "commenced"

    assert EffectKind.kind(
             "amendment to earlier affecting provision SI 1995/3128 reg. 10(2)",
             nil
           ) ==
             "other"

    assert EffectKind.kind(nil, nil) == "other"
  end

  test "EffectFacts.kind/2 delegates" do
    assert EffectFacts.kind("repealed", nil) == EffectKind.kind("repealed", nil)
  end

  test "the parser's version counts EffectKind, not EffectFacts; the labels' counts both" do
    parser = File.read!("lib/sertantai_legal/scraper/parser_version.ex")
    labels = File.read!("lib/sertantai_legal/scraper/label_version.ex")
    assert parser =~ "effect_kind.ex"
    refute parser =~ "effect_facts.ex"
    assert labels =~ "effect_facts.ex" and labels =~ "effect_kind.ex"
  end
end
