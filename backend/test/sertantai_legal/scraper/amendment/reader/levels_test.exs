defmodule SertantaiLegal.Scraper.Amendment.Reader.LevelsTest do
  @moduledoc """
  The level and operation of each change an instruction makes: words, or
  the provision whole (a heading, a mark, a joining word, a quote's
  numbered provisions, a definition's limb), and one rule per operation
  in a clause; each as the real words the reader once misread.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw

  @regs Reader.law_ref("UK_nisr_1997_193", "The Lifts Regulations (Northern Ireland)", "reg")

  defp doc(body, law \\ "UK_nisr_2015_265"),
    do: Doc.new(law, [~s|<Legislation><Secondary><Body>#{body}</Body></Secondary></Legislation>|])

  defp p1(id, text), do: ~s|<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>|

  defp read(d, id, law, terms \\ %{}), do: Reader.instruction(d, id, terms, [law])

  describe "words or the provision whole" do
    test "a heading or a mark itself changed is words; a provision going with its heading is whole" do
      d =
        doc(
          ~s|<P1 id="regulation-6"><P1para><Text>In regulation 6 of the Lifts Regulations (Northern Ireland) 1997—</Text><P2 id="regulation-6-a"><P2para><Text>for the heading substitute “New heading”;</Text></P2para></P2><P2 id="regulation-6-b"><P2para><Text>for the full stop at the end of paragraph (2) substitute a comma; and</Text></P2para></P2></P1para></P1>| <>
            p1(
              "regulation-7",
              "In the Lifts Regulations (Northern Ireland) 1997, omit regulation 27A and the heading preceding it."
            )
        )

      assert [%Rule{level: :words, targets: ["reg.6"]}] = read(d, "regulation-6-a", @regs)
      assert [%Rule{level: :words}] = read(d, "regulation-6-b", @regs)
      assert [%Rule{level: :provision, targets: ["reg.27A"]}] = read(d, "regulation-7", @regs)
    end

    test "a provision omitted with the word joining it goes whole (SI 2018/816 reg.23(1)(b))" do
      d =
        doc(
          p1(
            "regulation-11",
            "In regulation 23 of the Lifts Regulations (Northern Ireland) 1997, in paragraph (1) omit sub-paragraph (b) and the “or” which precedes it."
          )
        )

      assert [%Rule{level: :provision, operation: :repealed}] = read(d, "regulation-11", @regs)
    end

    test "a repeals-table line repealing a provision with its joining word is the provision whole (1989 c.29 Sch.7 on HSWA s.27(2)(b))" do
      d =
        Doc.new("UK_ukpga_1989_29", [
          ~s|<Legislation><Primary><Schedules><Schedule id="schedule-7"><Tabular><table><tbody><tr><th>Chapter</th><th>Short title</th><th>Extent of repeal</th></tr><tr><td>1974 c. 37</td><td>Health and Safety at Work etc. Act 1974</td><td><Para><Text>Section 27(2)(b) and the word “or” immediately preceding it.</Text></Para><Para><Text>Section 1(1)(d) and the word “and” preceding it.</Text></Para><Para><Text>In section 2(1), the word “or”.</Text></Para></td></tr></tbody></table></Tabular></Schedule></Schedules></Primary></Legislation>|
        ])

      hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")
      rules = Reader.repeal_table(d, "schedule-7", [hswa])
      level = fn t -> for r <- rules, t in r.targets, do: r.level end

      assert level.("s.27(2)(b)") == [:provision]
      assert level.("s.1(1)(d)") == [:provision]
      assert level.("s.2(1)") == [:words]
    end
  end

  describe "a quote's provisions" do
    test "a quote numbering provisions makes them whole (NISR 2011/365 reg.4(5))" do
      d =
        doc(
          ~s|<P1 id="regulation-4"><P1para><Text>In regulation 3 of the Lifts Regulations (Northern Ireland) 1997—</Text><P2 id="regulation-4-5"><P2para><Text>In paragraph (l), at the end, for “.” substitute—</Text><BlockAmendment><P3><Pnumber>m</Pnumber><P3para><Text>new m;</Text></P3para></P3><P3><Pnumber>n</Pnumber><P3para><Text>new n.</Text></P3para></P3></BlockAmendment></P2para></P2></P1para></P1>|,
          "UK_nisr_2011_365"
        )

      rules = read(d, "regulation-4-5", @regs)

      assert %Rule{level: :provision, treatment: :quoted} =
               Enum.find(rules, &("reg.3(m)" in &1.targets))
    end

    test "a quoted lone (i) under a lettered paragraph is that paragraph's (2011 c.13 Sch.16 para 119(2)(b))" do
      hswa = Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

      d =
        doc(
          ~s|<P1 id="section-1"><P1para><Text>Section 51A of the Health and Safety at Work etc. Act 1974 is amended as follows.</Text><P2 id="section-1-2"><P2para><Text>In subsection (2)—</Text><P3 id="section-1-2-b"><P3para><Text>in paragraph (c), for “means the person” substitute “means—</Text><BlockAmendment><P4><Pnumber>i</Pnumber><P4para><Text>one</Text></P4para></P4><P4><Pnumber>ii</Pnumber><P4para><Text>two</Text></P4para></P4></BlockAmendment></P3para></P3></P2para></P2></P1para></P1>|,
          "UK_ukpga_2011_13"
        )

      quoted = Enum.find(read(d, "section-1-2-b", hswa), &(&1.treatment == :quoted))
      assert "s.51A(2)(c)(i)" in quoted.targets and "s.51A(2)(c)(ii)" in quoted.targets
    end

    test "a quoted limb of a definition is words in the provision defining (COSHH reg.2(1), SI 2015/21 reg.12(2)(i)(ii))" do
      coshh =
        Reader.law_ref(
          "UK_uksi_2002_2677",
          "The Control of Substances Hazardous to Health Regulations",
          "reg"
        )

      d =
        doc(
          ~s|<P1 id="regulation-12"><P1para><Text>The Control of Substances Hazardous to Health Regulations 2002 are amended as follows.</Text><P2 id="regulation-12-2"><P2para><Text>In regulation 2(1)—</Text><P3 id="regulation-12-2-i"><P3para><Text>in the definition of “substance hazardous to health”—</Text><P4 id="regulation-12-2-i-ii"><P4para><Text>for paragraph (a), substitute—</Text><BlockAmendment><P4><Pnumber>a</Pnumber><P4para><Text>which meets the criteria;</Text></P4para></P4></BlockAmendment></P4para></P4></P3para></P3></P2para></P2></P1para></P1>|,
          "UK_uksi_2015_21"
        )

      rules = read(d, "regulation-12-2-i-ii", coshh)

      level = fn known ->
        for {_key, target, claims} <- AmendingLaw.read(rules, %{}, known),
            %{attribute: :level, value: v} <- claims,
            uniq: true,
            do: {target, v}
      end

      # no row for the limb: words in reg.2(1), never reg.2(1) substituted whole
      assert level.(["reg.2", "reg.2(1)"]) == [{"reg.2(1)", :words}]
      # the limb held as a row: it is substituted whole, once
      assert level.(["reg.2", "reg.2(1)", "reg.2(1)(a)"]) == [{"reg.2(1)(a)", :provision}]
    end

    test "a quote numbering its provision in its text is that provision, not the anchor (SI 1989/682 reg.5(3), SI 2009/606 reg.2(4))" do
      law =
        Reader.law_ref(
          "UK_uksi_1989_682",
          "The Health and Safety Information for Employees Regulations",
          "reg"
        )

      d =
        doc(
          ~s|<P1 id="regulation-2"><P1para><Text>The Health and Safety Information for Employees Regulations 1989 are amended as follows.</Text><P2 id="regulation-2-4"><P2para><Text>After regulation 5(3)(b) insert the following—</Text><BlockAmendment><P2para><Text>; or (c) information as to how any of his employees may obtain the information.</Text></P2para></BlockAmendment></P2para></P2></P1para></P1>|,
          "UK_uksi_2009_606"
        )

      assert [%Rule{targets: ["reg.5(3)(c)"], operation: :inserted, level: :provision}] =
               read(d, "regulation-2-4", law)
    end
  end

  describe "a clause with two operations" do
    @biocidal Reader.law_ref(
                "UK_nisr_2012_255",
                "The Biocidal Products Regulations (Northern Ireland)",
                "reg"
              )

    test "\"add\" is an insertion: each operation its own rule (NISR 2015/339 reg.34(2)(b))" do
      d =
        doc(
          p1(
            "regulation-34",
            "The Biocidal Products Regulations (Northern Ireland) 2012 are amended as follows."
          ) <>
            ~s|<P1 id="regulation-34-2"><P1para><Text>In regulation 8—</Text><P3 id="regulation-34-2-b"><P3para><Text>in paragraph (1), after “a notifier” add “or applicant” and for “2001” substitute “2015”;</Text></P3para></P3></P1para></P1>|,
          "UK_nisr_2015_339"
        )

      ops =
        d
        |> read("regulation-34-2-b", @biocidal)
        |> Enum.map(&{&1.operation, &1.level, &1.targets})

      assert {:inserted, :words, ["reg.8(1)"]} in ops
      assert {:substituted, :words, ["reg.8(1)"]} in ops
    end
  end
end
