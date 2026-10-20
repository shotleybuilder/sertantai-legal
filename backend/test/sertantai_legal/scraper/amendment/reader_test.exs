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

  describe "AR-05: a block set out in the amending law's own Schedule" do
    @era Reader.law_ref("UK_ukpga_1996_18", "Employment Rights Act", "s")

    # EReA 1999: the quote is Sch 4's, under wrappers with their own ids
    defp erea(body) do
      quote = fn part, wrapper, ns ->
        ~s(<Part id="schedule-4-part-#{part}"><P1group id="schedule-4-part-#{part}-chapter-1-paragraph-#{wrapper}"><BlockAmendment><Part><Number>Part VIII</Number>) <>
          Enum.map_join(
            ns,
            &~s(<P1group><P1><Pnumber>#{&1}</Pnumber><P1para><P2><Pnumber>1</Pnumber><P2para><Text>new</Text></P2para></P2></P1para></P1></P1group>)
          ) <> "</Part></BlockAmendment></P1group></Part>"
      end

      Doc.new("UK_ukpga_1999_26", [
        ~s(<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>),
        ~s(<Legislation><Primary><Schedules><Schedule id="schedule-4">) <>
          quote.("I", "wrapper2n1", ~w(71 72 80)) <>
          quote.("II", "wrapper3n1", ~w(57A 57B)) <>
          ~s(</Schedule><Schedule id="schedule-1"><P1 id="schedule-1-paragraph-1"><P1para><Text>For section 9 substitute—</Text><BlockAmendment><P1><Pnumber>9</Pnumber><P1para><Text>new</Text></P1para></P1></BlockAmendment></P1para></P1></Schedule></Schedules></Primary></Legislation>)
      ])
    end

    defp era_reached(rules, sid),
      do: for(r <- rules, {:ok, t} <- [Evaluator.reach(r, "UK_ukpga_1996_18:" <> sid)], do: t)

    test "\"The provisions set out in Part I of Schedule 4 shall be substituted for Part VIII of the … Act 1996\" reaches the provisions the Part quotes (EReA 1999 s.7)" do
      d =
        erea(
          ~S|<P1 id="section-7"><P1para><Text>The provisions set out in Part I of Schedule 4 shall be substituted for Part VIII of the Employment Rights Act 1996.</Text></P1para></P1>|
        )

      rules = Reader.instruction(d, "section-7", %{}, [@era])

      assert Enum.all?(rules, &(&1.operation == :substituted and &1.level == :provision))
      assert "UK_ukpga_1996_18:s.72(1)" in era_reached(rules, "s.72(1)")
      assert "UK_ukpga_1996_18:s.80" in era_reached(rules, "s.80")
      assert era_reached(rules, "s.57A") == []
    end

    test "\"… set out in Part II of Schedule 4 shall be inserted after section 57 of that Act\" reaches the sections inserted, not s.57 (EReA 1999 s.8)" do
      d =
        erea(
          ~S|<P1 id="section-7"><P1para><Text>The provisions set out in Part I of Schedule 4 shall be substituted for Part VIII of the Employment Rights Act 1996.</Text></P1para></P1><P1 id="section-8"><P1para><Text>The provisions set out in Part II of Schedule 4 shall be inserted after section 57 of that Act.</Text></P1para></P1>|
        )

      rules = Reader.instruction(d, "section-8", %{}, [@era])

      assert Enum.all?(rules, &(&1.operation == :inserted and &1.level == :provision))
      assert "UK_ukpga_1996_18:s.57B(1)" in era_reached(rules, "s.57B(1)")
      assert era_reached(rules, "s.57") == []
      assert era_reached(rules, "s.72") == []
    end

    test "\"is amended as set out in Schedule 1\" points to the Schedule's own instructions: no block" do
      d =
        erea(
          ~S|<P1 id="section-9"><P1para><Text>The Employment Rights Act 1996 is amended as set out in Schedule 1.</Text></P1para></P1>|
        )

      assert Reader.instruction(d, "section-9", %{}, [@era]) == []
    end
  end

  test "AR-06: a repeals-table line quoting words or naming a definition or entry is words; naming a provision beside a quote is the provision (1991 c.34 Sch 19)" do
    d =
      Doc.new("UK_ukpga_1991_34", [
        ~S"""
        <Legislation><Primary><Schedules><Schedule id="schedule-19"><Tabular><table><tbody>
        <tr><th>Chapter</th><th>Short title</th><th>Extent of repeal</th></tr>
        <tr><td>1982 c. 16</td><td>Civic Government (Scotland) Act 1982</td><td><Para><Text>In section 53(1)(a) “114”.</Text></Para><Para><Text>In section 63(6), the definition of “statutory provision”.</Text></Para><Para><Text>In section 86, the entry relating to the expression “licensing authority”.</Text></Para><Para><Text>In section 33(3)(a), sub-paragraph (ii) and the preceding “and”.</Text></Para><Para><Text>Section 40.</Text></Para><Para><Text>In section 130, in subsection (1) “, in place of the Commission”.</Text></Para><Para><Text>In section 10, in subsection (1), the words “or water development board”.</Text></Para></td></tr>
        </tbody></table></Tabular></Schedule></Schedules></Primary></Legislation>
        """
      ])

    law = Reader.law_ref("UK_ukpga_1982_16", "Civic Government (Scotland) Act", "s")
    rules = Reader.repeal_table(d, "schedule-19", [law])
    level = fn target -> for r <- rules, target in r.targets, do: r.level end

    assert level.("s.53(1)(a)") == [:words]
    assert level.("s.63(6)") == [:words]
    assert level.("s.86") == [:words]
    assert level.("s.33(3)(a)(ii)") == [:provision]
    assert level.("s.40") == [:provision]
    # "in subsection (1)" is where the words are: words, on that subsection
    assert level.("s.130(1)") == [:words]
    assert level.("s.10(1)") == [:words]
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
