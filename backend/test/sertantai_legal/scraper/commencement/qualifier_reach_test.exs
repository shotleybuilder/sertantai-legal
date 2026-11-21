defmodule SertantaiLegal.Scraper.Commencement.QualifierReachTest do
  @moduledoc """
  A qualifier reaches only the provisions its words reach (RULES
  `a-qualifier-binds-its-own-item`):

  - a closing qualifier pointing back ("…, and sections 222 and 227, and
    Schedule 19, in so far as they relate to those paragraphs") limits the
    items after the paragraphs, never those before (1996 c.52 s.232(2));
  - a bracket bringing in several subsections so far as relating to the
    item ("(and section 115(1) and (2) so far as relating to those Parts
    of those Schedules)") limits them alone (2012 c.9 s.120(5)(b));
  - an order's last item after "… the 2003 Act and section 147 of that Act
    insofar as it relates to those paragraphs" is alone limited (SI
    2004/759 art.8);
  - a Schedule's Part named for its repeals only ("in Part 1 of Schedule
    5, the repeals to …") is partly in, never whole (2005 c.16 s.108(3),
    (4); 2009 c.25 s.182(3)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, OwnClause, Rule}
  alias SertantaiLegal.Scraper.LawStart.{ListItems, PointingBack}

  defp own(law, type, made, rows, ref) do
    rows =
      for {sid, text} <- held() ++ rows, do: %{section_id: "#{law}:#{sid}", text: text, part: nil}

    law
    |> OwnClause.rules(%{type_code: type, rows: rows, made: made, clml_head: nil, lrt_date: nil})
    |> Enum.filter(&(&1.source.ref == ref and is_list(&1.scope)))
  end

  # the rows of the provisions the statements name
  defp held do
    for sid <-
          ~w[s.3 s.4 s.5 s.18 s.35 s.36 s.68 s.81 s.82 s.85 s.88 s.89 s.90 s.91 s.94 s.95 s.113
             s.115(1) s.115(2) s.115(3) s.116 s.119 s.121 s.177(1) s.178 s.221 s.222 s.227
             sch.5.pt.1 sch.5.pt.4 sch.5.pt.6 sch.9.pt.12 sch.10.pt.10 sch.18.para.27 sch.19
             sch.21.para.69 sch.23.pt.3],
        do: {sid, "…"}
  end

  defp full(rules), do: rules |> Enum.filter(&Rule.full?/1) |> Enum.flat_map(& &1.scope)
  defp partly(rules), do: rules |> Enum.reject(&Rule.full?/1) |> Enum.flat_map(& &1.scope)

  describe "the Housing Act 1996 (1996 c.52) s.232(2): a closing qualifier pointing back" do
    setup do
      {:ok,
       rules:
         own(
           "UK_ukpga_1996_52",
           "ukpga",
           ~D[1996-07-24],
           [
             {"s.232(2)",
              "The following provisions of this Act come into force at the end of the period of two months beginning with the date on which this Act is passed— sections 81 and 82 (restriction on termination of tenancy for failure to pay service charge), section 85 (appointment of manager by the court), section 94 (provision of general legal advice about residential tenancies), section 95 (jurisdiction of county courts), section 221 (exercise of compulsory purchase powers in relation to Crown land), paragraph 24 (powers of local housing authorities to acquire land for housing purposes), paragraph 26 (preserved right to buy) and paragraphs 27 to 29 of Schedule 18 (local authority assistance in connection with mortgages), and sections 222 and 227, and Schedule 19 (consequential repeals), in so far as they relate to those paragraphs."}
           ],
           "s.232(2)"
         )}
    end

    test "the sections before the paragraphs are fully in force two months on", %{rules: rules} do
      assert [%Rule{when: {:date, ~D[1996-09-24]}}] = Enum.filter(rules, &Rule.full?/1)
      for ref <- ~w(s.81 s.82 s.85 s.94 s.95 s.221), do: assert(ref in full(rules))
      assert Enum.any?(full(rules), &String.starts_with?(&1, "sch.18.para.27"))
    end

    test "sections 222 and 227 and Schedule 19 alone are so limited", %{rules: rules} do
      assert Enum.sort(partly(rules)) == ~w(s.222 s.227 sch.19)
    end
  end

  describe "PointingBack.split/1" do
    test "the items after the paragraphs pointed back to" do
      assert {"section 221, paragraph 26 and paragraphs 27 to 29 of Schedule 18 (mortgages)",
              "sections 222 and 227, and Schedule 19 (consequential repeals)"} =
               PointingBack.split(
                 "section 221, paragraph 26 and paragraphs 27 to 29 of Schedule 18 (mortgages), and sections 222 and 227, and Schedule 19 (consequential repeals), in so far as they relate to those paragraphs."
               )
    end

    test "nil where no items stand between the paragraphs and the qualifier" do
      assert PointingBack.split(
               "paragraphs 27 to 29 of Schedule 18, in so far as they relate to those paragraphs"
             ) ==
               nil

      assert PointingBack.split("sections 222 and 227 so far as they apply to Wales") == nil
    end
  end

  describe "the Protection of Freedoms Act 2012 (2012 c.9) s.120(5): a bracket's subsections" do
    test "section 113 and the two Parts are full; section 115(1) and (2) so far as relating" do
      rules =
        own(
          "UK_ukpga_2012_9",
          "ukpga",
          ~D[2012-05-01],
          [
            {"s.120(5)",
             "The following provisions come into force on the day on which this Act is passed—"},
            {"s.120(5)(a)", "sections 88 to 91,"},
            {"s.120(5)(b)",
             "section 113, Part 12 of Schedule 9 and Part 10 of Schedule 10 (and section 115(1) and (2) so far as relating to those Parts of those Schedules), and"},
            {"s.120(5)(c)",
             "sections 115(3) to (7) and 116 to 119, this section and section 121."}
          ],
          "s.120(5)"
        )

      for ref <- ~w(s.113 sch.9.pt.12 sch.10.pt.10), do: assert(ref in full(rules))
      assert Enum.sort(partly(rules)) == ["s.115(1)", "s.115(2)"]
    end
  end

  describe "the Clean Neighbourhoods and Environment Act 2005 (2005 c.16) s.108: repeals only" do
    @cnea [
      {"s.108(3)",
       "These provisions come into force in accordance with provision made by order by the Secretary of State—"},
      {"s.108(3)(e)", "section 68 and Part 6 of Schedule 5;"},
      {"s.108(3)(g)",
       "in Part 1 of Schedule 5, the repeal to section 3 of the London Local Authorities Act 2004 (c. i)."},
      {"s.108(4)",
       "These provisions come into force at the end of the period of two months beginning with the day on which this Act is passed—"},
      {"s.108(4)(a)",
       "sections 3 to 5 and, in Part 1 of Schedule 5, the repeals to the Greater London Council (General Powers) Act 1982 (c i) and section 11 of the London Local Authorities Act 2004 (c. i);"},
      {"s.108(4)(b)", "section 18;"},
      {"s.108(4)(e)",
       "sections 35 and 36, and in Part 4 of Schedule 5, the repeals to sections 1 and 2 of the Control of Pollution (Amendment) Act 1989 (c. 14);"}
    ]

    test "s.108(4): the sections are full on 7th June 2005, the Parts of Schedule 5 partly" do
      rules = own("UK_ukpga_2005_16", "ukpga", ~D[2005-04-07], @cnea, "s.108(4)")

      assert Enum.sort(full(rules)) == ~w(s.18 s.3 s.35 s.36 s.4 s.5)
      assert Enum.sort(partly(rules)) == ~w(sch.5.pt.1 sch.5.pt.4)
      assert Enum.all?(rules, &(&1.when == {:date, ~D[2005-06-07]}))
    end

    test "s.108(3): Part 6 of Schedule 5 whole, Part 1's one repeal partly" do
      rules = own("UK_ukpga_2005_16", "ukpga", ~D[2005-04-07], @cnea, "s.108(3)")

      assert Enum.sort(full(rules)) == ~w(s.68 sch.5.pt.6)
      assert partly(rules) == ~w(sch.5.pt.1)
    end

    test "s.108(2)(h): Part 4's repeals are the Part partly, the other repeal no section of this Act" do
      item =
        ListItems.read(
          "section 47, paragraph 4 of Schedule 4 and, in Part 4 of Schedule 5, the repeals to the Environmental Protection Act 1990, other than the repeal to section 33 of that Act;"
        )

      assert item.qualified == "Part 4 of Schedule 5"
      refute item.plain =~ "Schedule 5"
      assert item.plain =~ "section 47, paragraph 4 of Schedule 4"
    end
  end

  describe "the Coroners and Justice Act 2009 (2009 c.25) s.182(3): repeals only" do
    test "Part 3 of Schedule 23 partly, with section 178; the paragraphs full" do
      rules =
        own(
          "UK_ukpga_2009_25",
          "ukpga",
          ~D[2009-11-12],
          [
            {"s.182(3)", "The following provisions come into force on 1 January 2010—"},
            {"s.182(3)(b)",
             "paragraphs 69 to 71 of Schedule 21 (and section 177(1) so far as relating to those provisions);"},
            {"s.182(3)(d)",
             "in Part 3 of Schedule 23, the repeals relating to the Criminal Evidence (Witness Anonymity) Act 2008 (c. 15) (and section 178 so far as relating to those repeals)."}
          ],
          "s.182(3)"
        )

      assert Enum.any?(full(rules), &String.starts_with?(&1, "sch.21.para.69"))
      assert Enum.sort(partly(rules)) == ["s.177(1)", "s.178", "sch.23.pt.3"]
    end
  end

  describe "SI 2004/759 art.8: an order's last item, after the Act's name" do
    test "sections 118 and 119 are fully in force on 1st June 2004; section 147 alone is limited" do
      doc =
        Doc.new("UK_uksi_2004_759", [
          ~s|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the 2003 Act</Term>” means the Local Government Act 2003.</Text></P1para></P1><P1 id="article-8"><P1para><Text>1st June 2004 is the appointed day for the coming into force of sections 118 and 119 of, and paragraphs 9 and 11 of Schedule 9 to, the 2003 Act and section 147 of that Act insofar as it relates to those paragraphs of that Schedule.</Text></P1para></P1></Body></Secondary></Legislation>|
        ])

      rules =
        doc
        |> Order.rules(%{law: "UK_ukpga_2003_26", title: "Local Government Act", year: "2003"})
        |> Enum.filter(&is_list(&1.scope))

      for ref <- ~w(s.118 s.119), do: assert(ref in full(rules))
      assert partly(rules) == ["s.147"]
      assert Enum.all?(rules, &(&1.when == {:date, ~D[2004-06-01]}))
    end
  end
end
