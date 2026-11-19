defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSubstitutedForFormsTest do
  @moduledoc """
  The forms of "substituted for" a changes-feed Type takes beyond naming
  its own targets (Waste, Water and Climate: Feed reader):

  - new provisions in place of words or a full stop ("reg. 3(k)(l)"
    "substituted for full stop": S.R. 2010/59 by S.R. 2012/177 reg. 4(5),
    "In paragraph (j) at the end for "." substitute— (k) … (l) …") are
    inserted;
  - a Type naming none of its targets ("s. 39A-39E" "substituted for s. 39
    40") makes every target new;
  - a Type restating only the tail ("reg. 5(3)(4)" "(3)(4) substituted for
    (3)") names the target's own last parts;
  - a range of letters counts a to z, then aa to zz, then aaa ("for
    paragraphs (a) to (aaa) substitute—": EPA 1990 s. 153(1) by SI
    2015/479 art. 2).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedSubstitutedFor}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(type, text, refs, ranges \\ []),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affected_ranges: ranges,
      affecting: "UK_nisr_2012_177",
      in_force_date: ~D[2012-05-21]
    }

  # {target, operation, level} per change the reader makes
  defp read(e, law, order \\ []) do
    for {_key, target, claims} <- Feed.read([e], law, order) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level)}
    end
  end

  describe "new provisions in place of words" do
    test "paragraphs put in place of a full stop are inserted (S.R. 2010/59 reg. 3(k)(l))" do
      e =
        effect("substituted for full stop", "reg. 3(k)(l)", ["regulation-3-k", "regulation-3-l"])

      assert read(e, "UK_nisr_2010_59") == [
               {"reg.3(k)", :inserted, :provision},
               {"reg.3(l)", :inserted, :provision}
             ]
    end

    test "words that become a paragraph: the paragraph is new (asp 2002/3 s. 57(7)(a))" do
      e = effect("substituted for words", "s. 57(7)(a)", ["section-57-7-a"])
      assert read(e, "UK_asp_2002_3") == [{"s.57(7)(a)", :inserted, :provision}]
    end

    test "with the word beside them, and with the new provisions before the verb" do
      e = effect("substituted for word", "s. 61(6)(b)(iii) and word", ["section-61-6-b-iii"])
      assert read(e, "UK_asp_2003_2") == [{"s.61(6)(b)(iii)", :inserted, :provision}]

      e =
        effect("s. 80(4)(a)(b) substituted for words", "s. 80(4)(a)(b)", [
          "section-80-4-a",
          "section-80-4-b"
        ])

      assert [{_, :inserted, :provision}, {_, :inserted, :provision}] =
               read(e, "UK_ukpga_2003_14")
    end

    test "the words were in another provision (1985 c. 67 s. 26(1A)-(1C); S.R. 2010/160 reg. 3(m)(n))" do
      order = ~w(section-26-1 section-26-1A section-26-1B section-26-1C section-26-2)

      e =
        effect("substituted for words in s. 26(1)", "s. 26(1A)-(1C)", [], [
          {"section-26-1A", "section-26-1C"}
        ])

      assert read(e, "UK_ukpga_1985_67", order) == [
               {"s.26(1A)", :inserted, :provision},
               {"s.26(1B)", :inserted, :provision},
               {"s.26(1C)", :inserted, :provision}
             ]

      e =
        effect("substituted for full stop in reg. 3(l)", "reg. 3(m)(n) and semicolon", [
          "regulation-3-m",
          "regulation-3-n"
        ])

      assert [{"reg.3(m)", :inserted, _}, {"reg.3(n)", :inserted, _}] =
               read(e, "UK_nisr_2010_160")
    end

    test "punctuation or a sum in place of words stays the provision's words" do
      e = effect("semi-colon substituted for full stop", "reg. 6(2)(c)", ["regulation-6-2-c"])
      assert read(e, "UK_nisr_1993_20") == [{"reg.6(2)(c)", :substituted, :words}]

      e = effect("sum substituted for words", "s. 24(6)(a)", ["section-24-6-a"])
      assert read(e, "UK_ukpga_1979_2") == [{"s.24(6)(a)", :substituted, :words}]
    end

    test "not where the feed lands on what holds the provision, not on it" do
      # "Sch. 1 Table 1 semicolon" is placed on the Schedule
      assert FeedSubstitutedFor.inserted(
               "substituted for full stop",
               ["sch.1"],
               "Sch. 1 Table 1 semicolon"
             ) ==
               []

      assert FeedSubstitutedFor.inserted(
               "substituted for words",
               ["sch.2.pt.14"],
               "Sch. 2 Pt. 14 Class G para. G.2(a)(i)(ii)"
             ) == []
    end
  end

  describe "a Type naming none of its targets" do
    test "every target is new (1965 c. 49 s. 39A-39E for ss. 39, 40)" do
      order = ~w(section-39A section-39B section-39C section-39D section-39E section-41)

      e =
        effect("substituted for s. 39 40", "s. 39A-39E", [], [{"section-39A", "section-39E"}])

      assert [
               {"s.39A", :inserted, :provision},
               {"s.39B", :inserted, :provision},
               {"s.39C", :inserted, :provision},
               {"s.39D", :inserted, :provision},
               {"s.39E", :inserted, :provision} | _removed
             ] = read(e, "UK_ukpga_1965_49", order)
    end
  end

  describe "a Type restating only the tail" do
    test "the bracketed number alone (SI 2000/3184 reg. 5(3)(4), reg. 17(6)(6A))" do
      e =
        effect("(3)(4) substituted for (3)", "reg. 5(3)(4)", ["regulation-5-3", "regulation-5-4"])

      assert read(e, "UK_uksi_2000_3184") == [
               {"reg.5(3)", :substituted, :provision},
               {"reg.5(4)", :inserted, :provision}
             ]

      e = effect("substituted for (6)", "reg. 17(6)(6A)", ["regulation-17-6", "regulation-17-6A"])

      assert read(e, "UK_uksi_2000_3184") == [
               {"reg.17(6)", :substituted, :provision},
               {"reg.17(6A)", :inserted, :provision}
             ]
    end

    test "a Schedule's paragraph without its Schedule (1986 c. 53 Sch. 11 para. 6A(2)(b)(c))" do
      assert FeedSubstitutedFor.inserted(
               "substituted for para. 6A(2)(b)",
               ["sch.11.para.6A(2)(b)", "sch.11.para.6A(2)(c)"],
               "Sch. 11 para. 6A(2)(b)(c)"
             ) == ["sch.11.para.6A(2)(c)"]

      assert FeedSubstitutedFor.inserted(
               "substituted for para. 36(2)",
               ["sch.2A.para.36(2)", "sch.2A.para.36(2A)"],
               "Sch. 2A para. 36(2)(2A)"
             ) == ["sch.2A.para.36(2A)"]
    end

    test "a number that is also the provision's own is not mistaken for it" do
      assert FeedSubstitutedFor.inserted(
               "substituted for (3)",
               ["reg.3(3)", "reg.3(3A)"],
               "reg. 3(3)(3A)"
             ) ==
               ["reg.3(3A)"]
    end
  end

  describe "a range of letters" do
    test "counts a to z, then aa to zz, then aaa (EPA 1990 s. 153(1)(a)-(nn))" do
      targets = Enum.map(~w(a b i q z aa ii nn), &"s.153(1)(#{&1})")

      assert FeedSubstitutedFor.inserted(
               "substituted for s. 153(1)(a)-(aaa)",
               targets,
               "s. 153(1)(a)-(nn)"
             ) == []

      assert FeedSubstitutedFor.inserted(
               "substituted for s. 153(1)(qq)-(zz)",
               ["s.153(1)(pp)", "s.153(1)(rr)", "s.153(1)(aaa)"],
               "s. 153(1)(pp)-(aaa)"
             ) == ["s.153(1)(pp)", "s.153(1)(aaa)"]
    end

    test "letters put in between keep their place ((da) after (d); (ba) within (b)-(d))" do
      assert FeedSubstitutedFor.inserted(
               "substituted for art. 54A(3)(b)-(d)",
               ["reg.54A(3)(b)", "reg.54A(3)(ba)", "reg.54A(3)(d)", "reg.54A(3)(da)"],
               "art. 54A(3)(b)-(da)"
             ) == ["reg.54A(3)(da)"]
    end
  end
end
