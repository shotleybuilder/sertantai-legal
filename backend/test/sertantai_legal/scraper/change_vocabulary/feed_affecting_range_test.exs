defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedAffectingRangeTest do
  @moduledoc """
  A feed record's affecting provisions given as a range (a `SectionRange`:
  "regs 11-14", "art. 2-4", "art. 11(1)-(3)") point to every provision
  from its start to its end, each as a ref of its own — the shape every
  reader of the `affecting` claim already takes (Fire and OH&S: Feed
  reader). Ends that cannot be counted between (lettered numbers, roman
  numerals) give the two ends.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedAffecting}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  describe "refs/1 over a range" do
    # SI 2000/1335 on SI 1998/2241 (Maritime Safety): "regs 11-14",
    # "regs.8-10" — Start regulation-11, End regulation-14
    test "whole provisions, the kind named in the plural" do
      assert FeedAffecting.refs("regs 11-14") == ["reg.11", "reg.12", "reg.13", "reg.14"]
      assert FeedAffecting.refs("regs.8-10") == ["reg.8", "reg.9", "reg.10"]
    end

    # SI 2004/829 on the Fire Precautions Act 1971's neighbours: "art. 2-4"
    test "an Order's articles, with or without spaces at the dash" do
      assert FeedAffecting.refs("art. 2-4") == ["reg.2", "reg.3", "reg.4"]
      assert FeedAffecting.refs("arts. 2 - 4") == ["reg.2", "reg.3", "reg.4"]
      assert FeedAffecting.refs("ss. 3-5") == ["s.3", "s.4", "s.5"]
    end

    # SI 1994/2421: "art. 11(1)-(3) Sch. 7"
    test "a range of a provision's parts, then another provision" do
      assert FeedAffecting.refs("art. 11(1)-(3) Sch. 7") ==
               ["reg.11(1)", "reg.11(2)", "reg.11(3)", "sch.7"]

      assert FeedAffecting.refs("reg. 3(2)(c)-(e)") ==
               ["reg.3(2)(c)", "reg.3(2)(d)", "reg.3(2)(e)"]
    end

    test "a Schedule's paragraphs, and Schedules" do
      assert FeedAffecting.refs("Sch. 2 para. 3-5") ==
               ["sch.2.para.3", "sch.2.para.4", "sch.2.para.5"]

      assert FeedAffecting.refs("art. 2 Sch. 1 paras. 4(1)-(3)") ==
               ["reg.2", "sch.1.para.4(1)", "sch.1.para.4(2)", "sch.1.para.4(3)"]

      assert FeedAffecting.refs("art. 3 Sch. 1-3") == ["reg.3", "sch.1", "sch.2", "sch.3"]
    end

    test "ends that cannot be counted between give the two ends" do
      assert FeedAffecting.refs("s. 2A-2D") == ["s.2A", "s.2D"]
      assert FeedAffecting.refs("reg. 4(i)-(iv)") == ["reg.4(i)", "reg.4(iv)"]
      assert FeedAffecting.refs("art. 3(2)-(4)(b)") == ["reg.3(2)", "reg.3(4)(b)"]
      assert FeedAffecting.refs("art. 9-4") == ["reg.9", "reg.4"]
    end

    test "a kind in the plural with no range stays unread (a list, not this class)" do
      assert FeedAffecting.refs("regs. 3 5") == []
      assert FeedAffecting.refs("s. 50(2) Sch. 6 paras. 2(4) 7") == ["s.50(2)", "sch.6"]
      assert FeedAffecting.refs("s. 79 Sch. 7 paras. 31 32-35") == ["s.79", "sch.7"]
    end

    test "an \"(adding …)\" tail names the provisions it adds to another law, never the affecting law's" do
      assert FeedAffecting.refs("s. 57(adding1990 c 43 s 78A-78YC)") == ["s.57"]

      assert FeedAffecting.refs("s. 47 Sch. 2 Pt. 2 para. 13 (adding 1949 c. 30 s. 3A(1)-(3))") ==
               ["s.47", "sch.2.para.13"]

      assert FeedAffecting.refs("Sch. 22 para. 93(5)(adding1990 c 43 Sch. 1 Pt. 2 paras. 8-10 )") ==
               ["sch.22.para.93(5)"]

      assert FeedAffecting.refs("s. 39(2) Sch. 6 para. 1(2)(a)(addingto1986 c 53 Sch. 15A)") ==
               ["s.39(2)", "sch.6.para.1(2)(a)"]
    end

    test "a range is never one provision" do
      assert FeedAffecting.ref("art. 2-4") == nil
    end
  end

  test "the feed reader's affecting claim holds every provision of the range" do
    id = "key-" <> String.duplicate("d", 4)

    effect = %Effect{
      effect_id: id,
      type: "revoked",
      affected_provisions: "reg. 5",
      affected_refs: ["regulation-5"],
      affecting: "UK_uksi_2000_1335",
      affecting_provisions: "regs 11-14",
      in_force: [],
      in_force_date: nil
    }

    [{^id, _target, claims}] = Feed.read([effect], "UK_uksi_1998_2241")

    assert Enum.find_value(claims, &(&1.attribute == :affecting && &1.value)) ==
             ["reg.11", "reg.12", "reg.13", "reg.14"]
  end
end
