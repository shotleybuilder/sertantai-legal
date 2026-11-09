defmodule SertantaiLegal.Scraper.ChangeVocabulary.Catalogue.MarkupHeldExamplesTest do
  @moduledoc """
  The markup catalogue's held examples come first on regeneration
  (`catalogue-examples-rotate`, Maritime Safety: Markup reader, 2026-11-04:
  122 held examples rotated out, 24 patterns left with none). A pattern's
  held example reserves its slot until its law is passed; a new example
  fills only the slots left; a held example no longer generated, or
  reading differently alone, leaves its slot to a later law. The replay of
  laws scanned alone, each knowing only its own held examples, is still
  the serial run (#195).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.LawScan

  defp c(i, law, n, patterns), do: {:classified, i, "#{law}/#{n}", patterns}

  defp laws,
    do: [
      {"A", [c(0, "A", 0, ["p"])]},
      {"B", [c(0, "B", 0, ["p"])]},
      {"C", [c(0, "C", 0, ["p"])]},
      {"D", [c(0, "D", 0, ["p"]), c(1, "D", 1, ["p"])]}
    ]

  defp ok(law, i), do: {:ok, %{json: %{"law" => law, "i" => i}, outcome: []}}

  defp serial(held, outcome) do
    Enum.reduce(laws(), LawScan.new_acc(held), fn {law, events}, acc ->
      LawScan.select(acc, law, events, &outcome.(law, &1))
    end)
  end

  defp replay(held, outcome) do
    Enum.reduce(laws(), LawScan.new_acc(held), fn {law, events}, acc ->
      solo =
        LawScan.select(
          LawScan.new_acc(LawScan.held_for(held, law)),
          law,
          events,
          &outcome.(law, &1)
        )

      LawScan.select(acc, law, %{events: events, outcomes: solo.outcomes})
    end)
  end

  defp same(held, outcome) do
    s = serial(held, outcome)
    assert Map.delete(replay(held, outcome), :outcomes) == Map.delete(s, :outcomes)
    s
  end

  test "with nothing held: first come in law order, as before" do
    assert same(%{}, &ok/2).patterns["p"].examples == ["A/0", "B/0", "C/0"]
  end

  test "a held example keeps its slot: a later law's held one is not displaced" do
    acc = same(%{"p" => ["D/1"]}, &ok/2)
    assert acc.patterns["p"].examples == ["A/0", "B/0", "D/1"]
    assert acc.patterns["p"].count == 5
  end

  test "a held example no longer generated frees its slot once its law is passed" do
    acc = same(%{"p" => ["B/9"]}, &ok/2)
    assert acc.patterns["p"].examples == ["A/0", "C/0", "D/0"]
  end

  test "a held example reading differently alone leaves its slot" do
    outcome = fn
      "D", 1 -> :mismatch
      law, i -> ok(law, i)
    end

    acc = same(%{"p" => ["D/1"]}, outcome)
    assert acc.patterns["p"].examples == ["A/0", "B/0"]
    assert acc.mismatch == ["D/1"]
  end

  test "a law's held examples, for its solo scan" do
    held = %{"p" => ["A/0", "D/1"], "q" => ["B/2"]}
    assert LawScan.held_for(held, "D") == %{"p" => ["D/1"]}
    assert LawScan.held_for(held, "C") == %{}
  end
end
