defmodule SertantaiLegal.Scraper.Commencement.AmendingClauseTest do
  @moduledoc """
  CR-06 (CR-05 folded in): an amending law's own commencement clause, read
  from its CLML (`OwnClause.doc_rows/1` → `OwnClause.rules/2`), dates the
  provision that made a change (`Amending.evaluate/4`) — the forms
  `AmendingLaw.Commencement` read: a provision's own "This section shall
  come into force on the passing of this Act", an SI's single date, "two
  months beginning with the day on which it is passed", by order.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Amending, OwnClause}

  @dir "test/fixtures/amending_law"

  defp rules(doc, made) do
    type = doc.law_name |> String.split("_") |> Enum.at(1)
    OwnClause.rules(doc.law_name, %{type_code: type, made: made, rows: OwnClause.doc_rows(doc)})
  end

  defp dated(rules, id), do: Amending.evaluate(rules, id, "UK_x:s.1", "E+W")

  test "doc_rows/1: body provisions in LAT's grammar, their own words only" do
    doc =
      Doc.new("UK_uksi_2000_1", [
        ~s(<Legislation><Secondary><Body><P1 id="article-2"><Pnumber>2</Pnumber><P1para><P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>In regulation 3 insert—</Text><BlockAmendment><P1 id="x"><Text>This regulation comes into force on 1st May 2001.</Text></P1></BlockAmendment></P2para></P2></P1para></P1></Body><Schedules><Schedule id="schedule-1"/></Schedules></Secondary></Legislation>)
      ])

    assert OwnClause.doc_rows(doc) == [
             %{section_id: "UK_uksi_2000_1:reg.2", text: "", part: nil, chapter: nil},
             %{
               section_id: "UK_uksi_2000_1:reg.2(1)",
               text: "In regulation 3 insert—",
               part: nil,
               chapter: nil
             }
           ]
  end

  test "Utilities Act 2000: by order — no date for its amending provisions" do
    doc =
      Doc.new("UK_ukpga_2000_27", [
        File.read!("#{@dir}/ukpga_2000_27_body.xml"),
        File.read!("#{@dir}/ukpga_2000_27_schedules.xml")
      ])

    rs = rules(doc, ~D[2000-07-28])
    assert %{full_from: nil, partial_from: nil} = dated(rs, "section-60-5")
    assert %{full_from: nil, partial_from: nil} = dated(rs, "schedule-6-paragraph-33-c")
  end

  test "a provision's own words: on the passing of this Act; the rest by order" do
    doc =
      Doc.new("UK_ukpga_2000_27", [
        ~s|<Legislation><Primary><Body><P1 id="section-68"><P1para><P2 id="section-68-1"><P2para><Text>After section 15 of the Electricity Act 1989 there is inserted—</Text></P2para></P2><P2 id="section-68-2"><P2para><Text>This section shall come into force on the passing of this Act.</Text></P2para></P2></P1para></P1><P1 id="section-110"><P1para><Text>This Act (apart from this section and section 68) shall come into force on such day as the Secretary of State may by order appoint.</Text></P1para></P1></Body></Primary></Legislation>|
      ])

    rs = rules(doc, ~D[2000-07-28])
    assert %{full_from: ~D[2000-07-28]} = dated(rs, "section-68-1")
    assert %{full_from: nil} = dated(rs, "section-3")
  end

  test "an SI's single date; an Act two months after passing" do
    si =
      Doc.new("UK_uksi_2000_1937", [
        ~s(<Legislation><Secondary><Body><P1 id="regulation-1"><P1para><Text>These Regulations may be cited as the Gas Regulations 2000 and shall come into force on 10th August 2000.</Text></P1para></P1><P1 id="regulation-5"><P1para><Text>Omit regulation 3.</Text></P1para></P1></Body></Secondary></Legislation>)
      ])

    assert %{full_from: ~D[2000-08-10]} = dated(rules(si, ~D[2000-07-20]), "regulation-5")

    act =
      Doc.new("UK_ukpga_1995_1", [
        ~s(<Legislation><Primary><Body><P1 id="section-9"><P1para><Text>This Act shall come into force at the end of the period of two months beginning with the day on which it is passed.</Text></P1para></P1></Body></Primary></Legislation>)
      ])

    assert %{full_from: ~D[1995-05-01]} = dated(rules(act, ~D[1995-03-01]), "section-2")
  end
end
