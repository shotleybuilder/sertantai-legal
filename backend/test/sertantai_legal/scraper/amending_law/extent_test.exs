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
end
