defmodule SertantaiLegal.Scraper.AmendingLaw.ExtentTest do
  @moduledoc """
  An amending Act's extent clause read (CV-03; primary text): Serious
  Organised Crime and Police Act 2005 s.179, trimmed real wording, and the
  section introducing Schedule 7 (s.111).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}

  @doc_xml ~S"""
  <Legislation><Primary><Body>
  <P1 id="section-110"><P1para><Text>Powers of arrest.</Text></P1para></P1>
  <P1 id="section-111"><P1para><Text>Schedule 7, which supplements section 110 by providing for the repeal of certain enactments (including some which are spent) and by making other amendments, has effect.</Text></P1para></P1>
  <P1 id="section-179"><P1para>
  <P2 id="section-179-2"><P2para><Text>Subject to the following provisions, this Act extends to England and Wales only.</Text></P2para></P2>
  <P2 id="section-179-3"><P2para><Text>The following extend also to Scotland—</Text>
  <P3 id="section-179-3-a"><P3para><Text>sections 1 to 54 and 56 to 58,</Text></P3para></P3>
  <P3 id="section-179-3-b"><P3para><Text>sections 60 to 68, 70, 82 to 96, 98 to 106, 107(1) and (4) and 108,</Text></P3para></P3>
  <P3 id="section-179-3-g"><P3para><Text>Schedules 1, 3, 5 and 15.</Text></P3para></P3></P2para></P2>
  <P2 id="section-179-4"><P2para><Text>The following extend to Scotland only—</Text>
  <P3 id="section-179-4-b"><P3para><Text>sections 129 and 130(3),</Text></P3para></P3></P2para></P2>
  <P2 id="section-179-6"><P2para><Text>The following extend to Northern Ireland only—</Text>
  <P3 id="section-179-6-d"><P3para><Text>Part 2 of Schedule 10.</Text></P3para></P3></P2para></P2>
  <P2 id="section-179-7"><P2para><Text>The following have the same extent as the enactments to which they relate—</Text>
  <P3 id="section-179-7-j"><P3para><Text>(subject to subsection (8)) section 174(2) and Schedule 17.</Text></P3para></P3></P2para></P2>
  <P2 id="section-179-8"><P2para><Text>So far as Schedule 17 contains a repeal or revocation of an enactment which corresponds to the repeal or revocation of that enactment by another provision of this Act, that Schedule and section 174(2) have the same extent as that other provision.</Text></P2para></P2>
  </P1para></P1>
  </Body></Primary></Legislation>
  """

  setup do
    %{extent: Extent.read(Doc.new("UK_ukpga_2005_15", [@doc_xml]))}
  end

  test "the default, and the lists that widen, confine or defer it", %{extent: e} do
    assert e.default == "E+W"
    assert Extent.of(e, "s.110") == "E+W"
    assert Extent.of(e, "s.30") == "E+W+S"
    assert Extent.of(e, "s.107(4)") == "E+W+S"
    assert Extent.of(e, "s.107(2)") == "E+W"
    assert Extent.of(e, "s.129") == "S"
    assert Extent.of(e, "sch.10.pt.2") == "NI"
    assert Extent.of(e, "sch.17.pt.2") == :same
    assert Extent.of(e, "sch.3.para.1") == "E+W+S"
  end

  test "a Schedule not named extends as the section introducing it (s.111 → Schedule 7)", %{
    extent: e
  } do
    assert e.introduced_by["sch.7"] == "s.111"
    assert Extent.of(e, "sch.7.para.27(2)") == "E+W"
  end

  test "a repeals schedule follows the provision it corresponds to (s.179(8): 1988/52 s.4(6), repealed by Sch 7 para 27(2) and Sch 17 Pt 2)",
       %{extent: e} do
    assert e.corresponds
    assert Extent.of_change(e, ["sch.7.para.27(2)", "sch.17.pt.2"]) == "E+W"
    assert Extent.of_change(e, ["sch.17.pt.2"]) == :same
  end

  test "rows: one per statement, read back to the same extent (extent_rules, CV-04)", %{
    extent: e
  } do
    rows = Extent.to_rows(e, "UK_ukpga_2005_15")

    assert %{kind: "default", place: "E+W", source_ref: "s.179"} =
             Enum.find(rows, &(&1.kind == "default"))

    assert Enum.any?(rows, &(&1.kind == "only" and &1.place == "S" and "s.129" in &1.items))
    assert Enum.any?(rows, &(&1.kind == "corresponds"))

    assert %{items: ["sch.7"], source_ref: "s.111"} = Enum.find(rows, &(&1.kind == "introduces"))

    assert Enum.all?(rows, &(&1.source_law == "UK_ukpga_2005_15"))
    assert Extent.from_rows(rows) == e
  end

  test "an Act read with no extent clause is one row, read back as no clause" do
    e =
      Extent.read(
        Doc.new("UK_ukpga_2099_1", [
          ~S(<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>Words.</Text></P1para></P1></Body></Primary></Legislation>)
        ])
      )

    assert [%{kind: "none"}] = Extent.to_rows(e, "UK_ukpga_2099_1")
    assert Extent.from_rows(Extent.to_rows(e, "UK_ukpga_2099_1")) == e
    assert Extent.from_rows([]) == nil
  end

  # one provision's text as a document
  defp clause(law, id, text),
    do:
      Extent.read(
        Doc.new(law, [
          ~s(<Legislation><Body><P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1></Body></Legislation>)
        ])
      )

  describe "the forms an amending law states its extent in (CV-07: OH&S amending laws surveyed)" do
    test "an SI's: These Regulations / This Order extend to a list of places" do
      assert clause(
               "UK_uksi_2014_1639",
               "regulation-1",
               "These Regulations extend to England and Wales and Scotland only."
             ).default == "E+W+S"

      assert clause(
               "UK_uksi_2023_149",
               "regulation-1",
               "These Regulations extend to England and Wales."
             ).default == "E+W"

      assert clause(
               "UK_uksi_2014_469",
               "article-1",
               "This Order extends to England and Wales, Scotland and Northern Ireland."
             ).default == "E+W+S+NI"

      assert clause("UK_uksi_2013_235", "article-1", "This Order extends to Great Britain only.").default ==
               "E+W+S"
    end

    test "extent and application in one sentence: the extent is read here" do
      e =
        clause(
          "UK_uksi_2026_195",
          "regulation-1",
          "These Regulations extend to England and Wales and apply in relation to England only."
        )

      assert e.default == "E+W"
    end

    test "do not / shall not extend; which extend; the whole of" do
      assert clause(
               "UK_uksi_2015_398",
               "regulation-1",
               "These Regulations do not extend to Northern Ireland."
             ).default == "E+W+S"

      assert clause(
               "UK_uksi_2009_716",
               "regulation-1",
               "These Regulations shall not extend to Northern Ireland."
             ).default == "E+W+S"

      assert clause(
               "UK_uksi_1996_1513",
               "regulation-1",
               "These Regulations, which extend to Great Britain, may be cited as the Health and Safety (Consultation with Employees) Regulations 1996."
             ).default == "E+W+S"

      assert clause(
               "UK_uksi_2013_602",
               "article-1",
               "The provisions of this Order extend to the whole of the United Kingdom."
             ).default == "E+W+S+NI"

      assert clause(
               "UK_uksi_2013_603",
               "article-1",
               "This Order extends to the whole of the United Kingdom."
             ).default == "E+W+S+NI"
    end

    test "an Act that does not extend to a place: the rest of the United Kingdom" do
      assert clause(
               "UK_ukpga_2003_22",
               "section-20",
               "This Act does not extend to Northern Ireland."
             ).default == "E+W+S"
    end

    test "… apart from named sections, which extend there too" do
      e =
        clause(
          "UK_ukpga_1991_34",
          "section-84",
          "This Act, apart from sections 82 and 83, does not extend to Northern Ireland."
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.82") == "E+W+S+NI"
      assert Extent.of(e, "s.12") == "E+W+S"
    end

    test "a list of provisions named before its place, with no default, decides for those provisions" do
      e =
        clause(
          "UK_ukpga_2005_14",
          "section-60",
          "The following provisions of this Act extend to England and Wales only— (a) section 13; (b) section 39; and (c) section 52."
        )

      assert Extent.of(e, "s.39") == "E+W"
    end
  end

  describe "an amending law's application (CV-07: where its changes apply; ApplicationClause)" do
    test "extend to one place, apply in another" do
      e =
        clause(
          "UK_uksi_2026_195",
          "regulation-1",
          "These Regulations extend to England and Wales and apply in relation to England only."
        )

      assert e.application == "E"
    end

    test "a bare application clause" do
      assert clause(
               "UK_wsi_2016_1",
               "regulation-1",
               "These Regulations apply in relation to Wales."
             ).application == "W"
    end

    test "none stated" do
      assert clause(
               "UK_uksi_2023_149",
               "regulation-1",
               "These Regulations extend to England and Wales."
             ).application == nil
    end

    test "stored as a row, read back" do
      e =
        clause(
          "UK_uksi_2026_195",
          "regulation-1",
          "These Regulations extend to England and Wales and apply in relation to England only."
        )

      rows = Extent.to_rows(e, "UK_uksi_2026_195")
      assert Enum.any?(rows, &(&1.kind == "applies" and &1.place == "E"))
      assert Extent.from_rows(rows) == e
    end
  end

  describe "an SI with no extent clause extends as far as its enabling powers (CV-07)" do
    # HSWA-like parent: Part 1 to GB; s.84 to the UK
    @parent %Extent{default: "E+W+S", lists: [{:also, "NI", ["s.84"]}]}
    @wra %Extent{default: "E+W+S", lists: [{:only, "E+W", ["pt.3", "s.82"]}]}

    test "the union of its enabling sections' extents, by each parent's extent clause" do
      assert Extent.from_powers(
               [%{"law" => "UK_ukpga_1974_37", "sections" => ["15", "82"], "schedules" => []}],
               %{"UK_ukpga_1974_37" => @parent}
             ) == "E+W+S"

      assert Extent.from_powers(
               [%{"law" => "UK_ukpga_1991_57", "sections" => ["82"], "schedules" => []}],
               %{"UK_ukpga_1991_57" => @wra}
             ) == "E+W"

      assert Extent.from_powers(
               [%{"law" => "UK_ukpga_1974_37", "sections" => ["84"], "schedules" => []}],
               %{"UK_ukpga_1974_37" => @parent}
             ) == "E+W+S+NI"
    end

    test "all or nothing: a parent not read, or no provisions, gives no verdict" do
      assert Extent.from_powers(
               [
                 %{"law" => "UK_ukpga_1974_37", "sections" => ["15"], "schedules" => []},
                 %{"law" => "UK_ukpga_1972_68", "sections" => ["2"], "schedules" => []}
               ],
               %{"UK_ukpga_1974_37" => @parent}
             ) == nil

      assert Extent.from_powers([], %{}) == nil
    end

    test "used where the SI states none, stored as a powers row" do
      e = %Extent{powers: "E+W+S", ref: nil}
      assert Extent.of(e, "reg.3") == "E+W+S"
      rows = Extent.to_rows(e, "UK_uksi_2013_1471")
      assert Enum.any?(rows, &(&1.kind == "powers" and &1.place == "E+W+S"))
      assert Extent.from_rows(rows) == e
      # its own clause wins
      assert Extent.of(%Extent{default: "E+W", powers: "E+W+S"}, "reg.3") == "E+W"
    end
  end

  describe "HSWA 1974 s.84: an exception list, a purpose-limited exception, and a Part that does not extend" do
    @hswa ~S"""
    <Legislation><Primary><Body>
    <Part id="part-I"><P1 id="section-15"><P1para><Text>Health and safety regulations.</Text></P1para></P1></Part>
    <Part id="part-III"><P1 id="section-75"><P1para><Text>Amendments.</Text></P1para></P1><P1 id="section-77"><P1para><Text>Building regulations.</Text></P1para></P1></Part>
    <Part id="part-IV">
    <P1 id="section-84"><P1para>
    <P2 id="section-84-1"><P2para><Text>This Act, except—</Text>
    <P3 id="section-84-1-a"><P3para><Text>Part I and this Part so far as may be necessary to enable regulations under section 15 or 30 to be made and operate for the purpose mentioned in paragraph 2 of Schedule 3; and</Text></P3para></P3>
    <P3 id="section-84-1-b"><P3para><Text>section 77,</Text></P3para></P3>
    <Text>does not extend to Northern Ireland.</Text></P2para></P2>
    <P2 id="section-84-2"><P2para><Text>Part III, except section 75 and Schedule 7, does not extend to Scotland.</Text></P2para></P2>
    </P1para></P1></Part>
    </Body></Primary></Legislation>
    """

    setup do
      %{hswa: Extent.read(Doc.new("UK_ukpga_1974_37", [@hswa]))}
    end

    test "the Act: Great Britain", %{hswa: e} do
      assert e.default == "E+W+S"
    end

    test "Part I: a purpose-limited exception doesn't widen it", %{hswa: e} do
      assert Extent.of(e, "s.15") == "E+W+S"
    end

    test "Part III, except s.75: not Scotland; s.77 named in the exceptions reaches NI too", %{
      hswa: e
    } do
      assert Extent.of(e, "s.75") == "E+W+S"
      assert Extent.of(e, "s.77") == "E+W+NI"
    end
  end

  describe "a devolved instrument stating no extent: its legislature's competence (CV-07)" do
    test "by its type" do
      assert Extent.competence("UK_nisr_2016_427") == "NI"
      assert Extent.competence("UK_nisi_1978_1039") == "NI"
      assert Extent.competence("UK_ssi_2020_1") == "S"
      assert Extent.competence("UK_wsi_2016_1") == "E+W"
      assert Extent.competence("UK_uksi_2016_1105") == nil
    end

    test "told apart from an extent the law states (V1-04: it doesn't confine a devolved SI's insertion)" do
      assert Extent.competence_only?(%Extent{competence: "E+W"})
      refute Extent.competence_only?(%Extent{competence: "E+W", powers: "E+W"})
      refute Extent.competence_only?(%Extent{default: "E+W"})
    end

    test "used last: after its own clause and its enabling powers; stored as a row" do
      assert Extent.of(%Extent{competence: "NI"}, "reg.3") == "NI"
      assert Extent.of(%Extent{powers: "E+W+S", competence: "NI"}, "reg.3") == "E+W+S"
      e = %Extent{competence: "NI"}
      assert Extent.from_rows(Extent.to_rows(e, "UK_nisr_2016_427")) == e
    end
  end

  describe "CV-S05 catalogue forms" do
    defp law(law, provisions) do
      body =
        Enum.map_join(provisions, "\n", fn {id, text} ->
          ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)
        end)

      Extent.read(
        Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])
      )
    end

    test "named provisions' own extent: also (with a default), only, not, named (no default)" do
      e =
        law("UK_ukpga_1999_22", [
          {"section-109",
           "This Act extends to England and Wales. Sections 32 to 34 and 73(2) extend to Scotland. Section 74 extends to Northern Ireland only. Sections 17 and 27 do not extend to Wales."}
        ])

      assert Extent.of(e, "s.33") == "E+W+S"
      assert Extent.of(e, "s.74") == "NI"
      assert Extent.of(e, "s.27") == "E"
      assert Extent.of(e, "s.50") == "E+W"

      assert law("UK_ukpga_2023_36", [
               {"section-45",
                "Section 44 and sections 46 and 47 extend to England and Wales, Scotland and Northern Ireland."}
             ])
             |> Extent.of("s.46") == "E+W+S+NI"
    end

    test "a comma before the last place: \"England and Wales, and Scotland\"" do
      e =
        law("UK_ukpga_2003_33", [
          {"section-41", "Sections 32(12) and 38 extend only to England and Wales, and Scotland."}
        ])

      assert Extent.of(e, "s.38") == "E+W+S"
    end

    test "never another law's, a mention, a qualified or excepted extent" do
      for text <- [
            "Sections 128(4) and 132(3) of that Act shall continue to extend to Scotland.",
            "Part X of, and Schedule 9 to, the 1989 Act shall cease to extend to England and Wales.",
            "Parts 1 to 7 extend to England and Wales only, except that an amendment effected by any of those Parts has the same extent as the provision amended.",
            "Sections 1 and 2 above, and Schedule 1 to this Act (except paragraph 12), shall not extend to Northern Ireland."
          ] do
        assert law("UK_ukpga_2000_1", [{"section-9", text}]).lists == [], text
      end
    end

    test "amendments have the same extent as the enactments they change" do
      e =
        law("UK_ukpga_1990_42", [
          {"section-204",
           "The amendments and repeals in Schedules 20 and 21 have the same extent as the enactments to which they refer."}
        ])

      assert Extent.of(e, "sch.20.para.3") == :same
      assert Extent.of(e, "s.10") == nil

      every =
        law("UK_wsi_2013_755", [
          {"article-1",
           "An amendment, repeal or revocation made by this Order has the same extent as the provision to which it relates."}
        ])

      assert Extent.of(every, "sch.2.para.289") == :same

      # with exceptions after it not read plainly: its provisions' extent is
      # unknown, never the default (CV-S05 round 3 E); in its subject: not read
      assert law("UK_ukpga_2000_1", [
               {"section-9",
                "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that the amendments made by paragraphs 164 to 176, in so far as they relate to inquiries, extend to England only."}
             ]).lists == [{:unread, nil, ["sch.3"]}]

      assert law("UK_ukpga_2000_1", [
               {"section-9",
                "Any amendment made by this Act, other than one falling within subsection (3), has the same extent as the provision to which it relates."}
             ]).lists == []

      # never "bind the Crown to the same extent", "to the same extent as if"
      assert law("UK_asp_2004_6", [
               {"section-55",
                "The amendments and repeals of enactments made by schedule 7 bind the Crown to the same extent as the enactments amended or repealed."}
             ]).lists == []
    end

    test "a Part's own clause: This Part (of this Act) shall (not) extend to …" do
      e =
        law("UK_ukpga_1948_26", [
          {"part-II", ""},
          {"section-70", "Duties."},
          {"section-73", "This Part of this Act shall not extend to Scotland."},
          {"part-III", ""},
          {"section-80", "Other."}
        ])

      assert Extent.of(%{e | default: "E+W+S"}, "s.70") == "E+W"
      assert Extent.of(%{e | default: "E+W+S"}, "s.80") == "E+W+S"
    end

    test "a list heading with \"namely\", \"and no others\"; a citation clause's list" do
      e =
        law("UK_ukpga_1977_38", [
          {"section-32",
           "This Act extends to Great Britain. The following provisions of this Act extend to England and Wales only, namely— section 1(1) and section 5."}
        ])

      assert Extent.of(e, "s.5") == "E+W"

      assert law("UK_ssi_2009_266", [
               {"regulation-1",
                "These Regulations— a may be cited as the Example Regulations 2009; b come into force on 1st July 2009; and c extend to Scotland only."}
             ]).default == "S"
    end

    test "EPA 1990 s.164: only the following extend to NI; amendments where the enactment extends" do
      e =
        law("UK_ukpga_1990_43", [
          {"section-141", "Imports."},
          {"section-164",
           "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— section 3(5) to (8); section 62(2)(e) in so far as it relates to importation; . . ., section 141; section 147. Where any enactment amended or repealed by this Act extends to any part of the United Kingdom, the amendment or repeal extends to that part, subject, however, to any express provision in Schedule 15 or 16."}
        ])

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.141") == "E+W+S+NI"
      assert Extent.of(e, "s.164") == "E+W+S+NI"
      # qualified items aren't widened; every amendment follows its enactment
      assert Extent.of(e, "s.62(2)(e)") == :same
      assert Extent.of(e, "sch.15.para.3") == :same
    end

    test "stored and read back, \"not\" lists included (dropped before CV-S05)" do
      e = %Extent{
        default: "E+W+S",
        lists: [{:not, "S", ["s.70"]}, {:named, "NI", ["s.9"]}, {:same, nil, ["*"]}]
      }

      assert Extent.from_rows(Extent.to_rows(e, "UK_ukpga_1948_26")).lists == e.lists
    end
  end

  describe "CV-S05 agent round 1 (N1–N16)" do
    defp read_xml(law, body),
      do:
        Extent.read(
          Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])
        )

    defp p1(id, text), do: ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)

    test "N9: lists are stored and read back with no default" do
      e = %Extent{lists: [{:only, "S", ["s.107"]}]}
      rows = Extent.to_rows(e, "UK_ukpga_2015_20")
      refute Enum.any?(rows, &(&1.kind == "none"))
      assert Extent.from_rows(rows).lists == e.lists
      assert Extent.to_rows(%Extent{}, "UK_ukpga_2015_20") |> Enum.map(& &1.kind) == ["none"]
    end

    test "N15: \"This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1\"" do
      e =
        read_xml(
          "UK_ukpga_1987_43",
          ~s(<Part id="part-I"><P1 id="section-1"><P1para><Text>Liability.</Text></P1para></P1></Part><Part id="part-II">) <>
            p1(
              "section-49",
              "This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1; (b) any provision amending or repealing an enactment which does not so extend."
            ) <>
            "</Part>"
        )

      assert e.default == "E+W+S+NI"
      assert Extent.of(e, "s.1") == "E+W+S"
      # (b): an amendment goes where its enactment does (round 8 NEW-3)
      assert Extent.of(e, "s.49") == :same
    end

    test "N6: \", which subject to … extends to Scotland only— (a) may be cited\"" do
      e =
        read_xml(
          "UK_ukpga_1995_36",
          p1(
            "section-105",
            "This Act, which subject to subsections (8) to (10) below extends to Scotland only— (a) may be cited as the Children (Scotland) Act 1995; and (b) shall come into force on such day as the Secretary of State may appoint."
          )
        )

      assert e.default == "S"
    end

    test "N1, N2: application from the law's own words, never inserted words" do
      inserting =
        read_xml(
          "UK_uksi_2020_1577",
          ~s(<P1 id="regulation-15"><P1para><Text>After regulation 1 insert—</Text><BlockAmendment><P1 id="regulation-15-1A"><P1para><Text>These Regulations apply to Northern Ireland only.</Text></P1para></P1></BlockAmendment></P1para></P1>)
        )

      assert inserting.application == nil

      inserted =
        read_xml(
          "UK_uksi_2008_2852",
          ~s(<P1 id="regulation-1A"><P1para><Text><Addition ChangeId="c1">These Regulations apply to Northern Ireland only.</Addition></Text></P1para></P1>)
        )

      assert inserted.application == nil

      own =
        read_xml(
          "UK_uksi_2026_195",
          p1(
            "regulation-1",
            "These Regulations extend to England and Wales and apply in relation to England only."
          )
        )

      assert own.application == "E"
    end

    test "N4, N11: a list heading naming several places; \"of these Regulations\"" do
      e =
        read_xml(
          "UK_ukpga_2022_31",
          p1(
            "section-185",
            "This Act extends to England and Wales. The following provisions extend to England and Wales, Scotland and Northern Ireland— (a) section 92; (b) section 125."
          )
        )

      assert Extent.of(e, "s.92") == "E+W+S+NI"

      si =
        read_xml(
          "UK_uksi_2025_361",
          p1(
            "regulation-2",
            "The following provisions of these Regulations extend to England and Wales— (a) regulation 3; (b) Schedule 2."
          )
        )

      assert Extent.of(si, "reg.3") == "E+W"
    end

    test "N5, N8: \"Subject to …, Parts 1 to 5 extend …\"; articles and regulations named" do
      e =
        read_xml(
          "UK_ukpga_2006_48",
          ~s(<Part id="part-1">) <>
            p1("section-1", "One.") <>
            ~s(</Part><Part id="part-2">) <>
            p1("section-20", "Two.") <>
            ~s(</Part><Part id="part-6">) <>
            p1(
              "section-54",
              "Subject to subsections (2) to (6), Parts 1 to 2 extend to England and Wales only."
            ) <> "</Part>"
        )

      assert Extent.of(e, "s.20") == "E+W"

      si =
        read_xml(
          "UK_uksi_2016_1142",
          p1("article-1", "Articles 2 and 6(1) to (3) extend to Scotland only.")
        )

      assert Extent.of(si, "reg.2") == "S"
      assert Extent.of(si, "reg.6(2)") == "S"
    end

    test "N7: \"the preceding provisions of this Act (including the Schedules) do not extend to Northern Ireland\"" do
      e =
        read_xml(
          "UK_ukpga_1998_8",
          p1(
            "section-16",
            "Subject to subsection (2), the preceding provisions of this Act (including the Schedules) do not extend to Northern Ireland."
          )
        )

      assert e.default == "E+W+S"
    end

    test "N10, N13, N14: same application and extent; named Parts or regulations; amendments' own extent" do
      assert read_xml(
               "UK_uksi_2020_660",
               p1(
                 "regulation-1",
                 "An amendment made by these Regulations has the same application and extent as the provision amended."
               )
             ).lists ==
               [{:same, nil, ["*"]}]

      e =
        read_xml(
          "UK_uksi_2015_21",
          p1(
            "regulation-2",
            "The amendments made by regulations 3, 4 and 6 have the same extent as the provisions amended."
          )
        )

      assert e.lists == [{:same, nil, ["reg.3", "reg.4", "reg.6"]}]

      own =
        read_xml(
          "UK_uksi_2015_21",
          p1(
            "regulation-2",
            "The amendments made by regulations 8, 12, 17 and 19 extend to England and Wales and Scotland only."
          )
        )

      assert Extent.of(own, "reg.12") == "E+W+S"
    end

    test "N12: references — Schedule paragraphs and Parts, subsection ranges, Schedule ranges" do
      alias SertantaiLegal.Scraper.AmendingLaw.RefList

      assert RefList.parse("paragraphs 5, 35 and 36 of Schedule 23") ==
               ["sch.23.para.5", "sch.23.para.35", "sch.23.para.36"]

      assert RefList.parse("sections 26(7) to (10)") == [
               "s.26(7)",
               "s.26(8)",
               "s.26(9)",
               "s.26(10)"
             ]

      assert RefList.parse("Parts 4 and 5 of Schedule 13") == ["sch.13.pt.4", "sch.13.pt.5"]

      assert RefList.parse("Schedules 2 to 4, 11 and 12") == [
               "sch.2",
               "sch.3",
               "sch.4",
               "sch.11",
               "sch.12"
             ]

      assert RefList.parse("Schedule 2 (and article 26 so far as relating to it)") == ["sch.2"]
      assert RefList.parse("regulations 3 to 5") == ["reg.3..reg.5"]
      assert RefList.covers?("reg.3..reg.5", "reg.4(1)")
    end

    test "N3: a list inside an enumerated item ends at the parent's next item; qualified items aren't read" do
      e =
        read_xml(
          "UK_ukpga_1977_45",
          p1(
            "section-65",
            "This Act extends to England and Wales. In this Act— (a) Part V extends to Scotland; (b) the following provisions extend to Northern Ireland namely— sections 38 to 40, . . . section 52, subsections (1) and (3) of this section, Schedule 7, in Schedule 14, paragraph 5; (c) section 31 and Schedule 6, so far as they amend any enactment which extends to the Channel Islands, extend to the Channel Islands."
          )
        )

      assert [{:named, "NI", refs}] = Enum.filter(e.lists, &match?({_, "NI", _}, &1))
      # (the section's own subsections are in the list: round 13 S5, found
      # by the CV-S05d census)
      assert refs == ["s.38..s.40", "s.52", "s.65(1)", "s.65(3)", "sch.7", "sch.14.para.5"]
    end

    test "a default with plain exceptions after it; otherwise unread" do
      e =
        read_xml(
          "UK_uksi_2007_605",
          p1("regulation-1", "These Regulations extend to Northern Ireland except regulation 15.")
        )

      assert {e.default, e.lists} == {"NI", [{:not, "NI", ["reg.15"]}]}

      e =
        read_xml(
          "UK_ukpga_2019_3",
          p1(
            "section-26",
            "This Act extends to England and Wales, Scotland and Northern Ireland, except as otherwise provided by subsections (2) to (6)."
          )
        )

      assert e.default == "E+W+S+NI"

      e =
        read_xml(
          "UK_ukpga_2021_12",
          p1(
            "section-20",
            "This Act extends to England and Wales, Scotland and Northern Ireland, except that section 12 (airport slot allocation) extends to England and Wales and Scotland only."
          )
        )

      assert {e.default, Extent.of(e, "s.12")} == {"E+W+S+NI", "E+W+S"}

      e =
        read_xml(
          "UK_uksi_2017_304",
          p1(
            "regulation-1",
            "These Regulations extend to Great Britain, except for regulation 3 which extends only to Northern Ireland."
          )
        )

      assert Extent.of(e, "reg.3") == "NI"

      # another law's provisions in the exception: unread
      e =
        read_xml(
          "UK_uksi_2025_904",
          p1(
            "regulation-1",
            "These Regulations extend to England and Wales, Scotland and Northern Ireland, except paragraph 23 of Schedule 12A to the Data Protection Act 2018 which extends to England and Wales only."
          )
        )

      assert e.default == nil
    end

    test "a complement is no compound: \"…, but otherwise this Act extends there\"" do
      e =
        read_xml(
          "UK_ukpga_1987_12",
          p1(
            "section-32",
            "Sections 25, 26 and 27 of this Act do not extend to Northern Ireland, but otherwise this Act extends there."
          )
        )

      assert e.lists == [{:not, "NI", ["s.25", "s.26", "s.27"]}]
    end

    test "an SI naming some provisions' extent: the rest as far as its powers (SI 2019/758)" do
      e = %{
        read_xml(
          "UK_uksi_2019_758",
          p1(
            "regulation-1",
            "Regulation 12 and Schedule 10 extend to England and Wales and Scotland."
          )
        )
        | powers: "E+W+S+NI"
      }

      assert Extent.of(e, "reg.12") == "E+W+S"
      assert Extent.of(e, "reg.5") == "E+W+S+NI"
    end
  end

  describe "CV-S05 agent round 2" do
    defp read2(law, body),
      do:
        Extent.read(
          Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])
        )

    defp sec(id, text), do: ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)

    test "A: \"to England and Wales and, except as mentioned below, to Northern Ireland\"; a Part's listed provisions" do
      e =
        read2(
          "UK_ukpga_1996_23",
          ~s(<Part id="part-II">) <>
            sec("section-92", "Small claims.") <>
            sec("section-95", "Other.") <>
            "</Part>" <>
            sec(
              "section-108",
              "The provisions of this Act extend to England and Wales and, except as mentioned below, to Northern Ireland. The following provisions of Part II do not extend to Northern Ireland— section 92 (exclusion of Part I in relation to small claims arbitration in the county court)."
            )
        )

      assert e.default == "E+W+NI"
      assert Extent.of(e, "s.92") == "E+W"
      assert Extent.of(e, "s.95") == "E+W+NI"
    end

    test "B, G: \"or\" and \"or to\" join places; \"throughout\"; \"Nothing in this Act extends to\"" do
      assert read2(
               "L",
               sec("section-7", "This Act does not extend to Scotland or Northern Ireland.")
             ).default ==
               "E+W"

      assert read2(
               "L",
               sec("section-7", "This Act shall not extend to Scotland or to Northern Ireland.")
             ).default ==
               "E+W"

      assert read2(
               "L",
               sec(
                 "section-137",
                 "Subject to subsection (2), this Act extends throughout the United Kingdom."
               )
             ).default ==
               "E+W+S+NI"

      assert read2("L", sec("section-9", "Nothing in this Act extends to Northern Ireland.")).default ==
               "E+W+S"
    end

    test "C: lists apply in a fixed order, whatever order they are stored in" do
      e = %Extent{
        lists: [{:also, "S+NI", ["s.5"]}, {:only, "E+W", ["s.5", "s.6"]}]
      }

      assert Extent.of(e, "s.5") == "E+W+S+NI"
      assert Extent.of(e, "s.6") == "E+W"
    end

    test "D: \"except this section and the following provisions, namely—\"" do
      e =
        read2(
          "UK_ukpga_1986_44",
          sec(
            "section-68",
            "This Act, except this section and the following provisions, namely— sections 49 and 50; section 58, does not extend to Northern Ireland."
          )
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.68") == "E+W+S+NI"
      assert Extent.of(e, "s.49") == "E+W+S+NI"
      assert Extent.of(e, "s.10") == "E+W+S"
    end

    test "E: a Part that does not extend, outside the clause" do
      e =
        read2(
          "UK_ukpga_2001_10",
          ~s(<Part id="part-2">) <>
            sec("section-20", "Duties.") <>
            "</Part>" <>
            ~s(<Part id="part-4">) <>
            sec("section-42", "This Act extends to England and Wales and Northern Ireland.") <>
            sec("section-43", "Parts 2 and 3 do not extend to Northern Ireland.") <>
            "</Part>"
        )

      assert Extent.of(e, "s.20") == "E+W"
      assert Extent.of(e, "s.42") == "E+W+NI"
    end

    test "H: words the law inserts elsewhere are never its own clause" do
      e =
        read2(
          "UK_uksi_2026_867",
          ~s(<P1 id="regulation-2"><P1para><Text>After regulation 1 insert—</Text><BlockAmendment><Text>These Regulations extend to Northern Ireland.</Text></BlockAmendment></P1para></P1>)
        )

      assert e.default == nil
    end

    test "J: a heading list in a provision other than the clause" do
      e =
        read2(
          "UK_uksi_2019_696",
          sec("regulation-2", "These Regulations extend to England and Wales.") <>
            sec(
              "regulation-3",
              "The following provisions extend to the United Kingdom— regulation 5; regulation 6."
            )
        )

      assert Extent.of(e, "reg.5") == "E+W+S+NI"
      assert Extent.of(e, "reg.7") == "E+W"
    end

    test "qualified list items stay unread: \"with the exception of\", \"so much of Part 2 as\", a Chapter's Part" do
      e =
        read2(
          "UK_ukpga_2004_20",
          ~s(<Part id="part-1">) <>
            sec("section-1", "One.") <>
            "</Part>" <>
            ~s(<Part id="part-2">) <>
            sec("section-80", "Two.") <>
            "</Part>" <>
            sec(
              "section-188",
              "This Act extends to England and Wales, Scotland and Northern Ireland. The following provisions of this Act do not extend to Northern Ireland— (a) Chapter 3 of Part 1 (with the exception of section 59); (b) so much of Part 2 as amends the 1989 Act; (c) sections 82, 90 and 91."
            )
        )

      assert Extent.of(e, "s.1") == "E+W+S+NI"
      assert Extent.of(e, "s.80") == "E+W+S+NI"
      assert Extent.of(e, "s.82") == "E+W+S"
    end

    test "\"does not extend to Northern Ireland except so far as it affects other enactments\": the amendments follow them" do
      e =
        read2(
          "UK_ukpga_1988_54",
          sec(
            "section-30",
            "This Act does not extend to Northern Ireland except so far as it affects other enactments extending to Northern Ireland."
          ) <> sec("section-2", "Amends.")
        )

      assert e.default == "E+W+S"
      assert Extent.of(e, "s.2") == :same
    end

    test "\"Sections 240 and 242 … have the same extent as the provisions amended\"" do
      e =
        read2(
          "UK_ukpga_1996_18",
          sec("section-243", "This Act extends to England and Wales and Scotland.") <>
            sec(
              "section-244",
              "Sections 240 and 242 and Schedule 1 have the same extent as the provisions amended."
            )
        )

      assert Extent.of(e, "s.240") == :same
      assert Extent.of(e, "s.10") == "E+W+S"
    end
  end

  describe "CV-S05 agent round 3" do
    defp read3(law, body),
      do:
        Extent.read(
          Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])
        )

    defp sec3(id, text), do: ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)

    test "A: a Westminster Act that \"extends to Northern Ireland\" extends to the UK" do
      assert read3("UK_ukpga_1975_26", sec3("section-9", "This Act extends to Northern Ireland.")).default ==
               "E+W+S+NI"

      assert read3(
               "UK_ukpga_1975_26",
               sec3("section-9", "This Act extends to Northern Ireland only.")
             ).default ==
               "NI"

      assert read3(
               "UK_nisr_2000_1",
               sec3("regulation-1", "These Regulations extend to Northern Ireland.")
             ).default ==
               "NI"
    end

    test "B: \"to the extent that they apply in Northern Ireland\" is no application of the law's own" do
      e =
        read3(
          "UK_nisr_2018_17",
          sec3(
            "regulation-20",
            "The Medicines Regulations 1978 are also revoked to the extent that they apply in Northern Ireland."
          )
        )

      assert e.application == nil
    end

    test "C, E: a list naming its own extent beats a same list; an exception read, or the extent unknown" do
      e =
        read3(
          "UK_uksi_2013_602",
          ~s(<P1 id="article-1"><P1para>) <>
            ~s{<P2 id="article-1-3"><P2para><Text>Subject to paragraphs (4) to (8), the provisions of this Order extend to the whole of the United Kingdom.</Text></P2para></P2>} <>
            ~s{<P2 id="article-1-6"><P2para><Text>Subject to paragraph (7), the modifications specified in Schedule 2 have the same extent as the provisions being modified.</Text></P2para></P2>} <>
            ~s{<P2 id="article-1-7"><P2para><Text>The modifications specified in paragraphs 65, 66 and 76 of Schedule 2 extend to Scotland only.</Text></P2para></P2>} <>
            ~s{<P2 id="article-1-8"><P2para><Text>The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that the amendments made by paragraphs 11 to 13 of that Schedule extend to Scotland only.</Text></P2para></P2>} <>
            ~s{<P2 id="article-1-9"><P2para><Text>The amendments made by Schedule 4 have the same extent as the provisions which they amend, except that— (a) the amendments made by paragraph 178 of that Schedule, in so far as they relate to inquiries, extend to Scotland.</Text></P2para></P2>} <>
            "</P1para></P1>"
        )

      assert Extent.of(e, "sch.2.para.76") == "S"
      assert Extent.of(e, "sch.2.para.10") == :same
      assert Extent.of(e, "sch.3.para.12") == "S"
      assert Extent.of(e, "sch.3.para.2") == :same
      assert Extent.of(e, "sch.4.para.33") == nil
      assert Extent.of(e, "art.2") == "E+W+S+NI"

      rows = Extent.to_rows(e, "UK_uksi_2013_602")
      assert Extent.from_rows(rows).lists == e.lists
    end

    test "a bracketed description never names a Part" do
      e =
        read3(
          "UK_ukpga_2012_7",
          ~s(<Part id="part-7">) <>
            sec3("section-209", "Seven.") <>
            "</Part>" <>
            ~s(<Part id="part-12">) <>
            sec3("section-306", "This Act extends to England and Wales.") <>
            sec3(
              "section-308",
              "The following provisions extend to England and Wales, Scotland and Northern Ireland— section 230(1) to (4) and paragraphs 53 and 59 of Schedule 15 (Part 7: consequential provision etc.)."
            ) <>
            "</Part>"
        )

      assert Extent.of(e, "s.209") == "E+W"
      assert Extent.of(e, "s.230(1)") == "E+W+S+NI"
    end
  end

  describe "CV-S05 agent round 4" do
    defp read4(law, body),
      do:
        Extent.read(
          Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])
        )

    defp sec4(id, text), do: ~s{<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>}

    test "N-A: \"Any amendment … made by the provisions in Parts 2 and 3 has the same extent as the provision amended\"" do
      e =
        read4(
          "UK_uksi_2023_1071",
          sec4(
            "regulation-1",
            "Any amendment or revocation made by the provisions in Parts 2 and 3 has the same extent as the provision amended or revoked."
          ) <>
            ~s{<Part id="part-2">} <>
            sec4("regulation-107", "Schedule 1 has effect.") <>
            "</Part>" <>
            ~s{<Part id="part-4">} <> sec4("regulation-120", "Other.") <> "</Part>"
        )

      assert Extent.of(e, "reg.107") == :same
      assert Extent.of(e, "reg.120") == nil
    end

    test "N-B: other same-extent wordings" do
      for text <- [
            "Section 22 has the same extent within the United Kingdom as the provision to which it relates.",
            "Except as provided by subsections (2) and (3), a repeal, revocation or other amendment made by this Act has the same extent as the provision repealed, revoked or amended.",
            "Except as otherwise provided by this Act, an amendment made by this Act extends to the part or parts of the United Kingdom to which the enactment amended extends."
          ] do
        e = read4("UK_ukpga_2015_20", sec4("section-114", text))
        assert Extent.of(e, "s.22") == :same, text
      end
    end

    test "N-C: lettered statements under a lead-in" do
      e =
        read4(
          "UK_ukpga_2004_33",
          sec4(
            "section-262",
            "This Act extends to England and Wales, Scotland and Northern Ireland. In Part 5— (a) sections 220 to 224 extend to England and Wales only; (b) sections 225 to 227 extend to Scotland only; (c) sections 228 to 232 extend to Northern Ireland only."
          )
        )

      assert Extent.of(e, "s.221") == "E+W"
      assert Extent.of(e, "s.226") == "S"
      assert Extent.of(e, "s.230") == "NI"
      assert Extent.of(e, "s.10") == "E+W+S+NI"
    end

    test "N-D: a compound's second clause; \"that Schedule\" named" do
      e =
        read4(
          "UK_ukpga_2009_25",
          sec4(
            "section-181",
            "This Act extends to England and Wales. Paragraphs 34 and 35 of Schedule 22 extend to England and Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland only."
          )
        )

      assert Extent.of(e, "sch.22.para.34") == "E+W+S"
      assert Extent.of(e, "sch.22.para.36") == "S"
    end

    test "N-E: an exception not parsed gives no list" do
      e =
        read4(
          "UK_ukpga_1961_34",
          sec4(
            "section-185",
            "This Act, except subsections (1) and (2) of section seventy-seven, does not extend to Northern Ireland."
          )
        )

      assert e.default == "E+W+S"
      assert e.lists == []
    end
  end

  test "an SI's powers: a parent's \"every amendment has the same extent\" is no enabling section's (CV-S05 round 5)" do
    parent = %Extent{default: "E+W+S+NI", lists: [{:same, nil, ["*"]}]}

    assert Extent.from_powers(
             [%{"law" => "UK_ukpga_2023_28", "sections" => ["14"], "schedules" => []}],
             %{"UK_ukpga_2023_28" => parent}
           ) == "E+W+S+NI"
  end
end
