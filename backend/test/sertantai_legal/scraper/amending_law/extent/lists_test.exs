defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ListsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lists, Units}

  @socpa ~S"""
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

  # a provision's words, as `Extent.read/1` takes them
  defp words(doc, id),
    do: doc |> Doc.element(id) |> Units.own_words() |> Doc.lines() |> Enum.join(" ")

  test "a clause's headed lists: only, same (SOCPA 2005 s.179)" do
    doc = Doc.new("UK_ukpga_2005_15", [@socpa])
    lists = Lists.lists(words(doc, "section-179"), "s.179", doc)

    assert {:only, "S", ["s.129", "s.130(3)"]} in lists
    assert {:same, nil, ["s.174(2)", "sch.17"]} in lists
  end

  test "an exception list extends there too; a purpose-limited item doesn't (HSWA s.84(1))" do
    doc = Doc.new("UK_ukpga_1974_37", [@hswa])
    assert Lists.apart(words(doc, "section-84"), "s.84", doc) == [{:also, "NI", ["s.77"]}]
  end

  test "a Part that does not extend, except some of it (HSWA s.84(2))" do
    doc = Doc.new("UK_ukpga_1974_37", [@hswa])

    assert Lists.part_not(
             [
               {"s.84",
                "Part III, except section 75 and Schedule 7, does not extend to Scotland."}
             ],
             doc
           ) == [{:not, "S", ["s.77"]}]
  end

  test "a heading's kind and place" do
    m = ["The following extend also to Scotland—"]
    assert Lists.kind(m) == :also
    assert Lists.place(m) == "S"
  end
end
