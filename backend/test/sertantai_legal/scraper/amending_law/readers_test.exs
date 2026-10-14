defmodule SertantaiLegal.Scraper.AmendingLaw.ReadersTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{
    Commencement,
    DefinedTerms,
    Doc,
    Operation,
    RepealTable,
    RowRef,
    Target,
    Text
  }

  @dir "test/fixtures/amending_law"
  defp doc,
    do:
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

  defp electricity(sid), do: RowRef.new("UK_ukpga_1989_29:" <> sid, "Electricity Act")
  defp gas(sid), do: RowRef.new("UK_ukpga_1986_44:" <> sid, "Gas Act")

  test "DefinedTerms: a term's law from its definition's Citation, else its title" do
    terms = DefinedTerms.of(doc())
    assert terms["the 1989 act"] == %{law: "UK_ukpga_1989_29", title: "Electricity Act 1989"}
    assert terms["the 1986 act"] == %{law: nil, title: "Gas Act 1986"}
  end

  test "Operation: the drafting verb, words-level when words are quoted or named" do
    op = fn s -> Operation.of(%Text{id: "x", instruction: s}) end

    assert op.("After subsection (5) of that section there is inserted—") ==
             {"inserted", "inserted"}

    assert op.("In subsection (2) for “public electricity supplier” there is substituted .") ==
             {"substituted", "words substituted"}

    assert op.(
             "In subsection (5) of that section, paragraphs (b) and (c) shall cease to have effect."
           ) == {"repealed", "repealed"}

    assert op.("In section 3, omit the words “the public”.") == {"repealed", "words repealed"}
    assert op.("For section 4 substitute—") == {"substituted", "substituted"}
    assert op.("The 1989 Act is amended as follows.") == nil
  end

  test "Commencement: by order, except the provisions it names; an SI's date; passing" do
    d = doc()
    assert Commencement.of(d, "section-60-5") == :by_order
    assert Commencement.of(d, "schedule-6-paragraph-33-c") == :by_order
    assert Commencement.of(d, "section-68") == :unknown

    si =
      Doc.new("UK_uksi_2000_1937", [
        ~s(<Legislation><Secondary><Body><P1 id="regulation-1"><P1para><Text>These Regulations may be cited as the Gas Regulations 2000 and shall come into force on 10th August 2000.</Text></P1para></P1><P1 id="regulation-5"><P1para><Text>Omit regulation 3.</Text></P1para></P1></Body></Secondary></Legislation>)
      ])

    assert Commencement.of(si, "regulation-5") == {:date, ~D[2000-08-10], "regulation-1"}

    act =
      Doc.new("UK_ukpga_1995_1", [
        ~s(<Legislation xmlns:ukm="m"><ukm:EnactmentDate Date="1995-03-01"/><Primary><Body><P1 id="section-9"><P1para><Text>This Act shall come into force at the end of the period of two months beginning with the day on which it is passed.</Text></P1para></P1></Body></Primary></Legislation>)
      ])

    assert Commencement.of(act, "section-2") == {:date, ~D[1995-05-01], "section-9"}
  end

  test "Target: the text names the row's law and provision — else no match" do
    d = doc()
    terms = DefinedTerms.of(d)
    t = fn id, row -> Target.match(Text.of(d, id), Doc.title(d, id), terms, row) end

    # "The 1989 Act is amended" (context) + "subsection (5) of that section" (section 25) + inserted (5A)
    assert t.("section-60-5", electricity("s.25(5A)")) == {:ok, "UK_ukpga_1989_29:s.25(5A)"}
    assert t.("section-60-4", electricity("s.25(5)(b)")) == {:ok, "UK_ukpga_1989_29:s.25(5)(b)"}
    # the same instruction doesn't name section 26, nor the Gas Act
    assert t.("section-60-5", electricity("s.26(5A)")) == :no_match
    assert t.("section-60-5", gas("s.25(5A)")) == :no_match
    # a Schedule paragraph under a Part titled with the law
    assert t.("schedule-6-paragraph-33-c", electricity("s.40(2)")) ==
             {:ok, "UK_ukpga_1989_29:s.40(2)"}

    assert t.("schedule-6-paragraph-33-c", electricity("s.40(3)")) == :no_match
    # an instruction naming another law (the 1986 Act) never matches the 1989 Act
    assert t.("section-68", electricity("s.3")) == :no_match
    assert t.("section-68", gas("s.3")) == {:ok, "UK_ukpga_1986_44:s.3"}
  end

  test "RepealTable: a row of a repeals Schedule naming the row's law and provision" do
    d = doc()

    assert RepealTable.match(d, "schedule-8", electricity("s.36")) ==
             {:ok, "UK_ukpga_1989_29:s.36", "repealed"}

    assert RepealTable.match(d, "schedule-8", electricity("s.42")) ==
             {:ok, "UK_ukpga_1989_29:s.42", "repealed"}

    assert RepealTable.match(d, "schedule-8", electricity("s.40")) ==
             {:ok, "UK_ukpga_1989_29:s.40", "words repealed"}

    assert RepealTable.match(d, "schedule-8", electricity("s.37")) == :no_match
    assert RepealTable.match(d, "schedule-8", gas("s.36")) == :no_match
    assert RepealTable.match(d, "schedule-6", electricity("s.36")) == :not_a_table
    assert RepealTable.reference(d, "schedule-8") == "section-108"
  end

  test "RepealTable, modern form: Reference / Extent of repeal or revocation, entries per line" do
    d = Doc.new("UK_ukpga_2002_40", [File.read!("#{@dir}/ukpga_2002_40_schedules.xml")])
    row = fn sid, title -> RowRef.new(sid, title) end

    assert RepealTable.match(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.56C(7)", "Electricity Act")
           ) ==
             {:ok, "UK_ukpga_1989_29:s.56C(7)", "repealed"}

    assert RepealTable.match(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.56C(6)", "Electricity Act")
           ) == :no_match

    assert RepealTable.match(
             d,
             "schedule-26",
             row.("UK_ukpga_1989_29:s.57(1)", "Electricity Act")
           ) ==
             {:ok, "UK_ukpga_1989_29:s.57(1)", "words repealed"}

    assert RepealTable.match(
             d,
             "schedule-26",
             row.("UK_ukpga_1949_88:s.11A(1)(b)", "Registered Designs Act")
           ) ==
             {:ok, "UK_ukpga_1949_88:s.11A(1)(b)", "repealed"}

    assert RepealTable.match(
             d,
             "schedule-26",
             row.("UK_ukpga_1968_29:s.28(5A)", "Trade Descriptions Act")
           ) ==
             {:ok, "UK_ukpga_1968_29:s.28(5A)", "repealed"}

    assert RepealTable.reference(d, "schedule-26") == "section-278"
  end

  describe "Target truth guards (benchmark review)" do
    alias SertantaiLegal.Scraper.AmendingLaw.Text

    defp tx(instruction, opts \\ []),
      do: struct!(Text, [id: "x", instruction: instruction, quoted: "", context: []] ++ opts)

    test "inserted words beginning 'a' are not an inserted paragraph (a) (1990/43 s.6(2)(a))" do
      text =
        tx(
          "In section 6 of the Environmental Protection Act 1990, in subsection (2) after the words “shall be accompanied by” there shall be inserted—.",
          quoted: "a fee and a charge"
        )

      row = RowRef.new("UK_ukpga_1990_43:s.6(2)(a)", "Environmental Protection Act")
      assert Target.match(text, nil, %{}, row) == :no_match

      assert Target.match(
               text,
               nil,
               %{},
               RowRef.new("UK_ukpga_1990_43:s.6(2)", "Environmental Protection Act")
             ) == {:ok, "UK_ukpga_1990_43:s.6(2)"}
    end

    test "an inserted provision's own number counts (Pnumber in the quote)" do
      text =
        tx("In section 98(2) after paragraph (c) insert—.",
          inserted: [["ca"]],
          context: ["In the Water Industry Act 1991—"]
        )

      assert Target.match(
               text,
               nil,
               %{},
               RowRef.new("UK_ukpga_1991_56:s.98(2)(ca)", "Water Industry Act")
             ) == {:ok, "UK_ukpga_1991_56:s.98(2)(ca)"}
    end

    test "a law named only in quoted old words doesn't count; the nearest law-naming text decides" do
      row = RowRef.new("UK_ukpga_1990_43:s.142(7)", "Environmental Protection Act")
      quoted_old = tx("In section 142(7), for “Explosive Substances Act 1875” substitute .")

      assert Target.match(quoted_old, "Environmental Protection Act 1990", %{}, row) ==
               {:ok, "UK_ukpga_1990_43:s.142(7)"}

      other = tx("In section 142(7) of the Gas Act 1986, for “x” substitute .")
      assert Target.match(other, "Environmental Protection Act 1990", %{}, row) == :no_match
    end
  end

  test "an inserted provision matches by its full path in the quote, not by numbers found anywhere in it" do
    xml =
      ~s(<Legislation><Primary><Body><P1 id="section-35"><P1para><Text>After section 11 of the Electricity Act 1989 there is inserted—</Text><BlockAmendment><P1group><P1><Pnumber>11A</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><P3><Pnumber>b</Pnumber></P3></P2para></P2><P2><Pnumber>7</Pnumber><P2para><Text>text</Text></P2para></P2></P1para></P1></P1group></BlockAmendment></P1para></P1></Body></Primary></Legislation>)

    d = Doc.new("UK_ukpga_2000_27", [xml])
    t = Text.of(d, "section-35")
    assert t.inserted == [["11A"], ["11A", "1"], ["11A", "1", "b"], ["11A", "7"]]

    m = fn sid ->
      Target.match(t, nil, %{}, RowRef.new("UK_ukpga_1989_29:" <> sid, "Electricity Act"))
    end

    assert m.("s.11A(1)(b)") == {:ok, "UK_ukpga_1989_29:s.11A(1)(b)"}
    assert m.("s.11A(7)") == {:ok, "UK_ukpga_1989_29:s.11A(7)"}
    # (7)(b) isn't in the inserted text: added later by another law
    assert m.("s.11A(7)(b)") == :no_match
  end
end
