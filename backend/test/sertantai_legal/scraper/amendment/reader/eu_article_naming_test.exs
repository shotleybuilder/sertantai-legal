defmodule SertantaiLegal.Scraper.Amendment.Reader.EuArticleNamingTest do
  @moduledoc """
  An EU law's amending SIs, read onto its rows (Amending-law reader: EU
  article naming, 2026-11-27): targets spelt as the rows are
  (`art.Article 10(3)`), an EU paragraph's bare number a bracket, a quoted
  Article its own number, and an EU title's own citations no law named.
  Each case is the law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.Reader

  @drivers Reader.law_ref("UK_eur_2006_561", "Regulation (EC) No 561/2006", "art")
  @tacho Reader.law_ref("UK_eur_2014_165", "Regulation (EU) No 165/2014", "art")
  @reach Reader.law_ref("UK_eur_2006_1907", "Regulation (EC) No 1907/2006", "art")
  @clp Reader.law_ref("UK_eur_2008_1272", "Regulation (EC) No 1272/2008", "art")
  @fees Reader.law_ref("UK_eur_2008_340", "Regulation (EC) No 340/2008", "art")

  defp doc(amending, body),
    do:
      Doc.new(amending, [
        ~s(<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>)
      ])

  defp read(doc, id, laws), do: Reader.read(doc, id, %{}, laws)

  # SI 2019/453 reg.63 on the drivers' hours Regulation, Article 10
  @reg63 ~S|<P1 id="regulation-63"><P1para><P2 id="regulation-63-1"><P2para><Text>Article 10 is amended as follows.</Text></P2para></P2><P2 id="regulation-63-3"><P2para><Text>Omit paragraph 3.</Text></P2para></P2><P2 id="regulation-63-4"><P2para><Text>In paragraph 5(a)—</Text><P3 id="regulation-63-4-a"><Pnumber>a</Pnumber><P3para><Text>in point (i), for “Member State” substitute “relevant authority”; and</Text></P3para></P3></P2para></P2></P1para></P1>|
  @lead453 ~S|<P1 id="regulation-62"><P1para><Text>Regulation (EC) No 561/2006 of the European Parliament and of the Council on the harmonisation of certain social legislation relating to road transport is amended as follows.</Text></P1para></P1>|

  describe "the rows' spelling" do
    test "an EU law's targets are spelt as its rows: art.Article N (SI 2019/453 reg.63(3))" do
      d = doc("UK_uksi_2019_453", @lead453 <> @reg63)

      assert [%{amends: "UK_eur_2006_561", targets: targets, operation: :repealed}] =
               read(d, "regulation-63-3", [@drivers])

      assert "art.Article 10(3)" in targets
      refute Enum.any?(targets, &String.starts_with?(&1, "art.1"))
    end

    test "a UK law's targets keep their spelling" do
      ms =
        doc(
          "UK_uksi_2020_1",
          ~S|<P1 id="regulation-2"><P1para><Text>In regulation 5 of the Example Regulations 2010, omit paragraph (3).</Text></P1para></P1>|
        )

      ex = Reader.law_ref("UK_uksi_2010_1", "Example Regulations", "reg")
      assert [%{targets: ["reg.5(3)"]}] = read(ms, "regulation-2", [ex])
    end
  end

  describe "an EU paragraph's bare number" do
    test "\"In paragraph 5(a)—\" is Article 10(5)(a) (SI 2019/453 reg.63(4)(a))" do
      d = doc("UK_uksi_2019_453", @lead453 <> @reg63)

      assert [%{targets: targets, level: :words}] = read(d, "regulation-63-4-a", [@drivers])
      # (the bare (a), (i) beside it are the reader's candidates, kept only where held)
      assert "art.Article 10(5)(a)(i)" in targets
    end
  end

  describe "a quoted Article" do
    # SI 2019/720 Sch.2 para.53 on CLP: two Articles inserted, each a
    # <Part><Number>Article 53A</Number> holding its paragraphs
    @para53 ~S|<P1 id="schedule-2-paragraph-12"><P1para><Text>Regulation (EC) No 1272/2008 of the European Parliament and of the Council of 16 December 2008 on classification, labelling and packaging of substances and mixtures, amending and repealing Directives 67/548/EEC and 1999/45/EC, and amending Regulation (EC) No 1907/2006 is amended in accordance with paragraphs 13 to 57.</Text></P1para></P1><P1 id="schedule-2-paragraph-53"><P1para><Text>After Article 53, insert—</Text><BlockAmendment><Part><Number>Article 53A</Number><P1group><Title>Regulation making power</Title><P1><Pnumber>1</Pnumber><P1para><Text>Any power is exercisable by statutory instrument.</Text></P1para></P1></P1group><P1><Pnumber>2</Pnumber><P1para><Text>Such regulations may—</Text><P3><Pnumber>a</Pnumber><P3para><Text>contain incidental provision; and</Text></P3para></P3></P1para></P1></Part><Part><Number>Article 53B</Number><P1group><Title>The consent requirement</Title><P1><Pnumber>1</Pnumber><P1para><Text>Where any provision of this Regulation states …</Text></P1para></P1></P1group></Part></BlockAmendment></P1para></P1>|

    test "its paragraphs are the Article's, never Articles 1, 2 (SI 2019/720 Sch.2 para.53)" do
      d = doc("UK_uksi_2019_720", @para53)

      targets =
        d
        |> read("schedule-2-paragraph-53", [@clp])
        |> Enum.filter(&(&1.operation == :inserted))
        |> Enum.flat_map(& &1.targets)

      assert "art.Article 53A" in targets
      assert "art.Article 53A(2)(a)" in targets
      assert "art.Article 53B(1)" in targets
      refute Enum.any?(targets, &(&1 in ["art.Article 1", "art.Article 2", "art.1", "art.2"]))
    end
  end

  describe "an EU title's own citations" do
    test "\"… and amending Regulation (EC) No 1907/2006\" in CLP's title names CLP alone (SI 2019/720 Sch.2)" do
      d =
        doc(
          "UK_uksi_2019_720",
          @para53 <>
            ~S|<P1 id="schedule-2-paragraph-40"><P1para><Text>In Article 41, for “inventory” in both places it occurs, substitute “GB notification database”.</Text></P1para></P1>|
        )

      assert [%{amends: "UK_eur_2008_1272"}] = read(d, "schedule-2-paragraph-40", [@reach, @clp])
    end

    test "\"… repealing Council Regulation (EEC) No 3821/85 … and amending Regulation (EC) No 561/2006\" names the tachograph Regulation alone (SI 2019/453 reg.100)" do
      d =
        doc(
          "UK_uksi_2019_453",
          ~S|<P1 id="regulation-99"><P1para><Text>Regulation (EU) No 165/2014 of the European Parliament and of the Council on tachographs in road transport, repealing Council Regulation (EEC) No 3821/85 on recording equipment in road transport and amending Regulation (EC) No 561/2006 of the European Parliament and of the Council on the harmonisation of certain social legislation relating to road transport is amended as follows.</Text></P1para></P1><P1 id="regulation-100"><P1para><Text>In Article 2, omit paragraph 3.</Text></P1para></P1>|
        )

      assert [%{amends: "UK_eur_2014_165", targets: targets}] =
               read(d, "regulation-100", [@drivers, @tacho])

      assert "art.Article 2(3)" in targets
    end

    test "\"… pursuant to Regulation (EC) No 1907/2006 … (REACH)\" in the fees Regulation's title names no law, its defined term neither (SI 2019/758 Sch.6)" do
      d =
        doc(
          "UK_uksi_2019_758",
          ~S|<P1 id="regulation-8"><P1para><Text>Commission Regulation (EC) No 340/2008 on the fees and charges payable to the European Chemicals Agency pursuant to Regulation (EC) No 1907/2006 of the European Parliament and of the Council on the Registration, Evaluation, Authorisation and Restriction of Chemicals (REACH) is amended as follows.</Text></P1para></P1><P1 id="regulation-9"><P1para><Text>Omit Articles 14 and 15.</Text></P1para></P1>|
        )

      terms = %{"reach" => %{law: "UK_eur_2006_1907", title: nil}}

      assert [%{amends: "UK_eur_2008_340", targets: ["art.Article 14", "art.Article 15"]}] =
               Reader.read(d, "regulation-9", terms, [@reach, @fees])
    end
  end
end
