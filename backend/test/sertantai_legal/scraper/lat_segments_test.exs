defmodule SertantaiLegal.Scraper.LatSegmentsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatSegments, as: S
  alias SertantaiLegal.Scraper.LatTerritory.Change

  @keep %Change{kind: :keep, attribute: "S"}

  test "text/1 and mark/1 wrap a string; empty strings give no segment" do
    assert S.text("a") == [{:text, "a"}]
    assert S.mark("«") == [{:mark, "«"}]
    assert S.text("") == []
  end

  test "join/2 puts a mark between non-blank parts" do
    assert S.join([S.text("a"), [], S.text(" "), S.text("b")], " | ") ==
             [{:text, "a"}, {:mark, " | "}, {:text, "b"}]
  end

  test "blank?/1: only whitespace (in text, marks or changes)" do
    assert S.blank?([])
    assert S.blank?([{:text, "  "}, {:words, @keep, [{:text, " "}]}])
    refute S.blank?([{:words, @keep, [{:text, "x"}]}])
    refute S.blank?(S.mark("…"))
  end

  test "plain/1: the words as written, a pair's new before its old" do
    segs = [
      {:text, "be dealt with by "},
      {:pair, @keep, [{:text, "the service"}], [{:text, "the brigade"}]},
      {:words, @keep, [{:text, " now"}]},
      {:mark, " —"}
    ]

    assert S.plain(segs) == "be dealt with by the service the brigade now —"
  end

  test "trim/1 trims the outer edges only" do
    assert S.trim([{:text, "  a "}, {:words, @keep, [{:text, " b "}]}, {:text, " c  "}]) ==
             [{:text, "a "}, {:words, @keep, [{:text, " b "}]}, {:text, " c"}]

    assert S.trim([{:text, "   "}, {:text, "a"}]) == [{:text, "a"}]
  end

  test "trim/1 reaches into a change at the edge (EU 2006/1907 \"registration..»\"; table cells)" do
    assert S.trim([{:text, " a"}, {:words, @keep, [{:text, "registration. "}]}]) ==
             [{:text, "a"}, {:words, @keep, [{:text, "registration."}]}]

    assert S.trim([{:words, @keep, [{:text, "  "}]}, {:text, "a "}]) == [{:text, "a"}]
  end

  test "update_last_text/2 changes the last visible text, inside a change" do
    assert S.update_last_text(
             [{:text, "a"}, {:words, @keep, [{:text, "Minister,"}]}],
             &String.trim_trailing(&1, ",")
           ) ==
             [{:text, "a"}, {:words, @keep, [{:text, "Minister"}]}]
  end

  # LR-05 (Jason 2026-10-10): AppendText isn't part of the quoted block — it
  # follows the closing quote, as legislation.gov.uk prints it ("section.”.")
  test "append_after_quote/2: after the closing » mark" do
    assert S.append_after_quote(S.mark("«") ++ S.text("section.") ++ S.mark("»"), S.text(".")) ==
             [{:mark, "«"}, {:text, "section."}, {:mark, "»"}, {:text, "."}]

    assert S.append_after_quote(S.text("words"), S.text(".")) == [{:text, "words"}, {:text, "."}]

    # punctuation alone carries no territory: its change wrapper goes
    # ("…provision.]»." not "…provision.]»[E+W: .]"; 2006/1379 reg.5(2))
    inserted = [{:words, @keep, [{:text, "."}]}]

    assert S.append_after_quote(S.mark("«") ++ S.text("x") ++ S.mark("»"), inserted) ==
             [{:mark, "«"}, {:text, "x"}, {:mark, "»"}, {:text, "."}]

    words = [{:words, @keep, [{:text, "; and"}]}]
    assert S.append_after_quote(S.text("x"), words) == [{:text, "x"} | words]
  end

  test "strip_invisible/1: zero-width characters out of row text (U+200D in 1990/8 s.150(1)(b))" do
    assert S.strip_invisible("paragraph\u200D 24ZA") == "paragraph 24ZA"
    assert S.strip_invisible("would\u2060—\u200B\u200C\uFEFF") == "would—"
    # a no-break space is visible spacing: kept
    assert S.strip_invisible("about\u00A0—") == "about\u00A0—"
  end
end
