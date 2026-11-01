defmodule SertantaiLegal.Scraper.Amendment.Reader.BracketsTest do
  @moduledoc "The reader's bracket helpers (decomposed from Amendment.Reader, run time 2026-10-25)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Reader.Brackets

  test "plain_brackets/1: every bracket's contents, in order" do
    assert Brackets.plain_brackets("section 7(1)(a)(ii)") == ["1", "a", "ii"]
    assert Brackets.plain_brackets("no brackets") == []
  end

  test "bracket?/1: what a provision bracket may hold" do
    for b <- ~w(5 5A a ca ii iv A AB), do: assert(Brackets.bracket?(b), b)
    for b <- ["Part", "abcd", "1-2"], do: refute(Brackets.bracket?(b), b)
  end

  test "bracket_level/1: subsection, paragraph, sub-paragraph, capital" do
    assert Enum.map(~w(5 b ii A), &Brackets.bracket_level/1) == [0, 1, 2, 3]
  end

  test "above/2: the place's brackets above the clause's own level" do
    assert Brackets.above(["1", "a"], []) == ["1", "a"]
    assert Brackets.above(["1", "a"], ["b"]) == ["1"]
    assert Brackets.above(["1", "a", "ii"], ["iii"]) == ["1", "a"]
  end

  test "ref/2: a provision's ref; a range with no brackets" do
    assert Brackets.ref("s", ["25", "5A"]) == "s.25(5A)"
    assert Brackets.ref("reg", ["4", "1", "a"]) == "reg.4(1)(a)"
    assert Brackets.ref("s", ["22..25"]) == "s.22..s.25"
  end

  test "combos/1: each level taken or skipped (\"subsection (5), paragraphs (b) and (c)\")" do
    paths = Brackets.combos(["5", "b", "c"])
    for p <- [["5"], ["5", "b"], ["5", "c"], ["b"], ["c"]], do: assert(p in paths, inspect(p))
    refute [] in paths
  end

  test "an EU Article's numbered paragraphs bracketed as its rows (SI 2019/758 on REACH Art 3)" do
    assert Brackets.eu_paragraphs("In paragraph 36, at the end insert—", :article) ==
             "In paragraph (36), at the end insert—"

    assert Brackets.eu_paragraphs("In paragraphs 11, 13 and 14, for", :article) ==
             "In paragraphs (11), (13) and (14), for"

    assert Brackets.eu_paragraphs("omit paragraph 4a.", :article) == "omit paragraph (4a)."
    assert Brackets.eu_paragraphs("In paragraph (2)(b)", :article) == "In paragraph (2)(b)"
    assert Brackets.eu_paragraphs("In paragraph 36", :section) == "In paragraph 36"
  end
end
