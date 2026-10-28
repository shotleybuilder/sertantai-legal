defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffectingTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting

  describe "refs/1" do
    test "sections, Schedules, Parts and paragraphs" do
      assert FeedAffecting.refs("Sch. 7 para. 27(2) Sch. 17 Pt. 2") ==
               ["sch.7.para.27(2)", "sch.17.pt.2"]

      assert FeedAffecting.refs("s. 111, Sch. 7") == ["s.111", "sch.7"]
      assert FeedAffecting.refs(nil) == []
    end

    test "an article is named as our provisions name it, reg. (CV-S05 round 7 NEW-6)" do
      # SI 2022/1174 art. 18: its extent list names reg.18 (`Order.ref`)
      assert FeedAffecting.refs("art. 18") == ["reg.18"]
      assert FeedAffecting.refs("art. 3(2)(b), reg. 4") == ["reg.3(2)(b)", "reg.4"]
    end
  end

  describe "ref/1" do
    test "one provision only" do
      assert FeedAffecting.ref("s. 47(1)") == "s.47(1)"
      assert FeedAffecting.ref("art. 2(1)") == "reg.2(1)"
      assert FeedAffecting.ref("Sch. 5 para. 3") == "sch.5.para.3"
      assert FeedAffecting.ref("s. 1, s. 2") == nil
      assert FeedAffecting.ref(nil) == nil
    end
  end

  test "an unnumbered Schedule's paragraph (CV-S07 round 3: SSI 2010/220 \"Sch. para. 3(1)(b)\")" do
    assert FeedAffecting.refs("Sch. para. 3(1)(b)") == ["sch.para.3(1)(b)"]
    assert FeedAffecting.refs("art. 2, Sch. Pt. 1 para. 8(a)(i)") == ["reg.2", "sch.para.8(a)(i)"]
    assert FeedAffecting.refs("Sch.") == []
  end
end
