defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupNoteCitationTest do
  @moduledoc """
  A note's amending law and the provisions it names, where the note's
  pointers are not marked up under its first Citation (Waste, Water and
  Climate: Markup reader, `fallback-pointer-art-for-order`): an Order's
  articles read from the note's words, a copied note (its pieces matched by
  the id before the copy: `markup_copied_note_pieces_test`), and a law
  cited inside the date bracket.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.NoteCitation

  defp cite(id, path, text),
    do: ~s|<Citation id="#{id}" URI="http://www.legislation.gov.uk/id/#{path}">#{text}</Citation>|

  defp sub(citation, section_ref, text, operative \\ false) do
    mark = if operative, do: ~s| Operative="true"|, else: ""

    ~s|<CitationSubRef CitationRef="#{citation}" SectionRef="#{section_ref}"#{mark}>#{text}</CitationSubRef>|
  end

  defp claims(text, attribute) do
    """
    <Legislation><Body>
    <P1 id="section-22"><Pnumber>22</Pnumber><P1para><Text>Some <Addition ChangeId="d30p100" CommentaryRef="c1">words</Addition></Text></P1para></P1>
    </Body><Commentaries><Commentary id="c1" Type="F"><Para><Text>#{text}</Text></Para></Commentary></Commentaries>
    </Legislation>
    """
    |> Markup.read("UK_ukpga_1990_43")
    |> Enum.flat_map(fn {_, _, claims} ->
      for c <- claims, c.attribute == attribute, do: c.value
    end)
  end

  describe "an Order's articles read from the note's words" do
    # EPA 1990 s.153(1)(zz) (c20583771)
    test "{art. 2}: named as the marked-up pieces are, reg.2" do
      text =
        "S. 153(1)(zz) inserted (S.) (6.4.2009) by The Financial Assistance for " <>
          "Environmental Purposes (Scotland) Order (" <>
          cite("x1", "ssi/2009/75", "S.S.I. 2009/75") <> "), {art. 2}"

      assert claims(text, :affecting) == [["reg.2"]]
      assert claims(text, :cited) == ["UK_ssi_2009_75"]
    end

    # EPA 1990 s.84(1)(b) (c20582771)
    test "art. 2(c), {Sch. 3}: the article and the Schedule" do
      text =
        "S. 84(1)(b) repealed (S.) (1.10.2009) by The Public Health etc. (Scotland) Act 2008 " <>
          "(Commencement No. 2, Savings and Consequential Provisions) Order (" <>
          cite("x1", "ssi/2009/319", "S.S.I. 2009/319") <> "), art. 2(c), {Sch. 3}"

      assert claims(text, :affecting) == [["reg.2(c)", "sch.3"]]
    end

    # the Registration of Births … (Scotland) Act 1965 fee note: no Citation
    # link at all, the law read from the words
    test "arts. 1, 2 under a law cited in words only" do
      text =
        "Sum in s. 33A(9) substituted (S.) (1.1.2024) by The Fly-tipping (Fixed Penalty) " <>
          "(Scotland) Order 2023 (S.S.I. 2023/335), arts. 1, 2"

      assert claims(text, :affecting) == [["reg.1", "reg.2"]]
      assert claims(text, :cited_text) == ["UK_ssi_2023_335"]
    end

    test "a section and a regulation keep their names" do
      text =
        "Words substituted by " <>
          cite("x1", "ukpga/2000/27", "2000 c. 27") <> ", s. 108, Sch. 6 para. 33(c)"

      assert claims(text, :affecting) == [["s.108", "sch.6.para.33(c)"]]
    end
  end

  describe "a copied note: its pieces name the Citation's id before the copy" do
    # the Forestry Act 1967 s.8(2)(3): the Citation's id took "n1" in the
    # copy, its pieces' CitationRef did not; the marked piece is read
    # (`CopiedNotePieces`), never the unmarked commencement article
    test "its marked piece, an Order's articles named reg." do
      text =
        "S. 8(2)(3) inserted (16.3.2006) by " <>
          cite("c4i2-00008n1", "uksi/2006/780", "Regulatory Reform (Forestry) Order 2006") <>
          " (S.I. 2006/780), " <>
          sub("c4i2-00008", "article-1-1", "arts. 1(1)") <>
          ", " <> sub("c4i2-00008", "article-3-3", "3(3)", true)

      assert claims(text, :affecting) == [["reg.3(3)"]]
      assert claims(text, :cited) == ["UK_uksi_2006_780"]
    end

    # the Local Government Act 1974 s.26(7)(ba): the copy's
    # words name para. 18(3)(b)(i), its SectionRef still the copied
    # note's 18(3)(a)
    test "the words, not the copied note's SectionRef" do
      text =
        "Words in s. 26(7)(ba) substituted (1.12.2008) by " <>
          cite("d13e4n1", "ukpga/2008/17", "Housing and Regeneration Act 2008 (c. 17)") <>
          ", " <>
          sub("d13e4", "section-325-1", "s. 325(1)") <>
          ", " <> sub("d13e4", "schedule-8-paragraph-18-3-a", "Sch. 8 para. 18(3)(b)(i)")

      assert claims(text, :affecting) == [["s.325(1)", "sch.8.para.18(3)(b)(i)"]]
    end
  end

  describe "a law cited inside the date bracket is not the amending law" do
    # SI 2020/1265 art.34K(b): "(1.1.2024 immediately after S.I. 2023/850
    # comes into force) by … (S.I. 2023/1387), arts. 2(1), 6(3)"
    test "immediately after S.I. 2023/850 comes into force: the law after it" do
      text =
        "Words in art. 34K(b) substituted (E.W.S.) (1.1.2024 immediately after " <>
          cite("d5", "uksi/2023/850", "S.I. 2023/850") <>
          " comes into force) by " <>
          cite("d8", "uksi/2023/1387", "The Order 2023 (S.I. 2023/1387)") <>
          ", " <>
          sub("d8", "article-2-1", "arts. 2(1)") <>
          ", " <>
          sub("d8", "article-6-3", "6(3)", true) <>
          " (which affecting provision is extended to N.I. (1.1.2025) by virtue of " <>
          cite("d18", "uksi/2024/1366", "The Order 2024 (S.I. 2024/1366)") <>
          ", " <>
          sub("d18", "article-2-2-a", "arts. 2(2)(a)") <>
          ", " <> sub("d18", "article-45-2", "45(2)", true) <> ")"

      assert claims(text, :cited) == ["UK_uksi_2023_1387"]
      assert claims(text, :affecting) == [["reg.6(3)"]]
    end

    # the Control of Pollution Act 1974 s.3 (c18883191)
    test "in force as provided by S.I. 1994/1096, art. 3: the Act after \"by\"" do
      text =
        "S. 3 repealed (1.5.1994 save in respect of specified activities, as to which in " <>
          "force as provided by " <>
          cite("c25", "uksi/1994/1096", "S.I. 1994/1096") <>
          ", art. 3, 1.4.2015 for S. in so far as not already in force) by " <>
          cite("c26", "ukpga/1990/43", "Environmental Protection Act 1990 (c. 43)") <>
          ", " <>
          sub("c26", "section-162", "s. 162") <>
          ", " <>
          sub("c26", "schedule-16-part-II", "Sch. 16 Pt. II", true) <>
          "; " <>
          cite("c29", "uksi/1994/1096", "S.I. 1994/1096") <>
          ", " <> sub("c29", "article-2", "arts. 2", true)

      assert claims(text, :cited) == ["UK_ukpga_1990_43"]
      assert claims(text, :affecting) == [["sch.16.pt.II"]]
    end

    test "a closed date bracket, and the bracket round an Order's number, hide nothing" do
      refute NoteCitation.in_date_bracket?("S. 8 inserted (16.3.2006) by The Order (")
      refute NoteCitation.in_date_bracket?("repealed (1.4.1989, in part, and 1.4.1994) by ")
      assert NoteCitation.in_date_bracket?("inserted (1.1.2024 immediately after ")
      assert NoteCitation.in_date_bracket?("(15.11.1999 subject to arts. 5-7 (and 9) of ")
    end

    test "a note citing only inside its date bracket keeps that law" do
      text =
        "S. 3 in force (1.5.1994 as provided by " <>
          cite("c25", "uksi/1994/1096", "S.I. 1994/1096") <> ", art. 3)"

      assert claims(text, :cited) == ["UK_uksi_1994_1096"]
    end
  end

  describe "the amending law is the first Citation after the note's \"by\"" do
    # the Food and Environment Protection Act 1985 s.10: the bracket opens
    # with words, not a date
    test "(in force at 1.5.1994 … art. 3 of S.I. 1994/1096) by the Act" do
      text =
        "Words in s. 10 substituted (in force at 1.5.1994 except for the purposes of " <>
          "specified activities and in force for those excepted purposes in accordance " <>
          "with art. 3 of " <>
          cite("c1", "uksi/1994/1096", "S.I. 1994/1096") <>
          ") by " <>
          cite("c2", "ukpga/1990/43", "Environmental Protection Act 1990 (c.43, SIF 46:4)") <>
          ", " <>
          sub("c2", "section-162-1", "s. 162(1)") <>
          ", " <>
          sub("c2", "schedule-15-paragraph-26", "Sch. 15 para. 26") <>
          "; " <>
          cite("c3", "uksi/1994/1096", "S.I. 1994/1096") <>
          ", " <> sub("c3", "article-2", "arts. 2") <> ", " <> sub("c3", "article-3", "3")

      assert claims(text, :cited) == ["UK_ukpga_1990_43"]
      assert claims(text, :affecting) == [["s.162(1)", "sch.15.para.26"]]
    end

    # the Magistrates' Courts Act 1980 s.126(cc): a bracket inside the
    # date bracket
    test "a law cited in a bracket inside the date bracket" do
      text =
        "S. 126(cc) inserted (4.1.1999 for the purpose of sending any person for trial " <>
          "under s. 51 of the substituting Act from any area specified in " <>
          cite("c1", "uksi/1998/2327", "S.I. 1998/2327") <>
          ", " <>
          sub("c1", "schedule-2", "Sch. 2") <>
          " (as amended by " <>
          cite("c2", "uksi/1998/2412", "S.I. 1998/2412") <>
          " and " <>
          cite("c3", "uksi/2000/924", "S.I. 2000/924") <>
          ") otherwise 15.1.2001) by " <>
          cite("c4", "ukpga/1998/37", "1998 c. 37") <>
          ", " <>
          sub("c4", "section-119", "s. 119") <>
          ", " <>
          sub("c4", "schedule-8-paragraph-45-b", "Sch. 8 para. 45(b)") <>
          "; " <>
          cite("c5", "uksi/1998/2327", "S.I. 1998/2327") <>
          ", " <> sub("c5", "article-4-2-c", "art. 4(2)(c)")

      assert claims(text, :cited) == ["UK_ukpga_1998_37"]
      assert claims(text, :affecting) == [["s.119", "sch.8.para.45(b)"]]
    end

    # the Housing (Scotland) Act 1988 s.26(1): the law that made the words
    # now amended
    test "(as substituted by … 1990 c. 35) substituted (30.8.1993) by 1993 c. 19" do
      text =
        "Words in s. 26(1) (as substituted by Enterprise and New Towns (Scotland) Act " <>
          cite("c1", "ukpga/1990/35", "1990 c. 35") <>
          " ) substituted (30.8.1993) by " <>
          cite("c2", "ukpga/1993/19", "1993 c. 19") <>
          " , " <>
          sub("c2", "section-49-2", "s. 49(2)") <>
          " , " <>
          sub("c2", "schedule-8-paragraph-38-b", "Sch. 8 para. 38(b)") <>
          " ; " <>
          cite("c3", "uksi/1993/1908", "S.I. 1993/1908") <>
          " , " <> sub("c3", "article-2-1", "art. 2(1)")

      assert claims(text, :cited) == ["UK_ukpga_1993_19"]
      assert claims(text, :affecting) == [["s.49(2)", "sch.8.para.38(b)"]]
    end

    # the Social Security Act 1973 s.69: a law named before the "by",
    # outside any bracket
    test "except so far as it relates to … Act 1927 (c. 41) …, by S.I. 1975/1503" do
      text =
        "S. 69 repealed (N.I.), except so far as it relates to so much of the " <>
          cite(
            "c1",
            "ukpga/1927/41",
            "Superannuation and other Trust Funds (Validation) Act 1927 (c. 41)"
          ) <>
          " as extends to Northern Ireland, by " <>
          cite("c2", "nisi/1975/1503", "S.I. 1975/1503 (N.I. 15)") <>
          ", " <>
          sub("c2", "article-74-2", "art. 74(2)") <> ", " <> sub("c2", "schedule-6", "Sch. 6")

      assert claims(text, :cited) == ["UK_nisi_1975_1503"]
      assert claims(text, :affecting) == [["reg.74(2)", "sch.6"]]
    end

    # Regulation (EC) No 852/2004 Art.1(1)(g): the amending provision was
    # itself substituted by Y, so the change is Y's (the feed's affecting
    # law), with Y's pieces
    test "by X (as substituted by Y): Y and its pieces" do
      text =
        "Words in Art. 1(1)(g) substituted (31.12.2020) by " <>
          cite(
            "c1",
            "uksi/2019/642",
            "The General Food Hygiene (Amendment) (EU Exit) Regulations 2019 (S.I. 2019/642)"
          ) <>
          ", " <>
          sub("c1", "regulation-1", "regs. 1") <>
          ", " <>
          sub("c1", "regulation-3-a", "3(a)") <>
          " (as substituted by " <>
          cite("c2", "uksi/2020/1504", "S.I. 2020/1504") <>
          ", " <>
          sub("c2", "regulation-1-2", "regs. 1(2)") <>
          ", " <>
          sub("c2", "regulation-11-2", "11(2)") <>
          "); " <>
          cite("c3", "ukpga/2020/1", "2020 c. 1") <>
          ", " <> sub("c3", "schedule-5-paragraph-1-1", "Sch. 5 para. 1(1)")

      assert claims(text, :cited) == ["UK_uksi_2020_1504"]
      assert claims(text, :affecting) == [["reg.1(2)", "reg.11(2)"]]
    end

    # SI 2012/1715 reg.3(2): X in words only
    test "by X in words (as substituted by Y, in its number bracket): Y" do
      text =
        "Reg. 3(2) substituted (31.12.2020) by S.I. 2019/74, reg. 5 (as substituted by " <>
          "The Air Quality (Amendment) (Northern Ireland Protocol) (EU Exit) (No. 2) " <>
          "Regulations 2020 (" <>
          cite("c1", "uksi/2020/1352", "S.I. 2020/1352") <>
          "), " <>
          sub("c1", "regulation-1", "regs. 1") <>
          ", " <> sub("c1", "regulation-3-2", "3(2)") <> ")"

      assert claims(text, :cited) == ["UK_uksi_2020_1352"]
      assert claims(text, :cited_text) == []
      assert claims(text, :affecting) == [["reg.1", "reg.3(2)"]]
    end

    # the Local Government Act 1972 s.228(6): a date between "inserted"
    # and "by virtue of"
    test "by virtue of X (as inserted (21.7.2020) by virtue of Y): Y" do
      text =
        "Words in s. 228(6) inserted (W.) (temp.) by virtue of S.I. 2020/442, reg. 24(c) " <>
          "(with reg. 19) (as inserted (21.7.2020) by virtue of " <>
          cite(
            "c1",
            "wsi/2020/653",
            "The Local Authorities (Coronavirus) (Meetings) (Wales) (Amendment) Regulations 2020 (S.I. 2020/653)"
          ) <>
          ", " <>
          sub("c1", "regulation-1-2", "regs. 1(2)") <>
          ", " <> sub("c1", "regulation-3", "3") <> ")"

      assert claims(text, :cited) == ["UK_wsi_2020_653"]
      assert claims(text, :affecting) == [["reg.1(2)", "reg.3"]]
    end

    # Decision 2001/171 Art.A1: a law that only amended the amending
    # provision is not the change's (the feed names X)
    test "by X (as amended by Y): X" do
      text =
        "Art. A1 inserted (31.12.2020) by " <>
          cite(
            "c1",
            "uksi/2019/620",
            "The Waste (Miscellaneous Amendments) (EU Exit) Regulations 2019 (S.I. 2019/620)"
          ) <>
          ", " <>
          sub("c1", "regulation-1-2-b", "regs. 1(2)(b)") <>
          ", " <>
          sub("c1", "regulation-14-2", "14(2)") <>
          " (as amended by " <>
          cite("c2", "uksi/2020/1540", "S.I. 2020/1540") <>
          ", " <>
          sub("c2", "regulation-1-3", "regs. 1(3)") <>
          ", " <> sub("c2", "regulation-14-10", "14(10)") <> ")"

      assert claims(text, :cited) == ["UK_uksi_2019_620"]
      assert claims(text, :affecting) == [["reg.1(2)(b)", "reg.14(2)"]]
    end

    # the Companies Act 2006 s.641(7): X in words only, Y only amended it
    test "by X in words (as amended by Y): no linked law, X from the words" do
      text =
        "S. 641(7) inserted (22.4.2014) by S.I. 1991/724, Sch. Pt. 1 (as amended by " <>
          cite(
            "c1",
            "uksi/2014/821",
            "The High Court and County Court Jurisdiction (Amendment) Order 2014 (S.I. 2014/821)"
          ) <>
          ", " <>
          sub("c1", "article-1", "arts. 1") <>
          ", " <> sub("c1", "article-2-10-a-ii", "2(10)(a)(ii)") <> ")"

      assert claims(text, :cited) == []
      assert claims(text, :cited_text) == ["UK_uksi_1991_724"]
    end

    # the Control of Pollution Act 1974: the bracket speaks of the second
    # amending law only
    test "by virtue of X1 and X2 (as inserted by Y): X1" do
      text =
        "Words substituted by virtue of " <>
          cite("c1", "ukpga/1982/48", "Criminal Justice Act 1982 (c. 48)") <>
          ", " <>
          sub("c1", "section-46", "s. 46") <>
          " and " <>
          cite("c2", "ukpga/1975/21", "Criminal Procedure (Scotland) Act 1975 (c. 21)") <>
          ", " <>
          sub("c2", "section-289G", "s. 289G") <>
          " (as inserted by " <>
          cite("c3", "ukpga/1982/48", "Criminal Justice Act 1982 (c. 48)") <>
          ", " <> sub("c3", "section-54", "s. 54") <> ")"

      assert claims(text, :cited) == ["UK_ukpga_1982_48"]
      assert claims(text, :affecting) == [["s.46"]]
    end

    # the Salmon and Freshwater Fisheries (Consolidation) (Scotland) Act
    # 2003 s.64(1)(b): past the unlinked X, only its amender and the
    # commencement order are linked
    test "a commencement order after \";\" is not the amending law" do
      text =
        "S. 64(1)(b) substituted (1.4.2005) by 1989 (c.15), s. 141, Sch. 17 para. 4(a) " <>
          "(as amended by " <>
          cite(
            "c1",
            "asp/2003/15",
            "Salmon and Freshwater Fisheries (Consolidation) (Scotland) Act 2003 (asp 15)"
          ) <>
          ", " <>
          sub("c1", "section-71-2", "s. 71(2)") <>
          "); " <>
          cite("c2", "ssi/2005/174", "S.S.I. 2005/174") <>
          ", " <> sub("c2", "article-2", "art. 2")

      assert claims(text, :cited) == []
    end

    # the Taxes Management Act 1970: this "by" governs no law
    test "a \"by\" with no law after it leaves the note's first law" do
      text =
        cite("c1", "ukpga/1989/26", "Finance Act 1989 (c. 26)") <>
          ", " <>
          sub("c1", "section-156-2-a", "s. 156(2)(a)") <>
          " for tax charged by any assessment notice of which is issued after 30 July 1982"

      assert claims(text, :cited) == ["UK_ukpga_1989_26"]
    end

    test "the bracket round an instrument's number is the Citation's own" do
      text =
        "Words in reg. 4(3A) substituted (W.) (2.6.2026) by The Infrastructure Consent " <>
          "(Wales) Regulations 2026 (W." <>
          cite("c1", "wsi/2026/85", "S.I. 2026/85") <>
          "), " <> sub("c1", "regulation-2-b", "regs. 2(b)")

      assert claims(text, :cited) == ["UK_wsi_2026_85"]
    end

    # the National Health Service (Scotland) Act 1978 s.27(1)(cc): the
    # title's own ";" and "by"
    test "a \";\" in the law's title closes no other law's pieces" do
      text =
        "S. 27(1)(cc) inserted (1.7.1996) by Medicinal Products; Prescription by " <>
          cite("c1", "ukpga/1992/28", "Nurses etc. Act 1992 (c. 28)") <>
          ", " <>
          sub("c1", "section-3", "s. 3") <>
          "; " <>
          cite("c2", "uksi/1996/1505", "S.I. 1996/1505") <>
          ", " <> sub("c2", "article-2", "art. 2")

      assert claims(text, :cited) == ["UK_ukpga_1992_28"]
      assert claims(text, :affecting) == [["s.3"]]
    end
  end
end
