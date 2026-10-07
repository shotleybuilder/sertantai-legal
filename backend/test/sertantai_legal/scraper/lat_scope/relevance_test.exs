defmodule SertantaiLegal.Scraper.LatScope.RelevanceTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatScope.Relevance

  # Companies Act 2006: s.416 (Pt 15 Ch 5), s.468 (Pt 15 Ch 11), s.1292 (Pt 46)
  @section_parts %{"416" => "15", "468" => "15", "1292" => "46", "1" => "1", "1300" => nil}

  describe "fragments/3" do
    test "a cited section gives its whole Part, once per Part" do
      assert Relevance.fragments(@section_parts, ["416", "468", "1292"], []) ==
               ["part/15", "part/46"]
    end

    test "a cited section outside any Part, or unknown to the LAT, stays a section" do
      assert Relevance.fragments(@section_parts, ["1300", "999"], []) ==
               ["section/1300", "section/999"]
    end

    test "named fragments are added; one inside a kept Part is dropped" do
      assert Relevance.fragments(@section_parts, ["416"], [
               "part/15/chapter/5",
               "part/2/chapter/2"
             ]) ==
               ["part/15", "part/2/chapter/2"]
    end

    test "named fragments alone (no cited section)" do
      assert Relevance.fragments(%{}, [], ["part/1", "part/2/chapter/2"]) ==
               ["part/1", "part/2/chapter/2"]
    end

    test "nothing cited and nothing named: no scope" do
      assert Relevance.fragments(@section_parts, [], []) == []
    end
  end

  describe "covered?/2" do
    test "a chapter or section is covered by its Part; a Part by nothing narrower" do
      assert Relevance.covered?("part/15/chapter/5", ["part/15"])
      refute Relevance.covered?("part/15", ["part/15/chapter/5"])
      refute Relevance.covered?("part/1", ["part/15"])
      refute Relevance.covered?("part/1", ["part/1"])
    end
  end

  describe "kept?/2" do
    test "a row is kept when its Part, Part+Chapter or provision is in the fragments" do
      fragments = ["part/15", "part/2/chapter/2", "section/1300"]

      assert Relevance.kept?(%{part: "15", chapter: "5", provision: "416"}, fragments)
      assert Relevance.kept?(%{part: "2", chapter: "2", provision: "44"}, fragments)
      refute Relevance.kept?(%{part: "2", chapter: "1", provision: "15"}, fragments)
      assert Relevance.kept?(%{part: nil, chapter: nil, provision: "1300"}, fragments)
      refute Relevance.kept?(%{part: "46", chapter: nil, provision: "1292"}, fragments)
    end
  end
end
