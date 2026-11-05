defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.StatedExtentTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.StatedExtent

  # the European Communities Act 1972's own markup: no extent clause, each
  # provision's extent stated by legislation.gov.uk (Decision 2, Maritime
  # Safety: Extent reader, 2026-11-05)
  @body """
  <Body><Part id="part-I"><P1group RestrictExtent="E+W+S+N.I." ConfersPower="true"><Title>General implementation of Treaties</Title>
  <P1 DocumentURI="x" id="section-2"><Pnumber>2</Pnumber></P1></P1group>
  <P1group RestrictExtent="E+W"><Title>A</Title><P1 id="section-9"/></P1group>
  <P1group RestrictExtent="S"><Title>A</Title><P1 id="section-9"/></P1group>
  <P1group><Title>Unstated</Title><P1 id="section-10"/></P1group></Part></Body>
  """

  @schedules """
  <Schedules><Schedule id="schedule-2" RestrictExtent="E+W+S+N.I." Status="Repealed"><Number>SCHEDULE 2</Number></Schedule>
  <Schedule id="schedule-3"><Number>SCHEDULE 3</Number></Schedule></Schedules>
  """

  test "a section's stated extent, from its P1group" do
    assert StatedExtent.of([@body, @schedules], "s.2") == "E+W+S+NI"
  end

  test "territorial versions: the union" do
    assert StatedExtent.of([@body], "s.9") == "E+W+S"
  end

  test "a Schedule's, from its own element" do
    assert StatedExtent.of([@body, @schedules], "sch.2") == "E+W+S+NI"
  end

  test "a provision stating none takes its Act's, stated on the whole Act (Decision 3, 2026-11-05)" do
    root =
      ~s(<Legislation RestrictExtent="E+W+S+N.I."><Primary><Body><P1group><Title>Power</Title><P1 id="section-1"/></P1group></Body></Primary></Legislation>)

    assert StatedExtent.of([root], "s.1") == "E+W+S+NI"
    assert StatedExtent.root([root]) == "E+W+S+NI"
    assert StatedExtent.of([root], "s.2") == nil
    assert StatedExtent.root([@body]) == nil

    # the whole Act's only where no provision states another
    assert StatedExtent.uniform([root]) == "E+W+S+NI"
    mixed = String.replace(root, "<P1group>", ~s(<P1group RestrictExtent="E+W">))
    assert StatedExtent.uniform([mixed]) == nil
  end

  test "none stated, or not held: nil" do
    assert StatedExtent.of([@body, @schedules], "s.10") == nil
    assert StatedExtent.of([@body, @schedules], "sch.3") == nil
    assert StatedExtent.of([@body], "s.99") == nil
    assert StatedExtent.of([], "s.2") == nil
  end
end
