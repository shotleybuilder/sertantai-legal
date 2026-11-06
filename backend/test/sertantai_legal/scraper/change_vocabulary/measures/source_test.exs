defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.SourceTest do
  @moduledoc """
  What the measures count as read (Maritime Safety: Measures, the hand
  check): a pointer is read only where the amending law's text holds its
  provision, or one containing it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source

  test "a pointer whose provision, or one containing it, is in the text is read" do
    elements = ["section-2", "regulation-5-2", "schedule-1-paragraph-3"]

    assert Source.read_pointers(["s.2(3)(b)", "reg.5(2)", "sch.1.para.3(a)"], elements) ==
             ["s.2(3)(b)", "reg.5(2)", "sch.1.para.3(a)"]
  end

  test "a pointer into a Schedule the store doesn't hold is not read (FA 1995 Sch.29)" do
    assert Source.read_pointers(["sch.29", "sch.2.para.1", "s.4"], ["section-21"]) == []
  end

  test "an order's article pointer matches its element, and is read in both spellings (the feed may name it reg.: MSA 1995 Sch.5 para.4(c))" do
    assert Source.read_pointers(["art.1(2)", "art.7"], ["article-1-2"]) == [
             "art.1(2)",
             "reg.1(2)"
           ]
  end
end
