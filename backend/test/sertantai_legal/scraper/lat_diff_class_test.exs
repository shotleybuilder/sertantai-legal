defmodule SertantaiLegal.Scraper.LatDiffClassTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatDiffClass

  defp row(fields \\ []),
    do:
      Map.merge(
        %{text: "A duty applies.", title: nil, excluded_extent: nil, extent_code: "E+W"},
        Map.new(fields)
      )

  describe "classify/2" do
    test "an unchanged row has no classes" do
      assert LatDiffClass.classify(row(), row()) == []
    end

    test "inserted and removed rows" do
      assert LatDiffClass.classify(nil, row()) == ["inserted"]
      assert LatDiffClass.classify(row(), nil) == ["removed"]
    end

    test "excluded_extent and extent_code changes name old → new" do
      assert LatDiffClass.classify(row(), row(excluded_extent: "W")) == [
               "excluded_extent: nil → W"
             ]

      assert LatDiffClass.classify(row(extent_code: "E.W."), row()) == ["extent_code: E.W. → E+W"]
    end

    test "brackets added, removed or relabelled around the same words" do
      plain = row(text: "The regulator or the council may act.")
      bracketed = row(text: "The [E+W: regulator or the] council may act.")

      assert LatDiffClass.classify(plain, bracketed) == ["text: brackets added"]
      assert LatDiffClass.classify(bracketed, plain) == ["text: brackets removed"]

      assert LatDiffClass.classify(
               bracketed,
               row(text: "The [W: regulator or the] council may act.")
             ) ==
               ["text: brackets changed"]
    end

    test "words dropped or added are words changes, reordering is reordered" do
      old = row(text: "used for police [E+W: or fire brigade fire and rescue authority] purposes")
      new = row(text: "used for police [E+W: or fire and rescue authority] purposes")
      assert LatDiffClass.classify(old, new) == ["text: words"]

      assert LatDiffClass.classify(row(text: "b a"), row(text: "a b")) == ["text: reordered"]
    end

    test "several fields: one class each, in field order" do
      assert LatDiffClass.classify(row(title: "Old"), row(title: "New", excluded_extent: "S")) ==
               ["title: changed", "excluded_extent: nil → S"]
    end

    test "whitespace only: text: whitespace" do
      assert LatDiffClass.classify(row(text: "or]  a passenger"), row(text: "or] a passenger")) ==
               ["text: whitespace"]
    end

    test "nil and empty text are the same" do
      assert LatDiffClass.classify(row(text: nil), row(text: "")) == []
    end
  end

  describe "unexpected/2" do
    test "classes matching no expected pattern" do
      counts = %{
        "excluded_extent: nil → W" => 120,
        "text: words" => 3,
        "text: brackets added" => 9
      }

      assert LatDiffClass.unexpected(counts, [~r/^excluded_extent: nil → /, ~r/^text: brackets/]) ==
               %{"text: words" => 3}
    end
  end
end
