defmodule SertantaiLegal.Scraper.NotePointerTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.NotePointer

  @law "UK_ukpga_1991_56"

  defp law(text, type \\ "amendment"), do: NotePointer.law(text, type)

  describe "changed_by" do
    test "the first instrument after 'by', as a law name" do
      assert law(
               "S. 52(6) substituted (1.4.2006) by , ; Water Act 2003 (c. 37) ss. 22(5) 105(3) S.I. 2006/984 art. 2(l)"
             ) == "UK_ukpga_2003_37"

      assert law("Words inserted by , S.I. 1986/948 art. 8 Sch.") ==
               "UK_uksi_1986_948"

      assert law("Words in s. 30(3)(a) repealed (1.4.1996) by , (with ); 1994 c. 19 ss. 22(3)") ==
               "UK_ukpga_1994_19"

      assert law(
               "S. 1 repealed by , (with ); ; (subject to ) Planning and Compensation Act 1991 (c. 34, SIF 123:1) s. 23(7)"
             ) == "UK_ukpga_1991_34"
    end

    test "devolved and NI instruments" do
      assert law(
               "S. 61(b) repealed (1.4.2013) by , ; Police and Fire Reform (Scotland) Act 2012 (asp 8) s. 129(2)"
             ) == "UK_asp_2012_8"

      assert law(
               "Words inserted (1.1.2025) by Environment (Air Quality and Soundscapes) (Wales) Act 2024 (asc 2) s. 30(3)"
             ) == "UK_asc_2024_2"

      assert law(
               "Reg. 2 amended (1.1.2003) by The Water Regulations 2002 (S.I. 2002/324 (W. 37)) reg. 3"
             ) == "UK_wsi_2002_324"

      assert law(
               "Art. 3 substituted (1.4.2007) by Electricity (Single Wholesale Market) (Northern Ireland) Order 2007 (S.I. 2007/913 (N.I. 7)) art. 2"
             ) == "UK_nisi_2007_913"

      assert law("Reg. 4 revoked (1.4.2013) by S.S.I. 2013/51 art. 2") ==
               "UK_ssi_2013_51"

      assert law("Reg. 4 revoked (1.4.2013) by S.R. 2013/51 reg. 2") ==
               "UK_nisr_2013_51"
    end

    test "citation-only notes (no 'by'): the instrument cited" do
      assert law("F7 F7 S.I. 1965/1536") == "UK_uksi_1965_1536"
      assert law("F115 F115 2013 c.32.") == "UK_ukpga_2013_32"
      assert law("F110 F110 1995 c.46.") == "UK_ukpga_1995_46"
    end

    test "no recognisable instrument → nil" do
      assert law("Words repealed by , 1990 NI 14") == nil

      assert law("Reg. 3 in operation at 5.7.2004, see reg. 1", "commencement") ==
               nil
    end
  end

  describe "Welsh SIs (LH-01)" do
    test "\"W.S.I.\" is a Welsh SI" do
      assert law(
               "Pt. 1 amended (1.4.2026) by The Building Regulations (Wales) 2026 (W.S.I. 2026/112), reg. 3"
             ) ==
               "UK_wsi_2026_112"
    end

    test "same_law?/2: equal names, or a Welsh SI and its uksi name" do
      assert NotePointer.same_law?("UK_wsi_2018_35", "UK_uksi_2018_35")
      assert NotePointer.same_law?("UK_uksi_2018_35", "UK_wsi_2018_35")
      assert NotePointer.same_law?("UK_ukpga_1974_37", "UK_ukpga_1974_37")
      refute NotePointer.same_law?("UK_wsi_2018_35", "UK_uksi_2018_36")
      refute NotePointer.same_law?("UK_ssi_2018_35", "UK_uksi_2018_35")
    end
  end

  describe "title citations (LH-06)" do
    test "an SI cited by title and number; a (Wales) title is a Welsh SI" do
      # "for Wales" isn't "(Wales)" (UK SIs say "National Assembly for Wales")
      assert law(
               "Words in s. 12(2) substituted (1.4.2013) by The Natural Resources Body for Wales (Functions) Order 2013 (No. 755), art. 1"
             ) ==
               "UK_uksi_2013_755"

      assert law(
               "Reg. 2 substituted (1.4.2013) by The Water (Wales) Order 2013 (No. 756), art. 1"
             ) ==
               "UK_wsi_2013_756"

      assert law(
               "Reg. 3 amended (1.4.2014) by The Food Hygiene Regulations 2014 (No. 120), reg. 2"
             ) ==
               "UK_uksi_2014_120"
    end

    test "a plain \"S.I.\" behind a (Wales) title is a Welsh SI" do
      assert law(
               "Reg. 14 amended (1.4.2017) by The Water Supply (Wales) Regulations 2017 (S.I. 2017/544), reg. 3"
             ) ==
               "UK_wsi_2017_544"

      # England and Wales is not Wales
      assert law(
               "Reg. 14 amended (1.4.2017) by The Water (England and Wales) Regulations 2017 (S.I. 2017/545), reg. 3"
             ) ==
               "UK_uksi_2017_545"
    end

    test "a Church Measure" do
      assert law(
               "Words in s. 60(3) substituted (1.9.2018) by Ecclesiastical Jurisdiction and Care of Churches Measure 2018 (No. 3), s. 94; S.I. 2018/720"
             ) ==
               "UK_ukcm_2018_3"
    end
  end

  describe "marginal citations (LH-01)" do
    test "an editorial note that only cites a law names no changing instrument" do
      assert law("1906 c. 14.", "extent_editorial") == nil
      assert law("S.I. 1989/840.", "extent_editorial") == nil
    end

    test "an editorial note with \"by\" keeps its instrument" do
      assert law("Extent extended (S.) by S.I. 2001/1, art. 2", "extent_editorial") ==
               "UK_uksi_2001_1"
    end
  end

  describe "change_id" do
    test "stable for the same law and normalised text; differs by law or text" do
      a =
        NotePointer.change_id(@law, "S. 52(6)  substituted (1.4.2006) by Water Act 2003 (c. 37)")

      b =
        NotePointer.change_id(@law, " S. 52(6) substituted (1.4.2006) by Water Act 2003 (c. 37) ")

      assert a == b
      assert byte_size(a) == 32

      refute a ==
               NotePointer.change_id(
                 @law,
                 "S. 52(7) substituted (1.4.2006) by Water Act 2003 (c. 37)"
               )

      refute a ==
               NotePointer.change_id(
                 "UK_x",
                 "S. 52(6) substituted (1.4.2006) by Water Act 2003 (c. 37)"
               )
    end
  end
end
