defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedAffectingTailTest do
  @moduledoc """
  A feed record's affecting provisions may end in a bracket saying what
  the affecting provision does to another law ("(substituting 1968 c 47
  s. 10)", "(amending …)", "(replacing …)", "(modifying …)", "(subst. …)",
  "(am. …)"). The provisions it names are the other law's, never the
  affecting law's own, and the bracket is no part of the number before it
  (Waste, Water and Climate: Feed reader, Decision 2). Every example is a
  real record's text.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting

  describe "refs/1 with a tail naming another law" do
    # 1994 c.39 (the Local Government etc. (Scotland) Act 1994) on itself
    test "(substituting …) attached to a list's last number" do
      assert FeedAffecting.refs("s. 74(4) 102(substituting 1968 c 47 s. 10)") ==
               ["s.74(4)", "s.102"]
    end

    test "(substituting …) after a gap, with a definition named" do
      assert FeedAffecting.refs(
               ~S|Sch. 13 para. 119(53)(a)(iii) (substituting 1980 c 45 s. 109(1) defn.of"limitsofsupply")|
             ) == ["sch.13.para.119(53)(a)(iii)"]
    end

    # 1996 c.23 and 1995 c.36 on themselves, as the feed spells them
    test "(subsituting …) and (substutiting …)" do
      assert FeedAffecting.refs("s. 107(1) Sch. 3 para. 24(subsituting1966 c.041 s. 3)") ==
               ["s.107(1)", "sch.3.para.24"]

      assert FeedAffecting.refs(
               ~S|s. 105(4) Sch. 4 para. 7(6)(b)(c)(substutiting1937 c 37 s. 110(1) defns. of"placeofsafety""residentialestablishment")|
             ) == ["s.105(4)", "sch.4.para.7(6)(b)", "sch.4.para.7(6)(c)"]
    end

    # SI 1997/1414 on the Food Safety Act 1990; 1999 c.16 on itself
    test "(subst. …)" do
      assert FeedAffecting.refs("reg. 3(subst.SI1995/1544 reg. 10(1))") == ["reg.3"]

      assert FeedAffecting.refs(
               "s. 112(4) s. 112(6) 122 Sch. 14 para. 27 (subst. 1991 c. 31 s. 113(1))"
             ) == ["s.112(4)", "s.112(6)", "s.122", "sch.14.para.27"]
    end

    # 1996 c.25 on itself; 1994 c.39; 1994 c.22 on itself
    test "(amending …)" do
      assert FeedAffecting.refs("s. 68 Sch. 2 paras. 5 7(amending.1968 c 19 Sch. 2 para. 1)") ==
               ["s.68", "sch.2.para.5", "sch.2.para.7"]

      assert FeedAffecting.refs("Sch. 13 para. 92(22)(amending1973 c 65 s. 92(2))") ==
               ["sch.13.para.92(22)"]

      assert FeedAffecting.refs("s. 63 Sch. 3 para.002(a)(amendings. 2(13)(a) of 1966 c 18)") ==
               ["s.63", "sch.3.para.002(a)"]
    end

    test "(am. …) and (as am. by …)" do
      assert FeedAffecting.refs("art. 4 (am. S.I.1994/708 art. 2)") == ["reg.4"]
      assert FeedAffecting.refs("s. 45(2)(am.1988 c 39 Sch. 12 para. 2(3))") == ["s.45(2)"]

      assert FeedAffecting.refs("s. 40 Sch. para.026(am.Sch. 2 para. 2 of 1976 c 80)") ==
               ["s.40", "sch.para.026"]

      assert FeedAffecting.refs("s. 3A(3A) (as am. by S.I. 1999/712 reg. 2)") == ["s.3A(3A)"]
    end

    test "(replacing …)" do
      assert FeedAffecting.refs("s. 72 Sch. 3 paras. 6 8(replacing1987 c 38 s.11withs. 11 11A)") ==
               ["s.72", "sch.3.para.6", "sch.3.para.8"]

      assert FeedAffecting.refs("Sch. 17 para. 4 37 (replacing 1988 c. 1 s.749 at s.749A(4)(a))") ==
               ["sch.17.para.4", "sch.17.para.37"]

      assert FeedAffecting.refs("s.014(replacings. 21 of 1964 c 48withs. 21 21A-21C)") == [
               "s.014"
             ]
    end

    # 1996 c.55 on 1990 c.42
    test "a tail word with a capital" do
      assert FeedAffecting.refs("s. 138 Sch. 9 para. 1(Replacing1988 c 48 s. 73)") ==
               ["s.138", "sch.9.para.1"]
    end

    # 1997 c.43 on 1993 c.9
    test "(modifying …)" do
      assert FeedAffecting.refs("Sch. 2 para. 7(2) (modifying1984 c 47 Sch. para. 2)") ==
               ["sch.2.para.7(2)"]

      assert FeedAffecting.refs("Sch. 2 para. 6(1)(2) (modifying[retrosp]1984 c 47 Sch. para. 2)") ==
               ["sch.2.para.6(1)", "sch.2.para.6(2)"]
    end

    test "(inserting …), (insertedby…), (extending …), (reprinting …), (and see …)" do
      assert FeedAffecting.refs("reg.002(6)(insertingSch. para. 4Binto1995/402)") ==
               ["reg.002(6)"]

      assert FeedAffecting.refs("arts. 3(b) 4 4A(insertedbySI1997/1536)") ==
               ["reg.3(b)", "reg.4", "reg.4A"]

      assert FeedAffecting.refs("art. 2 (extending 1996/500 to S.)") == ["reg.2"]

      assert FeedAffecting.refs(
               "reg. 3 Sch. 3 (reprinting as am. & cont. in pt. SR&O 1933/789 Pt. 8 para. 91A(2))"
             ) == ["reg.3", "sch.3"]

      assert FeedAffecting.refs("s. 18(1)(and see S.I.1999 /1075)") == ["s.18(1)"]
    end

    # 1994 c.40 on 1992 c.53
    test "a tail saying what was added to another law" do
      assert FeedAffecting.refs("s. 35 Sch. 10 Pt. 1 para.001(3)(s. 3A-3Daddedto1973 c 65)") ==
               ["s.35", "sch.10.para.001(3)"]
    end

    test "a tail with no closing bracket runs to the end" do
      assert FeedAffecting.refs("s. 104 Sch. 14 para. 55(substituting 1988 c 35 s. 11(7)") ==
               ["s.104", "sch.14.para.55"]
    end
  end

  describe "refs/1 with a bracket of our own" do
    test "a bracketed sub-number stays, whatever its letters" do
      assert FeedAffecting.refs("s. 208(4)(ac)") == ["s.208(4)(ac)"]
      assert FeedAffecting.refs("art. 3(aaa)") == ["reg.3(aaa)"]
      assert FeedAffecting.refs("reg. 2(n)(xxviii)") == ["reg.2(n)(xxviii)"]
      assert FeedAffecting.refs("Sch. 1 para. 1(ss)") == ["sch.1.para.1(ss)"]
      assert FeedAffecting.refs("art. 4(am)") == ["reg.4(am)"]
      assert FeedAffecting.refs("s. 10(2)(a) (4)") == ["s.10(2)(a)", "s.10(4)"]
    end

    # the bracket lists the affecting law's own provisions
    test "(and regs …) names the affecting law's own provisions" do
      assert FeedAffecting.refs("reg.19 (and regs 2-18, schs.1-15)") ==
               FeedAffecting.refs("reg.19 and regs 2-18, schs.1-15")
    end
  end
end
