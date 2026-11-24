defmodule SertantaiLegal.Scraper.Commencement.Order.ItemsTest do
  @moduledoc "A commencement statement's items as refs (the order reader's split, 2026-11-24)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Items

  test "join_open/1: a line whose bracket is still open goes on in the next" do
    assert Items.join_open([
             "16(1), (2) (in so far as it inserts … of the Control of",
             "Pollution Act 1974) and (3)",
             "20"
           ]) ==
             [
               "16(1), (2) (in so far as it inserts … of the Control of Pollution Act 1974) and (3)",
               "20"
             ]
  end

  test "paragraphs?/1: every ref a Schedule's" do
    assert Items.paragraphs?(["sch.2.para.1", "sch.2.para.3"])
    refute Items.paragraphs?(["sch.2.para.1", "s.4"])
  end
end
