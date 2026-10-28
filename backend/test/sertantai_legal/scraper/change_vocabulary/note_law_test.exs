defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteLawTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteLaw

  test "a stray space after the slash (HSWA s.28(5)(b) d29p11427)" do
    assert NoteLaw.law(
             "Words in s. 28(5)(b) substituted (14.7.2004) by The Health and Safety at Work etc. Act 1974 (Application outside Great Britain) Order 2004 (S.I. 2004/ 1822), art. 2, {Sch. Pt. 1 para. 8(b)(i)}"
           ) == "UK_uksi_2004_1822"
  end

  test "the first law cited, of each form" do
    assert NoteLaw.law(
             "S. 84(5) repealed (6.3.1992) by Offshore Safety Act 1992 (c. 15), s. 7, Sch. 2"
           ) ==
             "UK_ukpga_1992_15"

    assert NoteLaw.law("Words substituted (14.6.2010) by S.R. 2010/187, reg. 2") ==
             "UK_nisr_2010_187"

    assert NoteLaw.law("Words inserted by S.S.I. 2010/220, sch. para. 3(1)(a)") ==
             "UK_ssi_2010_220"

    assert NoteLaw.law("Words substituted") == nil
  end
end
