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
            "Section 1(2) and Schedule 1 extend to Northern Ireland so far as they amend the House of Commons Disqualification Act 1975.",
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

      # with exceptions after it, or in its subject: not read
      for text <- [
            "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that the amendments made by paragraphs 164 to 176 extend to England only.",
            "Any amendment made by this Act, other than one falling within subsection (3), has the same extent as the provision to which it relates."
          ] do
        assert law("UK_ukpga_2000_1", [{"section-9", text}]).lists == [], text
      end

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
end
