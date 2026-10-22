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
end
