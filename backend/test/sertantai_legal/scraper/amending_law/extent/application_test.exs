defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ApplicationTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Application

  defp applies(law, text, extent),
    do: Application.application(ExtentDoc.doc(law, ExtentDoc.p1("regulation-1", text)), extent)

  test "extend to one place, apply in another" do
    assert applies(
             "UK_uksi_2026_195",
             "These Regulations extend to England and Wales and apply in relation to England only.",
             "E+W"
           ) == "E"
  end

  test "a bare application clause" do
    assert applies("UK_wsi_2016_1", "These Regulations apply in relation to Wales.", nil) == "W"
  end

  test "none stated" do
    assert applies("UK_uksi_2023_149", "These Regulations extend to England and Wales.", "E+W") ==
             nil
  end

  test "never the words it inserts into another law" do
    assert Application.application(
             ExtentDoc.doc(
               "UK_uksi_2020_1",
               ~s{<P1 id="regulation-2"><P1para><Text>After regulation 1 insert—</Text><BlockAmendment><P1para><Text>These Regulations apply to Northern Ireland.</Text></P1para></BlockAmendment></P1para></P1>}
             ),
             nil
           ) == nil
  end
end
