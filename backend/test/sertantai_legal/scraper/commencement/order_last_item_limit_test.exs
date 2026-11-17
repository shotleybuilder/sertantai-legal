defmodule SertantaiLegal.Scraper.Commencement.OrderLastItemLimitTest do
  @moduledoc """
  Fire and OH&S: Labels side by side — a limit after a list's last item
  (", and section 162(1) of the Act in so far as it relates to …") binds
  that item only; the items before it come in fully. A limit set off by a
  comma, or one in the plural after a single provision, is the list's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}

  @epa %{law: "UK_ukpga_1990_43", title: "Environmental Protection Act", year: "1990"}

  defp order(law, sentence),
    do:
      Doc.new(law, [
        ~s|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>In this Order “<Term id="t">the Act</Term>” means the Environmental Protection Act 1990.</Text></P1para></P1><P1 id="article-2"><P1para><Text>#{sentence}</Text></P1para></P1></Body></Secondary></Legislation>|
      ])

  defp rules(law, sentence), do: Order.rules(order(law, sentence), @epa)

  defp rule_of(rules, ref), do: Enum.find(rules, &(is_list(&1.scope) and ref in &1.scope))

  describe "SI 1991/96 reg.2" do
    setup do
      {:ok,
       rules:
         rules(
           "UK_uksi_1991_96",
           "Sections 86(2), (6) to (8), (11), (14) and (15), 88(5), (7), and (9)(b), 89(4), 90(1), (2) and (7), 94(1) and (2) and 96(2) and (3) of the Act, and section 162(1) of the Act in so far as it relates to paragraphs 10(3) and 15(3) to (5) of Schedule 15 to the Act, shall come into force on 14th January 1991."
         )}
    end

    test "the sections before the last item are fully in force on 14th January 1991", %{rules: rs} do
      for ref <- ["s.86(2)", "s.89(4)", "s.96(2)", "s.96(3)"] do
        assert %Rule{when: {:date, ~D[1991-01-14]}, purposes: nil} = rule_of(rs, ref)
      end
    end

    test "section 162(1), the item the limit follows, is partly in force", %{rules: rs} do
      assert %Rule{scope: ["s.162(1)"], when: {:date, ~D[1991-01-14]}, purposes: :in_relation_to} =
               rule_of(rs, "s.162(1)")
    end

    test "the paragraphs it relates to stay as read", %{rules: rs} do
      assert %Rule{purposes: nil} = rule_of(rs, "sch.15.para.10(3)")
    end
  end

  describe "SI 1991/685" do
    test "\"The amendments made by sections 128, 130 and 132 of the Act, and section 162(2) … in so far as it relates to the repeals …\"" do
      rs =
        rules(
          "UK_uksi_1991_685",
          "The amendments made by sections 128, 130 and 132 of the Act, and section 162(2) of the Act in so far as it relates to the repeals to the Countryside Act 1968 and the Wildlife and Countryside Act 1981 in Part VI of Schedule 16 to the Act, shall come into force on 1st April 1991."
        )

      assert %Rule{
               scope: ["s.128", "s.130", "s.132"],
               when: {:date, ~D[1991-04-01]},
               purposes: nil
             } =
               rule_of(rs, "s.130")

      assert %Rule{scope: ["s.162(2)"], purposes: :in_relation_to} = rule_of(rs, "s.162(2)")
      assert rule_of(rs, "sch.16.pt.VI")
    end
  end

  describe "a limit that governs the whole list stays on every item" do
    test "set off by a comma: \"…, and section 162(1) of the Act, in so far as they relate to …\"" do
      rs =
        rules(
          "UK_uksi_1991_96",
          "Sections 89(4) and 96(2) of the Act, and section 162(1) of the Act, in so far as they relate to paragraph 10(3) of Schedule 15 to the Act, shall come into force on 14th January 1991."
        )

      for ref <- ["s.89(4)", "s.96(2)", "s.162(1)"] do
        assert %Rule{purposes: :in_relation_to} = rule_of(rs, ref)
      end
    end

    test "in the plural after a single provision: \"…, and section 162(1) of the Act in so far as they relate to …\"" do
      rs =
        rules(
          "UK_uksi_1991_96",
          "Sections 89(4) and 96(2) of the Act, and section 162(1) of the Act in so far as they relate to paragraph 10(3) of Schedule 15 to the Act, shall come into force on 14th January 1991."
        )

      for ref <- ["s.89(4)", "s.96(2)", "s.162(1)"] do
        assert %Rule{purposes: :in_relation_to} = rule_of(rs, ref)
      end
    end

    test "after the date: \"Section 120(1) of, and Schedule 22 to, the Act come into force … in so far as they relate to …\" (SSI 2015/73)" do
      rs =
        rules(
          "UK_ssi_2015_73",
          "Section 120(1) of, and Schedule 22 to, the Environmental Protection Act 1990 come into force on 1st April 2015 in so far as they relate to paragraph 81 of Schedule 22."
        )

      assert %Rule{purposes: :in_relation_to} = rule_of(rs, "s.120(1)")
    end
  end
end
