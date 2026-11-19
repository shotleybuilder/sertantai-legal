defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPunctuationLevelTest do
  @moduledoc """
  A punctuation mark the feed names as what was inserted is a change
  within the provision's text (words level), never the provision itself:
  "bracket inserted" (SI 2024/174 Sch. 8 para. 3(2)(a), by SI 2024/1384)
  and "dash inserted" (SSI 2018/219 sch. 8 para. 19, by SSI 2025/165 reg.
  39(j)(i): 'after "unless", insert "—"'), as "comma inserted" and "full
  stop substituted" already are.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(type, text, refs, affecting),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affecting: affecting,
      in_force_date: ~D[2025-01-01]
    }

  # {operation, level} per change the reader makes
  defp read(e, law) do
    for {_key, _target, claims} <- Feed.read([e], law, [], %{}, %{}, %{}) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {v.(:operation), v.(:level)}
    end
  end

  test "a bracket inserted changes the provision's words (SI 2024/174 Sch. 8 para. 3(2)(a))" do
    e =
      effect(
        "bracket inserted",
        "Sch. 8 para. 3(2)(a)",
        ["schedule-8-paragraph-3-2-a"],
        "UK_uksi_2024_1384"
      )

    assert [{:inserted, :words}] = read(e, "UK_uksi_2024_174")
  end

  test "a dash inserted changes the provision's words (SSI 2018/219 sch. 8 para. 19)" do
    e = effect("dash inserted", "sch. 8 para. 19", ["schedule-8-paragraph-19"], "UK_ssi_2025_165")

    assert [{:inserted, :words}] = read(e, "UK_ssi_2018_219")
  end

  test "the marks already read stay words: comma, full stop, punctuation mark" do
    for type <- ["comma inserted", "full stop omitted", "punctuation mark inserted"] do
      e = effect(type, "reg. 3(2)", ["regulation-3-2"], "UK_uksi_2024_1384")
      assert [{_, :words}] = read(e, "UK_uksi_2024_174"), type
    end
  end

  test "a provision inserted stays a provision" do
    e =
      effect(
        "inserted",
        "Sch. 8 para. 3(2)(a)",
        ["schedule-8-paragraph-3-2-a"],
        "UK_uksi_2024_1384"
      )

    assert [{:inserted, :provision}] = read(e, "UK_uksi_2024_174")
  end
end
