defmodule SertantaiLegal.Scraper.Commencement.AuthorityTest do
  @moduledoc """
  An Act that gives each place its own commencing authority (Decision 10,
  Jason 2026-11-22): the Water Act 2003 s.105(6) table and the Planning Act
  2008 s.241(3)–(4) list. An order made by an authority for one place
  brings in that place's provisions there, though its words name none
  (LAT Change Pipeline, step Commencement reader).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Authority, Order}

  @water_table {"UK_ukpga_2003_37:s.105(6).table.1",
                "Section or Schedule | Appropriate authority; Section 73 | The Secretary of State.; Section 67 | The Assembly after consulting the Secretary of State.; Sections 58, 69, 75, 77, 78, 80, 81 and 86 | The Secretary of State, in relation to England; the Assembly, in relation to Wales.; Section 101 and Schedules 7, 8 and 9 | As respects any amendment or repeal consequential on a provision referred to above in this table, the same appropriate authority as listed in respect of the provision in question; otherwise, the Secretary of State after consulting the Assembly."}

  @planning [
    {"UK_ukpga_2008_29:s.241(3)",
     "Except as provided by subsection (1)(a), the provisions listed in subsection (4) come into force on such day as may be appointed by order made by—"},
    {"UK_ukpga_2008_29:s.241(3)(a)", "the Welsh Ministers, in relation to Wales;"},
    {"UK_ukpga_2008_29:s.241(3)(b)", "the Secretary of State, in relation to England."},
    {"UK_ukpga_2008_29:s.241(4)", "The provisions are—"},
    {"UK_ukpga_2008_29:s.241(4)(a)",
     "sections 183, 185, 187, 188, 191(1) and (3), 192, 193 and 197 to 200;"},
    {"UK_ukpga_2008_29:s.241(4)(c)", "Schedules 8 and 11;"},
    {"UK_ukpga_2008_29:s.241(4)(d)", "the repeals in—"},
    {"UK_ukpga_2008_29:s.241(4)(d)(i)",
     "TCPA 1990 (except those in Schedules 1 and 1A to that Act);"},
    {"UK_ukpga_2008_29:s.241(5)",
     "The other provisions of this Act come into force on such day as the Secretary of State may by order appoint."}
  ]

  describe "read/1" do
    test "a table of authorities: a split for each place, and one place's whole" do
      authorities = Authority.read([@water_table])

      assert Authority.territory(authorities, ["s.77(2)"], :uk) == {:ok, "E"}
      assert Authority.territory(authorities, ["s.77"], :wales) == {:ok, "W"}
      assert Authority.territory(authorities, ["s.67"], :wales) == {:ok, nil}
      assert Authority.territory(authorities, ["s.73"], :uk) == {:ok, nil}
      # the consequential rows name no authority of their own
      assert Authority.territory(authorities, ["s.101(1)"], :uk) == :none
      # a scope only partly covered names none
      assert Authority.territory(authorities, ["s.77", "s.79"], :uk) == :none
      assert Authority.territory(authorities, :all, :uk) == :none
    end

    test "a list of provisions each place's authority appoints; another law's repeals are never its provisions" do
      authorities = Authority.read(@planning)

      assert Authority.territory(authorities, ["s.198"], :uk) == {:ok, "E"}
      assert Authority.territory(authorities, ["sch.8"], :wales) == {:ok, "W"}
      assert Authority.territory(authorities, ["s.191(1)"], :uk) == {:ok, "E"}
      assert Authority.territory(authorities, ["sch.1"], :uk) == :none
      assert Authority.territory(authorities, ["s.184"], :uk) == :none
    end

    test "an Act with none" do
      assert Authority.read([{"UK_x:s.1", "This Act comes into force on 1 April 2004."}]) == []
    end
  end

  describe "an order made by one place's authority" do
    @act %{
      law: "UK_ukpga_2003_37",
      title: "Water Act",
      year: "2003",
      authorities: Authority.read([@water_table])
    }

    defp order(law, title, text) do
      Doc.new(law, [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body>
        <P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Act” means the Water Act 2003.</Text></P1para></P1>
        <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>#{text}</Text></P1para></P1>
        </Body></Secondary></Legislation>
        """
      ])
    end

    test "a UK order naming no place brings in a provision split by place in England (SI 2004/2528)" do
      assert [%{territory: "E"}] =
               "UK_uksi_2004_2528"
               |> order(
                 "The Water Act 2003 (Commencement No. 2) Order 2004",
                 "Section 77 of the Act shall come into force on 1st October 2004."
               )
               |> Order.rules(@act)
    end

    test "a Welsh order brings in a provision the Assembly appoints for everywhere everywhere (WSI 2004/910, s.67)" do
      assert [%{territory: nil}] =
               "UK_wsi_2004_910"
               |> order(
                 "The Water Act 2003 (Commencement) (Wales) Order 2004",
                 "Section 67 of the Act shall come into force on 1 April 2004."
               )
               |> Order.rules(@act)
    end

    test "a range holding a split provision is split: the provision England's, the rest everywhere (SI 2004/641, sections 81 to 83)" do
      rules =
        "UK_uksi_2004_641"
        |> order(
          "The Water Act 2003 (Commencement No. 1 and Transitional Provisions) Order 2004",
          "Sections 81 to 83 of the Act shall come into force on 1st April 2004."
        )
        |> Order.rules(@act)

      assert Enum.sort(Enum.map(rules, &{&1.scope, &1.except, &1.territory})) == [
               {["s.81"], [], "E"},
               {["s.81..s.83"], ["s.81"], nil}
             ]
    end

    test "a Welsh order keeps Wales for any other provision" do
      assert [%{territory: "W"}] =
               "UK_wsi_2004_910"
               |> order(
                 "The Water Act 2003 (Commencement) (Wales) Order 2004",
                 "Section 69 of the Act shall come into force on 1 April 2004."
               )
               |> Order.rules(@act)
    end
  end
end
