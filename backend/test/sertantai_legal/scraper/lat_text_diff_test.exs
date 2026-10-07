defmodule SertantaiLegal.Scraper.LatTextDiffTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatTextDiff

  describe "diff/2" do
    test "changed, inserted and removed rows by section_id; unchanged rows left out" do
      old = %{"a" => "same", "b" => "x y", "c" => "gone"}
      new = %{"a" => "same", "b" => "y x", "d" => "new"}

      assert LatTextDiff.diff(old, new) == [
               {"b", "text_changed", "x y", "y x"},
               {"c", "removed", "gone", nil},
               {"d", "inserted", nil, "new"}
             ]
    end
  end

  describe "kind/2" do
    test "same words in a new order, or duplicates removed: reordered (the list-text fix)" do
      old = "“mine” means a mine; any place; and any place; In these Regulations—"
      new = "In these Regulations— “mine” means a mine; any place; and"

      assert LatTextDiff.kind(old, new) == "reordered"
    end

    test "a missing space restored between list items: reordered" do
      assert LatTextDiff.kind("at work; andany room", "at work; and any room") == "reordered"
    end

    test "a continuation marker only: reordered" do
      assert LatTextDiff.kind("who— and applies", "who— … and applies") == "reordered"
    end

    test "different words: other (e.g. an amendment since the last parse)" do
      assert LatTextDiff.kind("31st December 1992", "1st January 1993") == "other"
    end
  end
end
