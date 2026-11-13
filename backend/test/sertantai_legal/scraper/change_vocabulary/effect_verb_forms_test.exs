defmodule SertantaiLegal.Scraper.ChangeVocabulary.EffectVerbFormsTest do
  @moduledoc """
  The feed's verbs written in another form (Fire and OH&S: Feed reader,
  Decision 1): the bare "insert" and "substitute" are the insertion and
  the substitution; "become" renumbers, as "becomes" does; "words
  reordered" changes the text, a substitution of its words.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  # {target, operation, level} per change the reader makes
  defp read(type, text, refs, law) do
    e = %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affecting: "UK_ukpga_2024_3",
      in_force_date: ~D[2024-04-01]
    }

    for {_key, target, claims} <- Feed.read([e], law) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level)}
    end
  end

  test "a bare insert is an insertion (PACE 1984 s. 80A, by 1999 c. 23 Sch. 4 para. 14)" do
    assert EffectVerb.kind("insert") == "inserted"

    assert read("insert", "s. 80A", ["section-80A"], "UK_ukpga_1984_60") ==
             [{"s.80A", :inserted, :provision}]
  end

  test "insert and preceding word likewise (2008 c. 27 Sch. 6 para. 5(1)(c), by 2014 c. 7 (N.I.) s. 6(3)(b))" do
    assert EffectVerb.kind("insert and preceding word") == "inserted"
  end

  test "a bare substitute is a substitution (S.R. 2004/63 reg. 2(4)(f) comma, by S.R. 2026/178 reg. 2(2)(b))" do
    assert EffectVerb.kind("substitute") == "substituted"

    # (its level is the trailing part's, "comma": not this test's)
    assert [{"reg.2(4)(f)", :substituted, _level}] =
             read("substitute", "reg. 2(4)(f) comma", ["regulation-2-4-f"], "UK_nisr_2004_63")
  end

  test "become renumbers, as becomes does (2023 c. 30 s. 165(2)(a)(i)(ii), by 2024 c. 3)" do
    type = "s. 165(2)(a)(b) become s. 165(2)(a)(i)(ii)"
    assert EffectVerb.kind(type) == "renumbered"
    assert EffectVerb.kind("s. 2(1) becomes s. 2(1)(a)") == "renumbered"

    assert read(
             type,
             "s. 165(2)(a)(i)(ii)",
             ["section-165-2-a-i", "section-165-2-a-ii"],
             "UK_ukpga_2023_30"
           ) == [
             {"s.165(2)(a)(i)", :renumbered, :provision},
             {"s.165(2)(a)(ii)", :renumbered, :provision}
           ]
  end

  test "words that become part of the provision are renumbered at words level (1997 c. 8 s. 75A(5), by 2019 asp 13)" do
    assert read("words become closing words", "s. 75A(5)", ["section-75A-5"], "UK_ukpga_1997_8") ==
             [{"s.75A(5)", :renumbered, :words}]
  end

  test "words reordered is a substitution of the words (2023 c. 30 s. 267(4), by 2024 c. 3 Sch. 12 para. 42(1)(b)(i))" do
    assert EffectVerb.kind("words reordered") == "substituted"

    assert read("words reordered", "s. 267(4)", ["section-267-4"], "UK_ukpga_2023_30") ==
             [{"s.267(4)", :substituted, :words}]
  end

  test "the verbs' other uses are unchanged" do
    assert EffectVerb.kind("inserted") == "inserted"
    assert EffectVerb.kind("words substituted") == "substituted"
    assert EffectVerb.kind("power to insert provisions conferred") == "other"
    assert EffectVerb.no_operation?("revocation of earlier amending provision")
  end
end
