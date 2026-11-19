defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedAffectingSiblingsTest do
  @moduledoc """
  A feed record's affecting provisions with bracketed numbers written
  together ("s. 52(8)(9)") name sibling provisions where a number follows a
  number of its own form, as the feed's own `Section` and `SectionRange`
  children name them; a number of another form is nested ("s. 1(1)(a)")
  (Waste, Water and Climate: Feed reader; Decision 2).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{FeedAffecting, FeedAffectingSiblings}

  describe "refs/1 over numbers written together" do
    # on the School Standards and Framework Act 1998: Sections section-52-8,
    # section-52-9
    test "a number after a number is its sibling" do
      assert FeedAffecting.refs("s. 52(8)(9)") == ["s.52(8)", "s.52(9)"]
    end

    # on the Environmental Protection Act 1990: regulation-30-5,
    # regulation-30-6, regulation-30-7
    test "each number after is one more sibling" do
      assert FeedAffecting.refs("reg. 30(5)(6)(7)") == ["reg.30(5)", "reg.30(6)", "reg.30(7)"]
    end

    # on the New Roads and Street Works Act 1991: article-12-2,
    # article-12-3-a, article-12-4
    test "a letter under a number is nested, the number after it a sibling" do
      assert FeedAffecting.refs("art. 12(2)(3)(a)(4)") ==
               ["reg.12(2)", "reg.12(3)(a)", "reg.12(4)"]
    end

    # on the Criminal Justice Act 2003: article-2-1-a, article-2-2,
    # article-2-3
    test "a number after a letter stands at the number's level" do
      assert FeedAffecting.refs("art. 2(1)(a)(2)(3)") == ["reg.2(1)(a)", "reg.2(2)", "reg.2(3)"]
    end

    # on the Copyright, Designs and Patents Act 1988:
    # schedule-1-paragraph-27-2-a, schedule-1-paragraph-27-2-c
    test "a letter after a letter is its sibling" do
      assert FeedAffecting.refs("Sch. 1 para. 27(2)(a)(c)") ==
               ["sch.1.para.27(2)(a)", "sch.1.para.27(2)(c)"]
    end

    # on the Merchant Shipping Act 1995: schedule-2-paragraph-1-c-i,
    # schedule-2-paragraph-1-c-ii, schedule-2-paragraph-1-c-iii
    test "a roman numeral after a roman numeral is its sibling" do
      assert FeedAffecting.refs("Sch. 2 para. 1(c)(i)(ii)(iii)") ==
               ["sch.2.para.1(c)(i)", "sch.2.para.1(c)(ii)", "sch.2.para.1(c)(iii)"]
    end

    # on the Data Protection Act 2018: section-2-1, section-2-2, and the
    # SectionRange section-2-5 to section-2-7
    test "a range ends the last sibling" do
      assert FeedAffecting.refs("s. 2(1)(2)(5)-(7)") ==
               ["s.2(1)", "s.2(2)", "s.2(5)", "s.2(6)", "s.2(7)"]
    end

    # on the Charities Act 1993: section-40-1, section-40-2, section-40-4
    test "a bare number after siblings continues the last" do
      assert FeedAffecting.refs("s. 40(1)(2) (4) Sch. 6") ==
               ["s.40(1)", "s.40(2)", "s.40(4)", "sch.6"]
    end

    test "bare numbers written together are siblings" do
      assert FeedAffecting.refs("s. 10(2)(a) (4)(5)") == ["s.10(2)(a)", "s.10(4)", "s.10(5)"]
    end
  end

  describe "refs/1 over nesting, unchanged" do
    test "a number of another form is nested" do
      assert FeedAffecting.refs("s. 1(1)(a)") == ["s.1(1)(a)"]
      assert FeedAffecting.refs("reg. 4(2)(a)(i)") == ["reg.4(2)(a)(i)"]
      assert FeedAffecting.refs("s. 7(3)(b)(ii)(A)") == ["s.7(3)(b)(ii)(A)"]
    end

    # on the Tribunals, Courts and Enforcement Act 2007
    test "a doubled letter under a roman numeral is nested" do
      assert FeedAffecting.refs("Sch. 1 para. 12(15)(a)(ii)(aa)") ==
               ["sch.1.para.12(15)(a)(ii)(aa)"]
    end

    # on the Regulatory Reform Act 2001 (section-33-2-b-ii-b) and the Water
    # Act 2014 (article-3-i-i)
    test "the same number again is nested, never its own sibling" do
      assert FeedAffecting.refs("s. 33(2)(b)(ii)(b)") == ["s.33(2)(b)(ii)(b)"]
      assert FeedAffecting.refs("art. 3(i)(i)") == ["reg.3(i)(i)"]
    end

    # on the Customs and Excise Management Act 1979: section-170-4-b-viii-c
    test "a letter after a roman numeral is under it" do
      assert FeedAffecting.refs("s. 170(4)(b)(viii)(c)") == ["s.170(4)(b)(viii)(c)"]
    end

    # on the Transport Act 2000 (section-150-4-h-i) and the Highways Act
    # 1980 (schedule-13-paragraph-119-54-i-j is not held: the feed names
    # …-54-i and …-54-j, one record against the 62 that nest "(h)(i)")
    test "an (i) written with a letter is a roman numeral" do
      assert FeedAffecting.refs("s. 150(4)(h)(i)") == ["s.150(4)(h)(i)"]
      assert FeedAffecting.refs("reg. 19(1)(i)(j)") == ["reg.19(1)(i)(j)"]
    end

    # (xx) is the twentieth: regulation-21-3-b-xx-bb
    test "a doubled letter under a roman numeral written as a doubled letter" do
      assert FeedAffecting.refs("reg. 21(3)(b)(xx)(bb)") == ["reg.21(3)(b)(xx)(bb)"]
    end

    test "a bracket that is no number is left as it is" do
      assert FeedAffecting.refs("s. 5(1)(1 to 3)") == ["s.5(1)(1 to 3)"]
    end
  end

  describe "FeedAffectingSiblings" do
    test "split/1 gives each provision's number" do
      assert FeedAffectingSiblings.split("52(8)(9)") == ["52(8)", "52(9)"]
      assert FeedAffectingSiblings.split("1(1)(a)") == ["1(1)(a)"]
      assert FeedAffectingSiblings.split("4") == ["4"]
      assert FeedAffectingSiblings.split("2A(1)(1A)") == ["2A(1)", "2A(1A)"]
      assert FeedAffectingSiblings.split("3(a)(ii)(b)(i)") == ["3(a)(ii)(b)(i)"]
      assert FeedAffectingSiblings.split("3(1)(a)(ii)(2)(b)") == ["3(1)(a)(ii)", "3(2)(b)"]
      assert FeedAffectingSiblings.split("3(A)(B)") == ["3(A)", "3(B)"]
      assert FeedAffectingSiblings.split("3(i)(v)") == ["3(i)", "3(v)"]
      assert FeedAffectingSiblings.split("3(x)(i)") == ["3(x)(i)"]
      assert FeedAffectingSiblings.split("3(i)(a)") == ["3(i)(a)"]
      assert FeedAffectingSiblings.split("3(i)(k)") == ["3(i)(k)"]
      assert FeedAffectingSiblings.split("3(aa)(bb)") == ["3(aa)", "3(bb)"]
    end

    test "continued/2 gives the numbers a bare bracketed number names" do
      assert FeedAffectingSiblings.continued("10(2)(a)", "(4)") == ["10(4)"]
      assert FeedAffectingSiblings.continued("104(5)(a)", "(b)") == ["104(5)(b)"]
      assert FeedAffectingSiblings.continued("10(2)(a)", "(A)") == ["10(2)(a)(A)"]
      assert FeedAffectingSiblings.continued("4(a)(b)", "(2)") == ["4(2)"]
      assert FeedAffectingSiblings.continued("10(2)", "(4)(5)(a)") == ["10(4)", "10(5)(a)"]
    end
  end
end
