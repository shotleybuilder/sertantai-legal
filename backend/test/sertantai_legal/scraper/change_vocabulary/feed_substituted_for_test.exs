defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSubstitutedForTest do
  @moduledoc """
  "substituted for Art. 15(1)" over "Art. 15(1)(1A)" (REACH, by SI 2019/556
  reg. 25: "for paragraph 1 substitute— 1 … 1A …"): the Type names what
  the new text was substituted for. The provision it names is substituted;
  a provision the effect lands on beside it, under a number the Type does
  not name, is new text: inserted.
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
      affecting: "UK_uksi_2019_556",
      in_force_date: ~D[2020-12-31]
    }

  # {target, operation, level} per change the reader makes
  defp read(e, law, order \\ []) do
    for {_key, target, claims} <- Feed.read([e], law, order) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level)}
    end
  end

  describe "the reader" do
    test "the number the Type names is substituted, the extra one inserted (REACH Art. 15(1)(1A))" do
      e =
        effect("substituted for Art. 15(1)", "Art. 15(1)(1A)", ["article-15-1", "article-15-1A"])

      assert read(e, "UK_eur_2006_1907") == [
               {"art.Article 15(1)", :substituted, :provision},
               {"art.Article 15(1A)", :inserted, :provision}
             ]
    end

    test "likewise a section's and a regulation's (asp 2000/4 s. 60(3) (3A); S.R. 1995/340 reg. 3(2)(d)(da))" do
      e = effect("substituted for s. 60(3)", "s. 60(3) (3A)", ["section-60-3", "section-60-3A"])

      assert read(e, "UK_asp_2000_4") == [
               {"s.60(3)", :substituted, :provision},
               {"s.60(3A)", :inserted, :provision}
             ]

      e =
        effect("substituted for reg. 3(2)(d)", "reg. 3(2)(d)(da)", [
          "regulation-3-2-d",
          "regulation-3-2-da"
        ])

      assert read(e, "UK_nisr_1995_340") == [
               {"reg.3(2)(d)", :substituted, :provision},
               {"reg.3(2)(da)", :inserted, :provision}
             ]
    end

    test "with the new provisions written before the verb (1984 c. 60 s. 18(5) (5A))" do
      e =
        effect("s. 18(5)(5A) substituted for s. 18(5)", "s. 18(5) (5A)", [
          "section-18-5",
          "section-18-5A"
        ])

      assert read(e, "UK_ukpga_1984_60") == [
               {"s.18(5)", :substituted, :provision},
               {"s.18(5A)", :inserted, :provision}
             ]
    end

    test "a range beyond the range named: the provisions past its end are inserted (S.R. 1997/248 reg. 10(4)-(4C))" do
      order =
        ~w(regulation-10-3 regulation-10-4 regulation-10-4A regulation-10-4B regulation-10-4C regulation-10-5)

      e =
        effect("substituted for reg. 10(4)", "reg. 10(4)-(4C)", [], [
          {"regulation-10-4", "regulation-10-4C"}
        ])

      assert read(e, "UK_nisr_1997_248", order) == [
               {"reg.10(4)", :substituted, :provision},
               {"reg.10(4A)", :inserted, :provision},
               {"reg.10(4B)", :inserted, :provision},
               {"reg.10(4C)", :inserted, :provision}
             ]
    end

    test "every provision named is substituted; a words change is its provision's" do
      e = effect("substituted for s. 2(3)(4)", "s. 2(3)(4)", ["section-2-3", "section-2-4"])
      assert [{_, :substituted, _}, {_, :substituted, _}] = read(e, "UK_asp_2002_3")

      e = effect("words substituted for s. 73(11)(a)(b)", "s. 73(11)", ["section-73-11"])
      assert read(e, "UK_asp_2003_2") == [{"s.73(11)", :substituted, :words}]
    end
  end

  describe "inserted/2" do
    test "the targets the Type does not name" do
      assert FeedSubstitutedFor.inserted("substituted for Art. 15(1)", [
               "art.Article 15(1)",
               "art.Article 15(1A)"
             ]) == ["art.Article 15(1A)"]
    end

    test "siblings written in a row are each named (2010 c. 15 Sch. 12 para. 34(5)-(7))" do
      targets = ["sch.12.para.34(5)", "sch.12.para.34(6)", "sch.12.para.34(7)"]

      assert FeedSubstitutedFor.inserted("substituted for Sch. 12 para. 34(5)(6)", targets) ==
               ["sch.12.para.34(7)"]
    end

    test "a range names what lies within it, by number, letter or roman numeral" do
      assert FeedSubstitutedFor.inserted("substituted for s. 2(3)-(5)", [
               "s.2(3)",
               "s.2(4)",
               "s.2(5)",
               "s.2(5A)",
               "s.2(5D)"
             ]) == ["s.2(5A)", "s.2(5D)"]

      assert FeedSubstitutedFor.inserted("substituted for art. 54A(3)(b)-(d)", [
               "reg.54A(3)(b)",
               "reg.54A(3)(c)",
               "reg.54A(3)(d)",
               "reg.54A(3)(da)"
             ]) == ["reg.54A(3)(da)"]

      assert FeedSubstitutedFor.inserted("substituted for reg. 11(1)(c)(i)-(iii)", [
               "reg.11(1)(c)(i)",
               "reg.11(1)(c)(ii)",
               "reg.11(1)(c)(iii)",
               "reg.11(1)(c)(iv)"
             ]) == ["reg.11(1)(c)(iv)"]
    end

    test "none where the Type names no provision the effect lands on, or is not read" do
      # nothing says which of them the old text was
      assert FeedSubstitutedFor.inserted("substituted for s. 39 40", ["s.39A", "s.39B"]) == []

      assert FeedSubstitutedFor.inserted("substituted for words", ["s.6(7)(a)", "s.6(7)(b)"]) ==
               []

      assert FeedSubstitutedFor.inserted(
               "substituted for words in s. 26(1)",
               ["s.26(1)", "s.26(1A)"]
             ) == []

      assert FeedSubstitutedFor.inserted("substituted", ["s.1", "s.1A"]) == []
      assert FeedSubstitutedFor.inserted(nil, ["s.1"]) == []
    end

    test "none for a change to an earlier amending provision (REACH Art. 2(2A)-(2D), by SI 2020/1577)" do
      type =
        "substituted for Art. 2(2A)-(2C) in earlier amending provision S.I. 2019/758, Sch. 1 para. 2(4)"

      assert FeedSubstitutedFor.inserted(type, ["art.Article 2(2A)", "art.Article 2(2D)"]) == []
    end
  end
end
