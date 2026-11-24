defmodule SertantaiLegal.Scraper.Commencement.Order.WordsTest do
  @moduledoc "An order's words normalised, and a rule's source ref (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Words

  test "norm/1: lower case, words only" do
    assert Words.norm("The Health and Safety at Work etc. Act 1974") ==
             "the health and safety at work etc act 1974"
  end

  test "squash/1: one space, trimmed" do
    assert Words.squash("  section\n 3   and  4 ") == "section 3 and 4"
  end

  test "wording/1: \"the 1st of April\" read as \"1st April\"" do
    assert Words.wording("on the 1st of April 2015") =~ "1st April 2015"
  end

  test "source_ref/1: a CLML id in the law's grammar, else the id as given" do
    assert Words.source_ref("section-5") == "s.5"
    assert Words.source_ref("weird-x") == "weird-x"
  end
end
