defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedAffectingListTest do
  @moduledoc """
  A feed record's affecting provisions given as a list ("arts. 2 3 Sch. 1",
  "regs 2, 3") or with bare continuations ("art. 3-6 8-10", "s. 10(2)(a)
  (4)", "Sch. 6 paras. 2(4) 7") point to every listed provision, each as a
  ref of its own, as the feed's own `Section` and `SectionRange` children
  name them (Waste, Water and Climate: Feed reader; the parked
  `affecting-plural-list`).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedAffecting}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  describe "refs/1 over a list" do
    # SI 2011/1043 on SSI 2009/247 (Waste, Water and Climate): two
    # SectionRanges, article-3 to article-6 and article-8 to article-10
    test "a second range continues the first's kind" do
      assert FeedAffecting.refs("art. 3-6 8-10") ==
               ["reg.3", "reg.4", "reg.5", "reg.6", "reg.8", "reg.9", "reg.10"]
    end

    # on the Merchant Shipping Act 1995 (Maritime Safety): Sections
    # article-2, article-3, schedule-1
    test "a kind in the plural names each number listed" do
      assert FeedAffecting.refs("arts. 2 3 Sch. 1") == ["reg.2", "reg.3", "sch.1"]
      assert FeedAffecting.refs("regs. 3 5") == ["reg.3", "reg.5"]
      assert FeedAffecting.refs("ss. 34, 208(1)") == ["s.34", "s.208(1)"]
    end

    # on the Health and Safety at Work etc. Act 1974: regulation-3-1,
    # regulation-12
    test "a bare number continues a kind in the singular or the plural" do
      assert FeedAffecting.refs("regs. 3(1) 12") == ["reg.3(1)", "reg.12"]
      assert FeedAffecting.refs("art. 1 2") == ["reg.1", "reg.2"]
      assert FeedAffecting.refs("s. 10(7) 14 15") == ["s.10(7)", "s.14", "s.15"]

      assert FeedAffecting.refs("art. 2 15-18") == [
               "reg.2",
               "reg.15",
               "reg.16",
               "reg.17",
               "reg.18"
             ]
    end

    # on NISI 1997/1774 (OH&S: Occupational): article-2 to article-7 and
    # the unnumbered Schedule
    test "a list before an unnumbered Schedule" do
      assert FeedAffecting.refs("art. 2-7 Sch.") ==
               ["reg.2", "reg.3", "reg.4", "reg.5", "reg.6", "reg.7"]
    end

    test "a kind with no full stop, its numbers parted by commas" do
      assert FeedAffecting.refs("regs 2, 3") == ["reg.2", "reg.3"]
      assert FeedAffecting.refs("regs.2(10),4") == ["reg.2(10)", "reg.4"]
      # regulation-12-1, regulation-12-2, regulation-12-5
      assert FeedAffecting.refs("reg 12(1), (2), (5)") == ["reg.12(1)", "reg.12(2)", "reg.12(5)"]
    end

    # on the Capital Gains Tax Act 1979: schedule-6-paragraph-2-4,
    # schedule-6-paragraph-7; on the Finance Act 1995's: paragraph-31 and
    # the range paragraph-32 to paragraph-35 of Schedule 7
    test "a Schedule's paragraphs in the plural name each paragraph, never the Schedule" do
      assert FeedAffecting.refs("s. 50(2) Sch. 6 paras. 2(4) 7") ==
               ["s.50(2)", "sch.6.para.2(4)", "sch.6.para.7"]

      assert FeedAffecting.refs("s. 79 205 Sch. 7 paras. 31 32-35 Sch. 41 Pt. 5") ==
               ["s.79", "s.205"] ++
                 Enum.map(31..35, &"sch.7.para.#{&1}") ++ ["sch.41.pt.5"]

      assert FeedAffecting.refs("Sch. 1 para. 1 2") == ["sch.1.para.1", "sch.1.para.2"]

      assert FeedAffecting.refs("art. 3 Sch. paras. 2(4) 3(4)") ==
               ["reg.3", "sch.para.2(4)", "sch.para.3(4)"]
    end

    # schedule-10, schedule-10A; schedule-1-part-2, schedule-1-part-3
    test "Schedules and a Schedule's Parts listed" do
      assert FeedAffecting.refs("art. 12 Sch. 10 10A") == ["reg.12", "sch.10", "sch.10A"]
      assert FeedAffecting.refs("art. 2 Schs. 1 2") == ["reg.2", "sch.1", "sch.2"]
      assert FeedAffecting.refs("Sch. 1 Pt. 2 3") == ["sch.1.pt.2", "sch.1.pt.3"]
    end

    # schedule-1-paragraph-10-2-a, paragraph-10-6, paragraph-10-7
    test "a second \"para.\" stays under its Schedule" do
      assert FeedAffecting.refs("Sch. 1 para. 10(2)(a) para. 10(6) (7)") ==
               ["sch.1.para.10(2)(a)", "sch.1.para.10(6)", "sch.1.para.10(7)"]
    end
  end

  describe "refs/1 over a bare bracketed continuation" do
    # section-10-2-a, section-10-4; section-104-5-a, section-104-5-b;
    # schedule-13-paragraph-134-3-c-i, …-c-iii; schedule-7-paragraph-26-2-a-i,
    # …-26-2-a
    test "it stands in place of the last number's part of its own kind" do
      assert FeedAffecting.refs("s. 10(2)(a) (4)") == ["s.10(2)(a)", "s.10(4)"]
      assert FeedAffecting.refs("s. 104(5)(a) (b)") == ["s.104(5)(a)", "s.104(5)(b)"]

      assert FeedAffecting.refs("Sch. 13 para. 134(3)(c)(i) (iii) Sch. 14") ==
               ["sch.13.para.134(3)(c)(i)", "sch.13.para.134(3)(c)(iii)", "sch.14"]

      assert FeedAffecting.refs("Sch. 7 para. 26(2)(a)(i) (a)") ==
               ["sch.7.para.26(2)(a)(i)", "sch.7.para.26(2)(a)"]
    end

    # section-174-3-b-ii-A; schedule-7-paragraph-4-2 (the feed's child for
    # "4(a)(b)" nests them, schedule-7-paragraph-4-a-b; a letter after a
    # letter is its sibling: `FeedAffectingSiblings`)
    test "with no part of its kind a letter goes one level down, a number stands at the top" do
      assert FeedAffecting.refs("s. 174(3)(b)(ii) (A)") ==
               ["s.174(3)(b)(ii)", "s.174(3)(b)(ii)(A)"]

      assert FeedAffecting.refs("Sch. 7 para. 4(a)(b) (2)") ==
               ["sch.7.para.4(a)", "sch.7.para.4(b)", "sch.7.para.4(2)"]
    end

    # section-281-1 and the range section-281-3 to section-281-6
    test "a bracketed range is counted out" do
      assert FeedAffecting.refs("s. 281(1) (3)-(6)") ==
               ["s.281(1)", "s.281(3)", "s.281(4)", "s.281(5)", "s.281(6)"]
    end
  end

  describe "refs/1 reads no number that is not a provision's" do
    test "another law's number, a Note's or a Table's" do
      assert FeedAffecting.refs("reg. 11 1997/2965 reg. 30") == ["reg.11", "reg.30"]
      assert FeedAffecting.refs("Sch. 19(1) Note 1 2") == ["sch.19"]

      assert FeedAffecting.refs("Sch. 23 Pt. 7 para. 1(3) 2 Table 9") ==
               ["sch.23.para.1(3)", "sch.23.para.2"]

      assert FeedAffecting.refs("Sch. 18 Pt. 6(10) Note 1") == ["sch.18.pt.6"]
    end

    test "an \"(adding …)\" tail after a list" do
      assert FeedAffecting.refs("s. 100(1) (3) (adding 1988 c. 1 s. 494AA (5))") ==
               ["s.100(1)", "s.100(3)"]
    end
  end

  test "the feed reader's affecting claim holds every listed provision" do
    id = "key-" <> String.duplicate("c", 4)

    effect = %Effect{
      effect_id: id,
      type: "words substituted",
      affected_provisions: "reg. 5",
      affected_refs: ["regulation-5"],
      affecting: "UK_uksi_2011_1043",
      affecting_provisions: "art. 3-6 8-10",
      in_force: [],
      in_force_date: nil
    }

    [{^id, _target, claims}] = Feed.read([effect], "UK_ssi_2009_247")

    assert Enum.find_value(claims, &(&1.attribute == :affecting && &1.value)) ==
             ["reg.3", "reg.4", "reg.5", "reg.6", "reg.8", "reg.9", "reg.10"]
  end
end
