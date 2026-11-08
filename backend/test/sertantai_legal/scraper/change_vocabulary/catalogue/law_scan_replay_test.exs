defmodule SertantaiLegal.Scraper.ChangeVocabulary.Catalogue.LawScanReplayTest do
  @moduledoc """
  The feed and markup catalogues' laws scanned alone and replayed in law
  order give the catalogue a serial run gives (#195): every example the
  whole run asks of a law is one its solo scan computed, including a slot
  a dropped example leaves for a later change or law.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.LawScan, as: Feed
  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.LawScan, as: Markup

  defp c(i, law, n, patterns), do: {:classified, i, "#{law}/#{n}", patterns}

  # the serial run: every law's examples computed as it comes
  defp serial(mod, laws, outcome) do
    Enum.reduce(laws, mod.new_acc(), fn {law, events}, acc ->
      mod.select(acc, law, events, &outcome.(law, &1))
    end)
  end

  # the parallel run: each law alone, then replayed from its own outcomes
  defp replay(mod, laws, outcome) do
    Enum.reduce(laws, mod.new_acc(), fn {law, events}, acc ->
      solo = mod.select(mod.new_acc(), law, events, &outcome.(law, &1))
      mod.select(acc, law, %{events: events, outcomes: solo.outcomes})
    end)
  end

  defp same(mod, laws, outcome) do
    s = serial(mod, laws, outcome)
    r = replay(mod, laws, outcome)
    assert Map.delete(r, :outcomes) == Map.delete(s, :outcomes)
    s
  end

  describe "markup" do
    defp markup_laws,
      do: [
        {"A",
         [
           c(0, "A", 0, ["p"]),
           c(1, "A", 1, ["p"]),
           {:error, "bad change"},
           c(3, "A", 3, ["q"])
         ]},
        {"B", [c(0, "B", 0, ["p", "q"]), c(1, "B", 1, ["r"])]},
        {"C", [c(0, "C", 0, ["p"]), c(1, "C", 1, ["q"])]},
        {"D", [c(0, "D", 0, ["p"]), c(1, "D", 1, ["p", "r"])]},
        {"E", [c(0, "E", 0, ["p", "q"])]}
      ]

    # A's first p example too large, B's r example raises, C's q mismatched
    defp outcome("A", 0), do: :too_large
    defp outcome("B", 1), do: {:raise, "boom"}
    defp outcome("C", 1), do: :mismatch
    defp outcome(law, i), do: {:ok, %{json: %{"law" => law, "i" => i}, outcome: []}}

    test "the replay is the serial run" do
      acc = same(Markup, markup_laws(), &outcome/2)

      # A's slot went to its next change; p full after A, B, C
      assert acc.patterns["p"].examples == ["A/1", "B/0", "C/0"]
      assert acc.patterns["p"].count == 7
      assert acc.too_large == 1
      assert acc.mismatch == ["C/1"]
      assert acc.laws == 5
      assert acc.changes == 11
      assert {"B", "boom"} in acc.unclassified
      assert {"A", "bad change"} in acc.unclassified
      # D's r example asked for although p is full
      assert acc.patterns["r"].examples == ["D/1"]
    end

    test "a law given up on whole is unclassified, nothing counted" do
      acc = Markup.select(Markup.new_acc(), "A", %{error: "won't parse"})
      assert acc.unclassified == [{"A", "won't parse"}]
      assert acc.laws == 0
    end
  end

  describe "feed" do
    defp feed_laws,
      do: [
        {"A", [{:excluded, "legacy"}, c(1, "A", 1, ["p"]), c(2, "A", 1, ["p"])]},
        {"B", [c(0, "B", 0, ["p"]), {:error, "no ref"}]},
        {"C", [c(0, "C", 0, ["p", "q"])]},
        {"D", [c(0, "D", 0, ["p"]), c(1, "D", 1, ["q"])]}
      ]

    defp feed_outcome("B", 0), do: {:raise, "boom"}

    defp feed_outcome(law, i),
      do: {:ok, %{json: %{"law" => law, "i" => i}, outcome: [], mismatch: law == "C"}}

    test "the replay is the serial run" do
      acc = same(Feed, feed_laws(), &feed_outcome/2)

      # B's example raised: B takes no slot, D does
      assert acc.patterns["p"].examples == ["A/1", "C/0", "D/0"]
      assert acc.excluded == %{"legacy" => 1}
      assert acc.mismatch == ["C/0"]
      assert acc.effects == 8
      assert {"B", "boom"} in acc.unclassified
    end
  end
end
