defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedTrailingPartTest do
  @moduledoc """
  A part of a provision the feed writes after it, where the part is no
  provision of its own: its Table ("reg. 6(2) Table 1": SI 2002/3049 by SI
  2023/331 reg. 9(a), "for the table entitled … substitute the table"),
  its proviso ("reg. 15(1) proviso": SI 1986/1078 by SI 1990/1981 reg.
  4(2)(c), "for the proviso there shall be substituted"), a Note, a
  footnote, a Form, a Figure. A whole verb then changes that part: the
  change is within the provision (words level), never the provision
  replaced or repealed. A Form the feed links itself is the target, and a
  provision holding its Table as a row of its own keeps its reading.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedPart}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(text, refs, type \\ "substituted"),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affecting: "UK_uksi_2023_331",
      in_force_date: ~D[2023-04-06]
    }

  # {target, operation, level, heading} per change the reader makes
  defp read(e, law, rows \\ nil) do
    for {_key, target, claims} <- Feed.read([e], law, [], %{}, %{}, %{}, rows) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level), v.(:heading)}
    end
  end

  describe "a provision's Table" do
    test "substituted changes the table, not the provision (SI 2002/3049 reg. 6(2) Table 1)" do
      assert read(effect("reg. 6(2) Table 1", ["regulation-6-2"]), "UK_uksi_2002_3049") ==
               [{"reg.6(2)", :substituted, :words, nil}]
    end

    test "under any name (1997 c.16 s. 11(2) Table; 1994 c.23 s. 57 Table A; 1988 c.52 s. 101, Table)" do
      for {text, refs, law} <- [
            {"s. 11(2) Table", ["section-11-2"], "UK_ukpga_1997_16"},
            {"s. 11(2) table", ["section-11-2"], "UK_ukpga_1997_16"},
            {"s. 57 Table A", ["section-57"], "UK_ukpga_1994_23"},
            {"s. 101, Table", ["section-101"], "UK_ukpga_1988_52"},
            {"Sch. 1 para. 1B tables", ["schedule-1", "schedule-1-paragraph-1B"],
             "UK_ukpga_1994_22"}
          ] do
        assert [{_, :substituted, :words, nil}] = read(effect(text, refs), law), text
      end
    end

    test "in a Schedule and an EU Annex (SI 2007/3100 Sch. 2 Table; EU 2019/631 Annex 2 Pt. B s. 2 Table)" do
      assert read(effect("Sch. 2 Table", ["schedule-2"]), "UK_uksi_2007_3100") ==
               [{"sch.2", :substituted, :words, nil}]

      assert [{_, :substituted, :words, nil}] =
               read(
                 effect("Annex 2 Pt. B s. 2 Table", [
                   "annex-II-part-B",
                   "annex-II-part-B-section-2"
                 ]),
                 "UK_eur_2019_631"
               )
    end

    test "inserted, omitted or renumbered likewise (SI 1986/1078 reg. 7(1) Table; reg. 61 Table 1)" do
      assert [{"reg.7(1)", :inserted, :words, nil}] =
               read(
                 effect("reg. 7(1) Table", ["regulation-7-1"], "inserted"),
                 "UK_uksi_1986_1078"
               )

      assert [{"sch.2", :repealed, :words, nil}] =
               read(effect("sch. 2 Table A", ["schedule-2"], "omitted"), "UK_ssi_2006_209")

      assert [{"reg.61", _, :words, nil}] =
               read(
                 effect("reg. 61 Table 1", ["regulation-61"], "Table renumbered as Table 1"),
                 "UK_uksi_1986_1078"
               )
    end

    test "with its notes, or a note or an entry of it (SSI 2014/364 sch. 1 Table B and notes; NISR 2012/192 reg. 8 Table note 1)" do
      for {text, refs, law} <- [
            {"sch. 1 Table B and notes", ["schedule-1"], "UK_ssi_2014_364"},
            {"reg. 8 Table note 1", ["regulation-8"], "UK_nisr_2012_192"},
            {"reg. 3(2) Table entry", ["regulation-3-2"], "UK_uksi_1986_1078"}
          ] do
        assert [{_, :substituted, :words, nil}] = read(effect(text, refs), law), text
      end
    end

    test "held as a row of its own keeps the reading it has (SI 2008/2095 reg. 4 Table 1; reg. 6 Table 3)" do
      assert read(
               effect("reg. 4 Table 1", ["regulation-4"]),
               "UK_uksi_2008_2095",
               ["reg.4", "reg.4.table.1", "reg.5", "reg.5.table.1"]
             ) == [{"reg.4", :substituted, :provision, nil}]

      # the one table under the regulation, in its paragraph (2)
      assert read(
               effect("reg. 6 Table 3", ["regulation-6"]),
               "UK_uksi_2008_2095",
               ["reg.6", "reg.6(1)", "reg.6(2)", "reg.6(2).table.1"]
             ) == [{"reg.6", :substituted, :provision, nil}]

      # another provision's table is not this one's
      assert read(
               effect("reg. 6 Table 3", ["regulation-6"]),
               "UK_uksi_2008_2095",
               ["reg.6", "reg.60", "reg.60.table.1"]
             ) == [{"reg.6", :substituted, :words, nil}]
    end

    test "a note or an entry of a held table is words all the same (NISR 2012/192 reg. 8 Table note 1; SI 1986/1078 reg. 3(2) Table entry)" do
      assert read(
               effect("reg. 3(2) Table entry", ["regulation-3-2"], "inserted"),
               "UK_uksi_1986_1078",
               ["reg.3(2)", "reg.3(2).table.1"]
             ) == [{"reg.3(2)", :inserted, :words, nil}]

      assert FeedPart.table?("s. 57 Table A")
      assert FeedPart.table?("sch. 1 Table B and notes")
      refute FeedPart.table?("reg. 3(2) Table entry")

      assert read(
               effect("reg. 8 Table note 1", ["regulation-8"]),
               "UK_nisr_2012_192",
               ["reg.8", "reg.8.table.1"]
             ) == [{"reg.8", :substituted, :words, nil}]
    end
  end

  describe "a provision's proviso, Note, footnote, Form and Figure" do
    test "a proviso substituted or repealed (SI 1986/1078 reg. 15(1) proviso; 1947 c.41 s. 15(2) Proviso)" do
      assert read(effect("reg. 15(1) proviso", ["regulation-15-1"]), "UK_uksi_1986_1078") ==
               [{"reg.15(1)", :substituted, :words, nil}]

      assert [{"s.15(2)", :repealed, :words, nil}] =
               read(
                 effect("s. 15(2) Proviso", ["section-15-2"], "repealed (4.1.1995) (S)"),
                 "UK_ukpga_1947_41"
               )
    end

    test "a Note omitted or inserted, never the Schedule (1981 c.69 Sch. 5 Note 2; EU 2019/1021 Annex 1 Pt. A Note (1))" do
      assert read(effect("Sch. 5 Note 2", ["schedule-5"], "omitted"), "UK_ukpga_1981_69") ==
               [{"sch.5", :repealed, :words, nil}]

      for {text, refs, type, law} <- [
            {"Sch. 5 Note 2", ["schedule-5"], "inserted", "UK_ukpga_1981_69"},
            {"Annex 1 Pt. A Note (1)", ["annex-I", "annex-I-part-A"], "omitted",
             "UK_eur_2019_1021"},
            {"Annex 17 NOTE D", ["annex-XVII"], "replacement", "UK_eur_2006_1907"},
            {"Sch. 7A Pt. 2 Group 3 Note 6(2)(b)", ["schedule-7A", "schedule-7A-part-2"],
             "repealed", "UK_ukpga_1994_23"},
            {"Sch. 12 Pt. 3 para. 2 Note", ["schedule-12", "schedule-12-paragraph-2"], "added",
             "UK_ukpga_1986_53"}
          ] do
        assert [{_, _, :words, nil}] = read(effect(text, refs, type), law), text
      end
    end

    test "a footnote and a Figure (EU 2012/27 Annex 4 FOOTNOTE 3; SI 2001/3523 Sch. 2 Figure 1)" do
      assert [{_, :inserted, :words, nil}] =
               read(effect("Annex 4 FOOTNOTE 3", ["annex-IV"], "addition"), "UK_eudr_2012_27")

      assert [{"sch.2", :substituted, :words, nil}] =
               read(effect("Sch. 2 Figure 1", ["schedule-2"]), "UK_uksi_2001_3523")
    end

    test "a Form the feed does not link (SSI 2019/36 sch. 1 Form A1)" do
      assert read(effect("sch. 1 Form A1", ["schedule-1"]), "UK_ssi_2019_36") ==
               [{"sch.1", :substituted, :words, nil}]
    end

    test "a Form the feed links itself is the target, whole (SI 1979/791 sch. 1 form 6A inserted)" do
      refute FeedPart.named?("sch. 1 form 6A", ["schedule-1", "schedule-1-form-6A"])

      assert [{_, :inserted, :provision, nil}] =
               read(
                 effect("sch. 1 form 6A", ["schedule-1", "schedule-1-form-6A"], "inserted"),
                 "UK_uksi_1979_791"
               )
    end
  end

  describe "the heading's other names" do
    test "a side note written as two words (1992 c.12 s. 149A side note)" do
      assert read(effect("s. 149A side note", ["section-149A"]), "UK_ukpga_1992_12") ==
               [{"s.149A", :substituted, :words, true}]
    end

    test "a Type naming the title (1981 c.69 s. 20, title substituted by asp 2020/14 s. 7(5))" do
      assert read(effect("s. 20", ["section-20"], "title substituted"), "UK_ukpga_1981_69") ==
               [{"s.20", :substituted, :words, true}]
    end
  end

  describe "what stays whole" do
    test "the provision itself" do
      assert read(effect("reg. 6(2)", ["regulation-6-2"]), "UK_uksi_2002_3049") ==
               [{"reg.6(2)", :substituted, :provision, nil}]
    end

    test "a provision the feed names after the Table (1992 c.53 Sch. 1 Pt. 1 Table para. 17)" do
      refute FeedPart.named?("Sch. 1 Pt. 1 Table para. 17", ["schedule-1-part-I", "paragraph-17"])
      refute FeedPart.named?("Sch. 4 para.012 Table Pt.I", ["schedule-4-paragraph-12", "part-I"])
    end

    test "no part named" do
      refute FeedPart.named?("s. 20", ["section-20"])
      refute FeedPart.named?(nil, nil)
      refute FeedPart.named?("Explanatory Note", [])
    end
  end
end
