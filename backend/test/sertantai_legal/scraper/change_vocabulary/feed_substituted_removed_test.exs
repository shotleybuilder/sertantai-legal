defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedSubstitutedRemovedTest do
  @moduledoc """
  A provision a changes-feed Type says new text was substituted for, where
  the effect does not land on it, is gone: "sch. 1A Pt. C para. 3(b)(i)-(iii)"
  "substituted for sch. 1A Pt. C para. 3(b)(i)-(iv)" (SSI 2014/364 by SSI
  2022/387 reg. 17(4)(b)(ii)) removes (iv) (Waste, Water and Climate: Feed
  reader).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedSubstitutedRemoved}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(type, text, refs, ranges \\ []),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affected_ranges: ranges,
      affecting: "UK_ssi_2022_387",
      in_force_date: ~D[2023-01-01]
    }

  defp read(e, law, order \\ []) do
    for {_key, target, claims} <- Feed.read([e], law, order) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level)}
    end
  end

  describe "the reader" do
    test "the end of the range named, past the range landed on (SSI 2014/364 sch. 1A Pt. C para. 3(b))" do
      e =
        effect(
          "substituted for sch. 1A Pt. C para. 3(b)(i)-(iv)",
          "sch. 1A Pt. C para. 3(b)(i)-(iii)",
          ~w(schedule-1A-part-C schedule-1A-part-C-paragraph-3-b-i schedule-1A-part-C-paragraph-3-b-iii),
          [{"schedule-1A-part-C-paragraph-3-b-i", "schedule-1A-part-C-paragraph-3-b-iii"}]
        )

      read = read(e, "UK_ssi_2014_364")
      [{first, :substituted, :provision} | _] = read
      removed = for {target, :repealed, :provision} <- read, do: target

      # beside the targets, named as they are: (ii) lies in the range landed on
      assert removed == [String.replace_suffix(first, "(i)", "(iv)")]
    end

    test "the paragraph left out of the new text (asp 2004/6 s. 21(8)(a) (b) for (a)-(c))" do
      e =
        effect("substituted for s. 21(8)(a)-(c)", "s. 21(8)(a) (b)", [
          "section-21-8-a",
          "section-21-8-b"
        ])

      assert read(e, "UK_asp_2004_6") == [
               {"s.21(8)(a)", :substituted, :provision},
               {"s.21(8)(b)", :substituted, :provision},
               {"s.21(8)(c)", :repealed, :provision}
             ]
    end

    test "words in place of paragraphs: the paragraphs are gone (asp 2003/2 s. 73(11))" do
      e = effect("words substituted for s. 73(11)(a)(b)", "s. 73(11)", ["section-73-11"])

      assert read(e, "UK_asp_2003_2") == [
               {"s.73(11)", :substituted, :words},
               {"s.73(11)(a)", :repealed, :provision},
               {"s.73(11)(b)", :repealed, :provision}
             ]
    end

    test "the sections new sections took the place of (1965 c. 49 ss. 39, 40)" do
      order = ~w(section-39A section-39B section-41)
      e = effect("substituted for s. 39 40", "s. 39A-39B", [], [{"section-39A", "section-39B"}])

      assert read(e, "UK_ukpga_1965_49", order) == [
               {"s.39A", :inserted, :provision},
               {"s.39B", :inserted, :provision},
               {"s.39", :repealed, :provision},
               {"s.40", :repealed, :provision}
             ]
    end
  end

  describe "removed/4" do
    test "every number of the range named that the effect does not land on" do
      assert FeedSubstitutedRemoved.removed(
               "substituted for Sch. 4 para. 4(3)-(6)",
               "Sch. 4 para. 4(3) (4)",
               ["sch.4.para.4(3)", "sch.4.para.4(4)"],
               :provision
             ) == ["sch.4.para.4(5)", "sch.4.para.4(6)"]
    end

    test "a long list's letters: oo to zz, then aaa (EPA 1990 s. 153(1), SI 2015/479 art. 2)" do
      removed =
        FeedSubstitutedRemoved.removed(
          "substituted for s. 153(1)(a)-(aaa)",
          "s. 153(1)(a)-(nn)",
          ["s.153(1)(a)", "s.153(1)(m)", "s.153(1)(nn)"],
          :provision
        )

      assert removed == Enum.map(~w(oo pp qq rr ss tt uu vv ww xx yy zz aaa), &"s.153(1)(#{&1})")
    end

    test "roman numerals between the ends" do
      assert FeedSubstitutedRemoved.removed(
               "substituted for reg. 4(2)(i)-(vi)",
               "reg. 4(2)(i)(ii)",
               ["reg.4(2)(i)", "reg.4(2)(ii)"],
               :provision
             ) == ["reg.4(2)(iii)", "reg.4(2)(iv)", "reg.4(2)(v)", "reg.4(2)(vi)"]
    end

    test "an EU article's paragraph, named as the target is" do
      assert FeedSubstitutedRemoved.removed(
               "substituted for Art. 15(1)(2)",
               "Art. 15(1)",
               ["art.Article 15(1)"],
               :provision
             ) == ["art.Article 15(2)"]
    end

    test "none where the effect lands on all the Type names, or on more" do
      assert FeedSubstitutedRemoved.removed(
               "substituted for s. 2(3)-(5)",
               "s. 2(3)-(5D)",
               ["s.2(3)", "s.2(5D)"],
               :provision
             ) == []

      assert FeedSubstitutedRemoved.removed(
               "substituted for Art. 15(1)",
               "Art. 15(1)(1A)",
               ["art.Article 15(1)", "art.Article 15(1A)"],
               :provision
             ) == []
    end

    test "none for a provision of another place, words, or an earlier amending provision" do
      # another Schedule's paragraph is no sibling
      assert FeedSubstitutedRemoved.removed(
               "substituted for Sch. 2 para. 3(1)(2)",
               "Sch. 3 para. 3(1)",
               ["sch.3.para.3(1)"],
               :provision
             ) == []

      assert FeedSubstitutedRemoved.removed(
               "substituted for words",
               "s. 6(7)(a)(b)",
               ["s.6(7)(a)"],
               :provision
             ) ==
               []

      assert FeedSubstitutedRemoved.removed(
               "substituted for words in s. 26(1)",
               "s. 26(1A)",
               ["s.26(1A)"],
               :provision
             ) == []

      type =
        "substituted for Art. 2(2A)-(2C) in earlier amending provision S.I. 2019/758, Sch. 1 para. 2(4)"

      assert FeedSubstitutedRemoved.removed(type, "Art. 2(2A)", ["art.Article 2(2A)"], :provision) ==
               []

      # a whole provision is not what its own paragraph was substituted for
      assert FeedSubstitutedRemoved.removed(
               "substituted for s. 5(2)(a)",
               "s. 5(2)",
               ["s.5(2)"],
               :provision
             ) ==
               []

      # numbers run together name nothing surely (1989 c. 29 "s. 6C6D")
      assert FeedSubstitutedRemoved.removed(
               "substituted for s. 6C6D",
               "s. 6C-6CD",
               ["s.6C", "s.6CD"],
               :provision
             ) == []

      assert FeedSubstitutedRemoved.removed("substituted", "s. 1", ["s.1"], :provision) == []
      assert FeedSubstitutedRemoved.removed(nil, nil, ["s.1"], :provision) == []
    end
  end
end
