defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.SweepTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Sweep

  @clause MapSet.new(["s.111"])

  describe "net/3" do
    test "A: an exception in the clause's provision (Courts Act 2003 s.111(2), round 6 D1)" do
      assert Sweep.net(
               "Subsection (1) does not apply to section 59(3), 90, 91, 100, 101, 102, 103, 104, 105, 106 or 109.",
               "s.111",
               @clause
             ) == "A"

      # the same words outside the clause's provision: none
      assert Sweep.net(
               "Subsection (1) does not apply to section 59(3).",
               "s.12",
               @clause
             ) == nil
    end

    test "B: strong signals anywhere" do
      for s <- [
            # ukpga 2007/28 s.244(3), round 6 D2
            "The extent of any amendment, repeal or revocation made by section 60 or by Schedule 13 is the same as that of the provision amended.",
            "This paragraph applies in relation to England only.",
            "Paragraph (1) does not apply in Scotland.",
            "This Part shall extend to England and Wales, Scotland and Northern Ireland.",
            "An amendment in Schedule 2 extends to any part of the United Kingdom to which the amended enactment extends."
          ] do
        assert Sweep.net(s, "s.9", MapSet.new()) == "B", s
      end
    end

    test "never an idiom" do
      for s <- [
            "The report must assess the extent to which those objectives are achieved.",
            "The instruments specified in column 1 of Schedule 3 are revoked to the extent specified in column 3.",
            "The committee may extend the period mentioned in sub-paragraph (1).",
            "The Wine Regulations 2011, as they apply in England, Wales and Scotland, are amended as follows.",
            "A recall notice must be complied with to the extent that it applies in England."
          ] do
        assert Sweep.net(s, "s.111", @clause) == nil, s
      end
    end
  end

  test "uncaught/2: the nets' sentences the catalogue doesn't class, own words only" do
    doc =
      ExtentDoc.doc(
        "UK_ukpga_2003_39",
        ~s|<P1 id="section-111"><P1para><P2 id="section-111-1"><P2para><Text>This Act extends to England and Wales only.</Text></P2para></P2><P2 id="section-111-2"><P2para><Text>Subsection (1) does not apply to section 90.</Text></P2para></P2></P1para></P1>| <>
          ExtentDoc.p1("section-12", "This section applies in relation to Scotland only.") <>
          ~s|<P1 id="section-13"><P1para><Text>After subsection (2) insert—</Text><BlockAmendment><P2><P2para><Text>This section applies in relation to Wales only.</Text></P2para></P2></BlockAmendment></P1para></P1>|
      )

    classes = [{"s.111", "This Act extends to England and Wales only.", "default:E+W"}]

    assert Sweep.uncaught(doc, classes) == [
             {"s.111", "Subsection (1) does not apply to section 90.", "A"},
             {"s.12", "This section applies in relation to Scotland only.", "B"}
           ]
  end

  test "shape/1" do
    assert Sweep.shape("Subsection (1) does not apply to section 59(3), 90, 91 or 109.") ==
             "Subsection N does not apply to section N."
  end
end
