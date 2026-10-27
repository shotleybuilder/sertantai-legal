defmodule SertantaiLegal.Scraper.AmendingLaw.SubPathTest do
  @moduledoc """
  Runs of subdivision brackets as laws write them (CV-S05 round 13, S2:
  found by the CV-S05d census).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.SubPath

  test "a bracket continuing the one before replaces it at its own level" do
    assert SubPath.continue(["1"], ["4"]) == ["4"]
    assert SubPath.continue(["2", "a"], ["b"]) == ["2", "b"]
    assert SubPath.continue(["w", "i"], ["ii"]) == ["w", "ii"]
    assert SubPath.continue(["2", "a", "ii"], ["b", "i"]) == ["2", "b", "i"]
    assert SubPath.continue(["1A"], ["2", "b"]) == ["2", "b"]
    # (a letter i after h is a letter, not a roman numeral)
    assert SubPath.continue(["2", "h"], ["i"]) == ["2", "i"]
  end

  test "a run: \"(1A), (2)(b) and (2ZZA) to (2ZZC)\" (TCPA 1990 s.70)" do
    assert SubPath.paths("(1A), (2)(b) and (2ZZA) to (2ZZC)") ==
             [["1A"], ["2", "b"], ["2ZZA"], ["2ZZC"]]
  end

  test "a run: \"(2)(aa)\" is one path (TCPA 1990 s.70)" do
    assert SubPath.paths("(2)(aa)") == [["2", "aa"]]
  end

  test "ranges: numbers with a suffixed end, letters" do
    assert SubPath.paths("(4) to (8A)") == [["4"], ["5"], ["6"], ["7"], ["8"], ["8A"]]
    assert SubPath.paths("(2)(b) to (d)") == [["2", "b"], ["2", "c"], ["2", "d"]]
  end
end
