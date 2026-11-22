defmodule SertantaiLegal.Scraper.Commencement.OrderApplicationTest do
  @moduledoc """
  An order's own application clause names where it commences: "This Order
  applies in relation to England only" (LAT Change Pipeline, step
  Commencement reader). The Water Act 2003 (Commencement No. 10) Order 2010
  (SI 2010/975) art.1(2).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.Commencement.Order.Territory

  @act %{law: "UK_ukpga_2003_37", title: "Water Act", year: "2003"}

  defp rules(applies) do
    Doc.new("UK_uksi_2010_975", [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water Act 2003 (Commencement No. 10) Order 2010</dc:title><Secondary><Body>
      <P1 id="article-1"><Pnumber>1</Pnumber><P1para>
      <P2 id="article-1-2"><Pnumber>2</Pnumber><P2para><Text>#{applies}</Text></P2para></P2>
      <P2 id="article-1-3"><Pnumber>3</Pnumber><P2para><Text>In this Order “the Act” means the Water Act 2003.</Text></P2para></P2>
      </P1para></P1>
      <P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The 26th March 2010 is the day appointed for the coming into force of section 58 (fluoridation of water supplies) of the Act in so far as not already in force.</Text></P1para></P1>
      </Body></Secondary></Legislation>
      """
    ])
    |> Order.rules(@act)
  end

  test "“This Order applies in relation to England only.”: its rules are England's" do
    assert [%{scope: ["s.58"], territory: "E", purposes: nil}] =
             rules("This Order applies in relation to England only.")
  end

  test "an application clause with an exception names no one place (SI 2009/359 art.1(2))" do
    assert [%{territory: nil}] =
             rules(
               "This Order applies in relation to England only except article 2(d) which extends to Scotland only."
             )
  end

  test "Territory.of_application/1" do
    assert Territory.of_application("This Order applies to Wales.") == "W"

    assert Territory.of_application("This Order applies in relation to England and Wales.") ==
             "E+W"

    assert Territory.of_application("This Order extends to England and Wales.") == nil
    assert Territory.of_application("This Order comes into force on 1st April 2010.") == nil
  end
end
