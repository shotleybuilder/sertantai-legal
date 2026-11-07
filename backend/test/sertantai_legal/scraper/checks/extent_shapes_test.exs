defmodule SertantaiLegal.Scraper.Checks.ExtentShapesTest do
  @moduledoc """
  Extent shape mining in Elixir (#192): `Mine` and `Review` reproduce the
  frozen Python run (CV-S05c run-03, `test/fixtures/extent_shapes/run-03/`)
  byte for byte, by the sha256 its manifest recorded; and the pieces
  behave as `mine.py`'s did.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Checks.ExtentShapes.{Mine, Review}
  alias SertantaiLegal.Scraper.Checks.PyCompat

  @dir "test/fixtures/extent_shapes/run-03"

  defp fixture(name), do: Path.join(@dir, name) |> File.read!() |> :zlib.gunzip()

  defp sha(iodata), do: :sha256 |> :crypto.hash(iodata) |> Base.encode16(case: :lower)

  defp hashes do
    for line <- @dir |> Path.join("sha256.txt") |> File.read!() |> String.split("\n", trim: true),
        into: %{} do
      [h, name] = String.split(line, ~r/\s+/, parts: 2)
      {name, h}
    end
  end

  describe "run-03, frozen" do
    setup do
      sentences = fixture("sentences.tsv.gz")
      %{sentences: sentences, mined: Mine.run(sentences), hashes: hashes()}
    end

    test "the input is run-03's", %{sentences: s, hashes: h} do
      assert sha(s) == h["sentences.tsv"]
    end

    test "items.tsv, shapes.tsv and stats.json as mine.py wrote them", %{mined: m, hashes: h} do
      assert sha(m.items) == h["items.tsv"]
      assert sha(m.shapes) == h["shapes.tsv"]
      assert sha(m.stats) == h["stats.json"]
    end

    test "review.tsv and review.json as review.py wrote them", %{mined: m, hashes: h} do
      r = Review.run(IO.iodata_to_binary(m.items), fixture("verdicts.tsv.gz"))
      assert sha(r.review) == h["review.tsv"]
      assert sha(r.summary) == h["review.json"]
    end
  end

  describe "the pieces" do
    test "a sentence's lead and its lettered items" do
      assert Mine.split("This Act extends to—a England;b Wales.") ==
               {"This Act extends to", [{"a", "England"}, {"b", "Wales."}]}

      assert Mine.split("No items here.") == {"No items here.", []}
    end

    test "references, places and laws masked" do
      assert Mine.mask("Section 3 extends to England and Wales.") == "SEC extends to PLACE"
      assert Mine.mask("sections 1 to 4 of this Act") == "SECS of THIS_LAW"
    end

    test "words folded into WORDS, kept words and tokens kept" do
      assert Mine.coarse("SEC extends to PLACE only within reason") ==
               "SEC extends to PLACE only WORDS"
    end
  end

  describe "Python's ways" do
    test "round half to even, exactly" do
      assert PyCompat.round(2.5) == 2
      assert PyCompat.round(3.5) == 4
      assert PyCompat.round(0.0625, 3) == 0.062
      assert PyCompat.round(0.0635, 3) == 0.064
    end

    test "most_common: by count, ties in first-seen order" do
      assert PyCompat.most_common([{"b", 1}, {"a", 2}, {"c", 1}]) == [
               {"a", 2},
               {"b", 1},
               {"c", 1}
             ]
    end

    test "json.dump(indent=2), keys in order, non-ASCII escaped" do
      assert PyCompat.json([{"a", 1}, {"b", [{"c", nil}, {"d", 0.5}]}, {"e", "×"}], 2) ==
               ~s({\n  "a": 1,\n  "b": {\n    "c": null,\n    "d": 0.5\n  },\n  "e": "\\u00d7"\n})
    end

    test "a slice by code points, not graphemes" do
      assert PyCompat.slice("e\u0301abc", 2) == "e\u0301"
    end
  end
end
