defmodule SertantaiLegal.Scraper.Commencement.TextRefsTest do
  @moduledoc """
  The ref reader the order reader, the own clause's Schedule lists and the
  checks share, in its own module (the Commencement reader's speed fixes:
  the commencement catalogue reaches no order reading); `Order.refs_in/1`
  and `Order.own_schedule_refs/1` delegate here.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Order, TextRefs}

  test "an order's words as refs: sections, a range, a Schedule's paragraphs" do
    assert TextRefs.refs_in("sections 85 to 87") == ["s.85..s.87"]
    assert "sch.3.para.4..sch.3.para.10" in TextRefs.refs_in("paragraphs 4 to 10 of Schedule 3")
    assert TextRefs.refs_in("section 2 of the Health and Safety at Work etc. Act 1974") == []
  end

  test "a range of lettered or numbered paragraphs is its paragraphs, each named (SSI 2009/393: section 79(2)(a) to (d))" do
    assert TextRefs.refs_in("Section 79(1), (2)(a) to (d) and (3)") ==
             ["s.79(1)", "s.79(2)(a)", "s.79(2)(b)", "s.79(2)(c)", "s.79(2)(d)", "s.79(3)"]

    assert TextRefs.refs_in("section 10(2)(ii) to (iv)") ==
             ["s.10(2)(ii)", "s.10(2)(iii)", "s.10(2)(iv)"]

    # numbered ranges stay ranges
    assert TextRefs.refs_in("section 2(1) to (3)") == ["s.2(1)..s.2(3)"]
  end

  test "a Chapter of a Part is that Chapter; a heading \"in Chapter 1 of Part 1\" names where, never a provision" do
    # WSI 2018/35 art.2(w); SI 2012/873 art.2(a)
    assert TextRefs.refs("Chapter 6 (special cases) of Part 5 (supplementary provision)", nil) ==
             ["pt.5.ch.6"]

    assert TextRefs.refs("in Chapter 1 of Part 1 (green deal)—", nil) == []
  end

  test "a law's own Schedule list (Petroleum Act 1998 s.52(3))" do
    text = "in Schedule 4, paragraphs 8, 10 and 11"
    assert TextRefs.own_schedule_refs(text) == ~w(sch.4.para.8 sch.4.para.10 sch.4.para.11)
    assert Order.own_schedule_refs(text) == TextRefs.own_schedule_refs(text)
  end

  test "Order.refs_in/1 is the same reading" do
    for t <- ["sections 85 to 87", "Part II and paragraphs 4 to 10 and 21 of Schedule 3"],
        do: assert(Order.refs_in(t) == TextRefs.refs_in(t))
  end
end
