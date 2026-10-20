defmodule SertantaiLegal.Scraper.Amendment.ReaderTest do
  @moduledoc "AR-03: an amending provision read once into rules for the laws its notes point to."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Evaluator, Reader}

  @clean_air Reader.law_ref("UK_ukpga_1956_52", "Clean Air Act", "s")

  defp doc(body),
    do:
      Doc.new("UK_ukpga_1968_62", [
        ~s(<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>In this Act “<Term id="t">the principal Act</Term>” means the Clean Air Act 1956.</Text></P1para></P1>#{body}</Body></Primary></Legislation>)
      ])

  defp reached(rules, sid),
    do: for(r <- rules, {:ok, t} <- [Evaluator.reach(r, "UK_ukpga_1956_52:" <> sid)], do: t)

  test "a paragraph substituted by paragraphs: the quote is numbered from the provision holding it (Clean Air Act 1968 s.5(1))" do
    d =
      doc(
        ~S|<P1 id="section-5"><P1para><P2 id="section-5-1"><P2para><Text>In section 7(1) of the principal Act for paragraph (b) there shall be substituted the following paragraphs:—</Text><BlockAmendment><P3><Pnumber>b</Pnumber><P3para><Text>new b</Text></P3para></P3><P3><Pnumber>c</Pnumber><P3para><Text>new c</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-5-1",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.7(1)(c)" in reached(rules, "s.7(1)(c)")
    assert "UK_ukpga_1956_52:s.7(1)(b)" in reached(rules, "s.7(1)(b)")
  end

  test "a law the text doesn't name gets no rule" do
    d =
      doc(
        ~S|<P1 id="section-6"><P1para><Text>In section 3 of the Gas Act 1986, for “x” substitute “y”.</Text></P1para></P1>|
      )

    assert Reader.instruction(d, "section-6", %{}, [@clean_air]) == []
  end

  test "brackets named out of order are a set (\"In paragraph (a) of section 7(2)\")" do
    d =
      doc(
        ~S|<P1 id="section-7"><P1para><Text>In paragraph (a) of section 7(2) of the principal Act, for “x” substitute “y”.</Text></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-7",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.7(2)(a)" in reached(rules, "s.7(2)(a)")
  end

  test "a caption's words are not the verb (SI 1998/1420: \"(… revoked or suspended licences), after subsection (4) insert—\")" do
    d =
      doc(
        ~S|<P1 id="section-13"><P1para><Text>In section 7 of the principal Act (surrender of revoked or suspended licences), after subsection (4) insert—</Text><BlockAmendment><P2><Pnumber>4A</Pnumber><P2para><Text>new</Text></P2para></P2></BlockAmendment></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-13",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert Enum.all?(rules, &(&1.operation == :inserted))
  end

  test "a term named in brackets is not words changed (1989 c.27 s.1(1): \"for section 18 of the … Act 1956 (“the 1956 Act”)\")" do
    d =
      doc(
        ~S|<P1 id="section-14"><P1para><Text>The following section shall be substituted for section 18 of the Clean Air Act 1956 (“the 1956 Act”)—</Text><BlockAmendment><P1><Pnumber>18</Pnumber><P1para><Text>new</Text></P1para></P1></BlockAmendment></P1para></P1>|
      )

    rules = Reader.instruction(d, "section-14", %{}, [@clean_air])

    assert rules != []
    assert Enum.all?(rules, &(&1.operation == :substituted and &1.level == :provision))
  end

  test "quoted words keep their brackets (\"for “(within the meaning of x)” substitute “y”\")" do
    d =
      doc(
        ~S|<P1 id="section-15"><P1para><Text>In section 7 of the principal Act, for “(within the meaning of x)” substitute “y”.</Text></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-15",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert rules != []
    assert Enum.all?(rules, &(&1.level == :words))
  end

  test "an insertion at the end of a named provision is words in it (2025 c.34 s.113(6): \"in subsection (3)(a), at the end (but before the “and”) insert\")" do
    d =
      doc(
        ~S|<P1 id="section-16"><P1para><Text>In section 30 of the principal Act (amount of payment), in subsection (3)(a), at the end (but before the “and”) insert “, or”.</Text></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-16",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.30(3)(a)" in reached(rules, "s.30(3)(a)")
    assert Enum.all?(rules, &(&1.level == :words and &1.operation == :inserted))
  end

  test "a section named at the start of a sentence (\"Section 42 of the 1989 Act is amended as follows\": 2000 c.27 s.57(2))" do
    d =
      doc(
        ~S|<P1 id="section-17"><P1para><Text>Section 7 of the principal Act is amended as follows.</Text><P2 id="section-17-2"><P2para><Text>In subsection (1), paragraph (c) (and the word “and” preceding it) shall cease to have effect.</Text></P2para></P2></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-17-2",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.7(1)(c)" in reached(rules, "s.7(1)(c)")
  end

  describe "AR-04: whole repeals the corpus preview showed overreaching" do
    defp read(id, body),
      do:
        Reader.instruction(
          doc(~s(<P1 id="#{id}"><P1para><Text>#{body}</Text></P1para></P1>)),
          id,
          %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
          [@clean_air]
        )

    test "a modification (\"shall have effect as if … were omitted\": SI 1974/2013) is no amendment" do
      assert read(
               "section-20",
               "Section 7 of the principal Act shall have effect as if any reference to an order were omitted."
             ) == []
    end

    test "an emptied quote is words (\"At the end of subsection (1)(d) “” shall be omitted\": 1991 c.39)" do
      assert [%{level: :words}] =
               read(
                 "section-21",
                 "In section 7 of the principal Act, at the end of subsection (1)(d) “” shall be omitted."
               )
    end

    test "\"each of the following is omitted—\" (a list of words: 2004 c.5) is words" do
      assert [%{level: :words}] =
               read(
                 "section-22",
                 "In section 7 of the principal Act, in subsection (5) each of the following is omitted—"
               )
    end

    test "\"Sections 22 to 25 … are repealed\" is a range (SI 1988/1729)" do
      rules = read("section-23", "Sections 22 to 25 and 33 of the principal Act are repealed.")
      assert "UK_ukpga_1956_52:s.24" in reached(rules, "s.24")
      assert "UK_ukpga_1956_52:s.33" in reached(rules, "s.33")
      assert reached(rules, "s.26") == []
    end
  end

  test "many provisions, each with its brackets: no cap (SSI 2005/658)" do
    d =
      doc(
        ~S|<P1 id="section-2"><P1para><Text>In each of the following provisions of the principal Act, for “a” substitute “b”–section 7(7)(b)(i),section 8(10)(b),section 9(4)(b),section 10(4),section 11(4),section 12(2),section 12(3).</Text></P1para></P1>|
      )

    rules =
      Reader.instruction(
        d,
        "section-2",
        %{"the principal act" => %{law: "UK_ukpga_1956_52", title: "Clean Air Act 1956"}},
        [@clean_air]
      )

    assert "UK_ukpga_1956_52:s.12(3)" in reached(rules, "s.12(3)")
    assert "UK_ukpga_1956_52:s.7(7)(b)(i)" in reached(rules, "s.7(7)(b)(i)")
  end
end
