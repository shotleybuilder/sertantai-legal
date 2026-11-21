defmodule SertantaiLegal.Scraper.Commencement.DocRowsTest do
  @moduledoc """
  A law's CLML as rows, in its own module (the Commencement reader's speed
  fixes: what the CLML rows' cache keys on reaches no reader);
  `OwnClause.doc_rows/1` delegates here.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{DocRows, OwnClause}

  test "body provisions in LAT's grammar, their own words only, with the Part holding them" do
    doc =
      Doc.new("UK_ukpga_2000_1", [
        ~s(<Legislation><Primary><Body><Part id="part-2"><P1group><P1 id="section-5"><Pnumber>5</Pnumber><P1para><Text>This Part comes into force on 1st May 2001.</Text></P1para></P1></P1group></Part></Body><Schedules><Schedule id="schedule-1"/></Schedules></Primary></Legislation>)
      ])

    assert DocRows.rows(doc) == [
             %{
               section_id: "UK_ukpga_2000_1:s.5",
               text: "This Part comes into force on 1st May 2001.",
               part: "2",
               chapter: nil
             }
           ]

    assert OwnClause.doc_rows(doc) == DocRows.rows(doc)
  end
end
