defmodule SertantaiLegal.Scraper.Commencement.AmendingOwnClauseFormsTest do
  @moduledoc """
  An amending law's own commencement clause, the forms of the Fire and OH&S
  round's amending laws (LAT Change Pipeline, step Commencement reader):
  citation sentences ("may cited as", "which may be cited as", "except as
  provided in paragraphs …"), a date the revised text brackets, a list
  item counting from the day the item before it names, and a day left to
  a named authority's order.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingCommencement
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}

  defp rows(specs),
    do: for({sid, text} <- specs, do: %{section_id: "UK_x:" <> sid, text: text})

  defp read(specs, opts) do
    OwnClause.rules("UK_x", %{
      type_code: Keyword.get(opts, :type, "uksi"),
      rows: rows(specs),
      made: opts[:made],
      clml_head: opts[:head],
      lrt_date: opts[:lrt_date]
    })
  end

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_x") |> hd()))

  describe "the citation sentence's date" do
    test "\"may cited as\" (SI 1991/259 reg.1)" do
      rules =
        read(
          [
            {"reg.1",
             "These Regulations may cited as the Fire Precautions (Sub-surface Railway Stations) (Amendment) Regulations 1991, and shall come into force on 1st April 1991."}
          ],
          lrt_date: ~D[1991-04-01]
        )

      assert lines(rules) == ["all — 1991-04-01 — everywhere, fully — clause_date"]
    end

    test "a date the revised text brackets (SI 1999/2463 reg.1)" do
      rules =
        read(
          [
            {"reg.1",
             "These Regulations may be cited as the Mines (Control of Ground Movement) Regulations 1999 and shall come into force on [1st December 1999]."}
          ],
          lrt_date: ~D[1999-12-01]
        )

      assert lines(rules) == ["all — 1999-12-01 — everywhere, fully — clause_date"]
    end

    test "\"which may be cited as … shall come into force on\" (SI 2007/765 reg.1(1))" do
      rules =
        read(
          [
            {"reg.1(1)",
             "These Regulations which may be cited as the Smoke-free (Exemptions and Vehicles) Regulations 2007 shall come into force on 1st July 2007."}
          ],
          lrt_date: ~D[2007-07-01]
        )

      assert lines(rules) == ["all — 2007-07-01 — everywhere, fully — clause_date"]
    end

    test "\"and except as provided in paragraphs (2), (3) and (4) shall come into operation on\" (NISR 2011/127 reg.1)" do
      rules =
        read(
          [
            {"reg.1(1)",
             "These Regulations may be cited as the Waste Regulations (Northern Ireland) 2011 and except as provided in paragraphs (2), (3) and (4) shall come into operation on 8th April 2011."},
            {"reg.1(2)", "Regulation 17 shall come into operation on 8th October 2011."},
            {"reg.17", ""}
          ],
          lrt_date: ~D[2011-04-08]
        )

      assert lines(rules) == [
               "all — 2011-04-08 — everywhere, fully — clause_date",
               "reg.17 — 2011-10-08 — everywhere, fully — provision_dated"
             ]
    end
  end

  describe "an amending law's rows from its CLML (doc_rows/1)" do
    @reg2 ~s|<Legislation><Secondary><Body><P1 id="regulation-2"><Pnumber>2</Pnumber><P1para><P2 id="regulation-2-1"><Pnumber>1</Pnumber><P2para><Text>These Regulations (except regulation <InternalLink Ref="regulation-4-2" id="i00004">4(2)</InternalLink> and <InternalLink Ref="regulation-4-5" id="i00005">(5)</InternalLink>) come into force on 7th January 2019.</Text></P2para></P2><P2 id="regulation-2-2"><Pnumber>2</Pnumber><P2para><Text>Regulation <InternalLink Ref="regulation-4-2" id="i00006">4(2)</InternalLink> and <InternalLink Ref="regulation-4-5" id="i00007">(5)</InternalLink> comes into force on 7th April 2019.</Text></P2para></P2></P1para></P1><P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text>In these Regulations <Term id="term-the-act">the Act</Term> means the Environmental Protection Act 1990.</Text></P1para></P1><P1 id="regulation-4"><Pnumber>4</Pnumber><P1para><P2 id="regulation-4-2"><Pnumber>2</Pnumber><P2para><Text>Omit regulation 3.</Text></P2para></P2><P2 id="regulation-4-5"><Pnumber>5</Pnumber><P2para><Text>Omit regulation 6.</Text></P2para></P2></P1para></P1></Body></Secondary></Legislation>|

    test "a cross-reference's and a defined term's words stay in the text (SI 2018/1227 reg.2)" do
      rows = "UK_uksi_2018_1227" |> Doc.new([@reg2]) |> OwnClause.doc_rows()
      text = fn id -> Enum.find(rows, &(&1.section_id == "UK_uksi_2018_1227:" <> id)).text end

      assert text.("reg.2(1)") ==
               "These Regulations (except regulation 4(2) and (5)) come into force on 7th January 2019."

      assert text.("reg.2(2)") == "Regulation 4(2) and (5) comes into force on 7th April 2019."
      assert text.("reg.3") =~ "the Act means the Environmental Protection Act 1990"
      # a provision's own sub-provisions are still their own rows
      assert text.("reg.2") == ""
    end

    test "provisions the clause dates apart never take the general date (SI 2018/1227 reg.2)" do
      doc = Doc.new("UK_uksi_2018_1227", [@reg2])

      rules =
        OwnClause.rules("UK_uksi_2018_1227", %{
          type_code: "uksi",
          made: ~D[2018-11-22],
          rows: OwnClause.doc_rows(doc)
        })

      assert AmendingCommencement.commenced_on(rules, "regulation-4-2") == ~D[2019-04-07]
      assert AmendingCommencement.commenced_on(rules, "regulation-4-5") == ~D[2019-04-07]
      assert AmendingCommencement.commenced_on(rules, "regulation-3") == ~D[2019-01-07]
    end
  end

  describe "provisions the clause dates apart" do
    test "\"except for the following provisions which come into force on …—\" (SI 2018/575 reg.1(2))" do
      rules =
        read(
          [
            {"reg.1(1)", "These Regulations may be cited as the Environment Regulations 2018."},
            {"reg.1(2)",
             "They come into force on 1st June 2018, except for the following provisions which come into force on 5th July 2018—"},
            {"reg.1(2)(a)", "regulation 4;"},
            {"reg.1(2)(b)", "regulations 6 and 7;"},
            {"reg.1(2)(c)", "regulation 12."},
            {"reg.4", ""},
            {"reg.5", ""},
            {"reg.6", ""},
            {"reg.7", ""},
            {"reg.12", ""}
          ],
          made: ~D[2018-05-08]
        )

      assert AmendingCommencement.commenced_on(rules, "regulation-5") == ~D[2018-06-01]

      for id <- ~w(regulation-4 regulation-6 regulation-7 regulation-12),
          do: assert(AmendingCommencement.commenced_on(rules, id) == ~D[2018-07-05])
    end

    test "a day counted from laying is unread for the provisions it names, never the general date (SI 2018/1202 reg.1(3))" do
      rules =
        read(
          [
            {"reg.1(1)",
             "These Regulations may be cited as the Merchant Shipping Regulations 2018."},
            {"reg.1(2)",
             "Subject to paragraph (3), these Regulations come into force on exit day."},
            {"reg.1(3)",
             "This Regulation and regulation 2 come into force on the 22nd day after the day on which these Regulations are laid."},
            {"reg.2", ""},
            {"reg.3", ""}
          ],
          made: ~D[2018-11-18]
        )

      assert "reg.1, reg.2 — unread — everywhere, fully — provision_unread" in lines(rules)
      assert AmendingCommencement.commenced_on(rules, "regulation-2") == nil
      assert AmendingCommencement.commenced_on(rules, "regulation-3") == ~D[2020-12-31]
    end
  end

  describe "an Act's list of exceptions to its by-order clause (2014 c.12 s.185)" do
    @s185 [
      {"s.185(1)",
       "This Act comes into force on whatever day or days the Secretary of State appoints by order."},
      {"s.185(2)", "Subsection (1) does not apply to—"},
      {"s.185(2)(a)",
       "sections 150, 175 and 182 to 186, which come into force on the day on which this Act is passed;"},
      {"s.185(2)(b)",
       "sections 151 and 177, which come into force at the end of the period of 2 months beginning with that day;"},
      {"s.185(2)(e)", "section 122."},
      {"s.185(6)",
       "Section 122 comes into force on whatever day the Scottish Ministers appoint by order."},
      {"s.122", ""},
      {"s.150", ""},
      {"s.151", ""},
      {"s.177", ""}
    ]

    test "an item counting from \"that day\": the day the item before it names" do
      rules = read(@s185, type: "ukpga", made: ~D[2014-03-13])

      assert "s.151, s.177 — 2014-05-13 — everywhere, fully — provision_dated" in lines(rules)
    end

    test "\"as they apply in Wales … on whatever day the Welsh Ministers appoint by order\": by order, for Wales" do
      rules =
        read(
          @s185 ++
            [
              {"s.185(3)",
               "The following provisions, as they apply in Wales, come into force on whatever day or days the Welsh Ministers appoint by order—"},
              {"s.185(3)(a)", "sections 94 to 98;"},
              {"s.185(3)(b)", "section 100."},
              {"s.94", ""},
              {"s.98", ""},
              {"s.100", ""}
            ],
          type: "ukpga",
          made: ~D[2014-03-13]
        )

      assert "s.94, s.98, s.100 — appointed (by order) — W, fully — provision_by_order" in lines(
               rules
             )
    end

    test "\"on whatever day the Scottish Ministers appoint by order\": left to an order" do
      rules = read(@s185, type: "ukpga", made: ~D[2014-03-13])

      assert "s.122 — appointed (by order) — everywhere, fully — provision_by_order" in lines(
               rules
             )
    end
  end

  describe "\"The following provisions of this Act, namely …, shall come into force …, and the other provisions … by order\" (1968 c.64 s.20(4))" do
    @s20 [
      {"s.13", ""},
      {"s.14", ""},
      {"s.19", ""},
      {"s.20(1)", "This Act may be cited as the Civil Evidence Act 1968."},
      {"s.20(2)", "Sections 1 and 2 of the Evidence Act 1938 are hereby repealed."},
      {"s.20(4)",
       "The following provisions of this Act, namely sections 13 to 19, this section (except subsection (2)) and the Schedule, shall come into force on the day this Act is passed, and the other provisions of this Act shall come into force on such day as the Lord Chancellor may by order made by statutory instrument appoint; and different days may be so appointed for different purposes of this Act or for the same purposes in relation to different courts or proceedings or otherwise in relation to different circumstances."}
    ]

    test "the provisions named come in on passing, less the one excepted; the rest by order" do
      rules = read(@s20, type: "ukpga", made: ~D[1968-10-25])

      assert AmendingCommencement.commenced_on(rules, "section-14") == ~D[1968-10-25]
      assert AmendingCommencement.commenced_on(rules, "section-20-1") == ~D[1968-10-25]
      assert AmendingCommencement.commenced_on(rules, "section-20-2") == nil
      assert AmendingCommencement.commenced_on(rules, "section-2") == nil

      # the power to appoint different days qualifies nothing
      assert Enum.any?(
               rules,
               &(&1.scope == :rest and &1.when == {:appointed, "by order"} and
                   &1.purposes == nil)
             )
    end
  end
end
