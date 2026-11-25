defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.ExtentYardstickTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.ExtentYardstick, as: Y

  test "the feed's effect extent against the law's text bound" do
    assert Y.classify("E+W", "E+W") == "agree"
    assert Y.classify("E+W+S+N.I.", "UK") == "agree"
    assert Y.classify("E+W", "UK") == "law_wider"
    assert Y.classify("NI", "E+W+S+NI") == "law_wider"
    assert Y.classify("UK", "E+W+S") == "law_narrower"
    assert Y.classify("S", "E+W") == "disjoint"
    assert Y.classify("E+W", "W+S") == "overlap"
    assert Y.classify("E", nil) == "feed_only"
    assert Y.classify(nil, "E") == "law_only"
    assert Y.classify(nil, nil) == "neither"
  end

  test "counts every class; the record splits the no-bound changes by the feed" do
    rows = [
      %{feed_extent: "E+W", law_extent: "E+W", outcome: "bound:law"},
      %{feed_extent: "S", law_extent: nil, outcome: "none:same"},
      %{feed_extent: nil, law_extent: nil, outcome: "none:law_no_powers"}
    ]

    r = Y.record("F", ~U[2026-11-25 12:00:00Z], rows)
    assert r.counts["agree"] == 1 and r.counts["feed_only"] == 1 and r.counts["neither"] == 1
    assert r.counts |> Map.values() |> Enum.sum() == 3
    assert map_size(r.counts) == length(Y.classes())
    assert r.no_bound == %{"feed_speaks" => 1, "feed_silent" => 1}
  end

  @tag :tmp_dir
  test "written and read back; the measures' lines", %{tmp_dir: dir} do
    r =
      Y.record("F", ~U[2026-11-25 12:00:00Z], [
        %{feed_extent: "E", law_extent: "UK", outcome: "bound:law"}
      ])

    path = Path.join(dir, "f.json")
    :ok = Y.write(r, path)
    back = Y.read(path)
    assert back.counts["law_wider"] == 1

    [head | _] = lines = Y.lines(back, ~U[2026-11-26 00:00:00Z])
    assert head =~ "BEFORE the last build"
    assert Enum.any?(lines, &(&1 =~ "law_wider"))
    assert [_] = Y.lines(nil, nil)
  end
end
