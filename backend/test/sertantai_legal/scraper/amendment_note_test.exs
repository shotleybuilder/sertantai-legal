defmodule SertantaiLegal.Scraper.AmendmentNoteTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendmentNote

  @law "UK_ukpga_1991_56"

  defp parse(text, type \\ "amendment"), do: AmendmentNote.parse(text, type, @law)

  describe "effect" do
    test "from the note's verb" do
      assert parse("S. 52(6) substituted (1.4.2006) by , ; Water Act 2003 (c. 37)").effect ==
               "substituted"

      assert parse("S. 57(1D) inserted (31.1.2017) by Policing and Crime Act 2017 (c. 3)").effect ==
               "inserted"

      assert parse("Words in s. 30(3)(a) repealed (1.4.1996) by , 1994 c. 19").effect ==
               "repealed"

      assert parse("Reg. 5 revoked (1.1.2020) by S.I. 2019/1").effect == "repealed"

      assert parse(
               "omitted (31.12.2020) by virtue of , The Air Navigation (Amendment) Order 2020 (S.I. 2020/1555)"
             ).effect == "repealed"

      assert parse("S. 23 renumbered as s. 24 (1.4.2010) by S.I. 2010/1").effect == "renumbered"

      assert parse(
               "S. 6 in force at 20.1.2009 for specified purposes by , S.I. 2009/39",
               "commencement"
             ).effect == "commenced"

      assert parse("Reg. 3 in operation at 5.7.2004, see reg. 1", "commencement").effect ==
               "commenced"

      assert parse(
               "Ss. 1114-1119 applied (with modifications) (1.10.2009) by S.I. 2009/1",
               "modification"
             ).effect == "modified"
    end
  end

  describe "dates" do
    test "a single amendment date" do
      n =
        parse(
          "S. 52(6) substituted (1.4.2006) by , ; Water Act 2003 (c. 37) ss. 22(5) S.I. 2006/984"
        )

      assert n.effective_dates == [~D[2006-04-01]]
      assert n.effective_from == ~D[2006-04-01]
    end

    test "compound dates: all kept, effective_from is the latest" do
      n =
        parse(
          "S. 57(1D) inserted (31.1.2017 for specified purposes, 2.5.2017 in so far as not already in force) by Policing and Crime Act 2017 (c. 3)"
        )

      assert n.effective_dates == [~D[2017-01-31], ~D[2017-05-02]]
      assert n.effective_from == ~D[2017-05-02]

      n =
        parse(
          "Words substituted (1.10.2023 except in relation to W., 1.7.2026 for W.) by S.I. 2023/1"
        )

      assert n.effective_dates == [~D[2023-10-01], ~D[2026-07-01]]
    end

    test "commencement 'in force at' dates" do
      n = parse("in force at 1.4.2018 by , S. 68 S.I. 2018/35 art. 3", "commencement")
      assert n.effective_from == ~D[2018-04-01]
    end

    test "dates in instrument titles or after 'by' are not effective dates" do
      n =
        parse(
          "S. 3 substituted (1.4.2014) by The Energy Act 2013 (Commencement No. 1) Order 2014 (S.I. 2014/251) made 6.2.2014"
        )

      assert n.effective_dates == [~D[2014-04-01]]
    end

    test "undated or Royal Assent notes have no date" do
      assert parse("S. 310 repealed by , Water Act 1973 (c. 37) Sch. 9").effective_from == nil

      assert parse("in force for specified purposes at Royal Assent, see s. 183", "commencement").effective_dates ==
               []
    end

    test "invalid dates are skipped" do
      assert parse("Words substituted (31.2.2020) by S.I. 2020/1").effective_dates == []
    end
  end

  describe "changed_by" do
    test "the first instrument after 'by', as a law name" do
      assert parse(
               "S. 52(6) substituted (1.4.2006) by , ; Water Act 2003 (c. 37) ss. 22(5) 105(3) S.I. 2006/984 art. 2(l)"
             ).changed_by == "UK_ukpga_2003_37"

      assert parse("Words inserted by , S.I. 1986/948 art. 8 Sch.").changed_by ==
               "UK_uksi_1986_948"

      assert parse("Words in s. 30(3)(a) repealed (1.4.1996) by , (with ); 1994 c. 19 ss. 22(3)").changed_by ==
               "UK_ukpga_1994_19"

      assert parse(
               "S. 1 repealed by , (with ); ; (subject to ) Planning and Compensation Act 1991 (c. 34, SIF 123:1) s. 23(7)"
             ).changed_by == "UK_ukpga_1991_34"
    end

    test "devolved and NI instruments" do
      assert parse(
               "S. 61(b) repealed (1.4.2013) by , ; Police and Fire Reform (Scotland) Act 2012 (asp 8) s. 129(2)"
             ).changed_by == "UK_asp_2012_8"

      assert parse(
               "Words inserted (1.1.2025) by Environment (Air Quality and Soundscapes) (Wales) Act 2024 (asc 2) s. 30(3)"
             ).changed_by == "UK_asc_2024_2"

      assert parse(
               "Reg. 2 amended (1.1.2003) by The Water Regulations 2002 (S.I. 2002/324 (W. 37)) reg. 3"
             ).changed_by == "UK_wsi_2002_324"

      assert parse(
               "Art. 3 substituted (1.4.2007) by Electricity (Single Wholesale Market) (Northern Ireland) Order 2007 (S.I. 2007/913 (N.I. 7)) art. 2"
             ).changed_by == "UK_nisi_2007_913"

      assert parse("Reg. 4 revoked (1.4.2013) by S.S.I. 2013/51 art. 2").changed_by ==
               "UK_ssi_2013_51"

      assert parse("Reg. 4 revoked (1.4.2013) by S.R. 2013/51 reg. 2").changed_by ==
               "UK_nisr_2013_51"
    end

    test "citation-only notes (no 'by'): the instrument cited" do
      assert parse("F7 F7 S.I. 1965/1536").changed_by == "UK_uksi_1965_1536"
      assert parse("F115 F115 2013 c.32.").changed_by == "UK_ukpga_2013_32"
      assert parse("F110 F110 1995 c.46.").changed_by == "UK_ukpga_1995_46"
    end

    test "no recognisable instrument → nil" do
      assert parse("Words repealed by , 1990 NI 14").changed_by == nil

      assert parse("Reg. 3 in operation at 5.7.2004, see reg. 1", "commencement").changed_by ==
               nil
    end
  end

  describe "change_id" do
    test "stable for the same law and normalised text; differs by law or text" do
      a = parse("S. 52(6)  substituted (1.4.2006) by Water Act 2003 (c. 37)").change_id
      b = parse(" S. 52(6) substituted (1.4.2006) by Water Act 2003 (c. 37) ").change_id
      assert a == b
      assert byte_size(a) == 32
      refute a == parse("S. 52(7) substituted (1.4.2006) by Water Act 2003 (c. 37)").change_id

      refute a ==
               AmendmentNote.parse(
                 "S. 52(6) substituted (1.4.2006) by Water Act 2003 (c. 37)",
                 "amendment",
                 "UK_x"
               ).change_id
    end
  end

  describe "row_effective/1" do
    test "the latest dated amendment/commencement note wins; modification notes don't count" do
      notes = [
        parse("S. 6 substituted (1.4.2006) by Water Act 2003 (c. 37)"),
        parse("Words in s. 6(2) inserted (1.4.2014) by S.I. 2014/1"),
        parse("S. 6 modified (1.1.2020) by S.I. 2019/9", "modification"),
        parse("S. 6 repealed by Water Act 1973 (c. 37)")
      ]

      assert AmendmentNote.row_effective(notes) == {~D[2014-04-01], "UK_uksi_2014_1"}
    end

    test "same-date notes: deterministic whatever the note order" do
      a = parse("Words in s. 6(1) substituted (1.4.2014) by S.I. 2014/7")
      b = parse("Words in s. 6(2) inserted (1.4.2014) by Water Act 2014 (c. 21)")

      assert AmendmentNote.row_effective([a, b]) == AmendmentNote.row_effective([b, a])
    end

    test "no dated notes → the first note's instrument, no date; no notes → nil" do
      assert AmendmentNote.row_effective([parse("S. 310 repealed by , Water Act 1973 (c. 37)")]) ==
               {nil, "UK_ukpga_1973_37"}

      assert AmendmentNote.row_effective([]) == {nil, nil}
    end
  end
end
