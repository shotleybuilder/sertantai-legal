defmodule SertantaiLegal.Scraper.Commencement.OrderOneSentenceFormsTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — a Scottish order's one
  sentence naming its provision: "<date> is the appointed day on which
  section 23 (…) of the Act comes into force" (SSI 2013/252), and "The day
  appointed for the coming into force of X for the purpose of P is D1 and
  for all other purposes is D2" (SSI 2007/50); and an item's place in
  undertakers' words, "so far as relating to undertakers whose areas are
  wholly or mainly in England" (SI 2025/726), read as England's alone, as
  Decision 11 reads an authority's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}

  @act %{
    law: "UK_asp_2003_3",
    title: "Water Environment and Water Services (Scotland) Act",
    year: "2003"
  }

  defp rules(law, title, text),
    do:
      Doc.new(law, [
        ~s(<Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>#{title}</dc:title><Secondary><Body><P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>#{text}</Text></P1para></P1></Body></Secondary></Legislation>)
      ])
      |> Order.rules(@act)

  defp lines(rules),
    do: Enum.map(rules, &(&1 |> Rule.to_text() |> String.split(" — UK_") |> hd()))

  test "“21st September 2013 is the appointed day on which section 23 (…) of the Act comes into force” (SSI 2013/252 art.2)" do
    assert "UK_ssi_2013_252"
           |> rules(
             "The Water Environment and Water Services (Scotland) Act 2003 (Commencement No. 9) Order 2013",
             "21st September 2013 is the appointed day on which section 23 (fixing of charges for water services) of the Water Environment and Water Services (Scotland) Act 2003 comes into force."
           )
           |> lines() == ["s.23 — 2013-09-21 — everywhere, fully — order_date"]
  end

  test "“… for the purpose of enabling provision to be made by order is 6th February 2007 and for all other purposes is 31st March 2007” (SSI 2007/50 art.2)" do
    assert [partly, fully] =
             "UK_ssi_2007_50"
             |> rules(
               "The Water Environment and Water Services (Scotland) Act 2003 (Commencement No. 5) Order 2007",
               "The day appointed for the coming into force of subsections (1) to (4) of section 24 (planning permission: fish farming) of the Water Environment and Water Services (Scotland) Act 2003 for the purpose of enabling provision to be made by order is 6th February 2007 and for all other purposes is 31st March 2007."
             )
             |> Enum.sort_by(& &1.when)

    assert %{scope: ["s.24(1)..s.24(4)"], when: {:date, ~D[2007-02-06]}} = partly
    assert partly.purposes != nil
    assert %{scope: ["s.24(1)..s.24(4)"], when: {:date, ~D[2007-03-31]}} = fully
    assert lines([fully]) |> hd() =~ "fully"
  end

  test "“section 3 (…), so far as relating to undertakers whose areas are wholly or mainly in England” is England's alone (SI 2025/726 reg.2)" do
    act = %{law: "UK_ukpga_2025_5", title: "Water (Special Measures) Act", year: "2025"}

    rules =
      Doc.new("UK_uksi_2025_726", [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Water (Special Measures) Act 2025 (Commencement No. 1) Regulations 2025</dc:title><Secondary><Body><P1 id="regulation-2"><Pnumber>2</Pnumber><P1para><Text>The following provisions of the Water (Special Measures) Act 2025 come into force on 23rd June 2025—</Text><P3 id="regulation-2-a"><Pnumber>a</Pnumber><P3para><Text>section 3 (pollution incident reduction plans), so far as relating to undertakers whose areas are wholly or mainly in England;</Text></P3para></P3><P3 id="regulation-2-b"><Pnumber>b</Pnumber><P3para><Text>section 5 (nature-based solutions), so far as relating to undertakers whose areas are wholly or mainly in England.</Text></P3para></P3></P1para></P1></Body></Secondary></Legislation>
        """
      ])
      |> Order.rules(act)

    assert lines(rules) == [
             "s.3 — 2025-06-23 — E, fully — order_date",
             "s.5 — 2025-06-23 — E, fully — order_date"
           ]
  end

  test "“Section 6(1) of and Schedule 2 to the … Act 1999 shall come into force on 21st March 2000 in so far as they extend to England and Wales” is England and Wales's alone (SI 2000/800 art.2)" do
    act = %{law: "UK_ukpga_1999_24", title: "Pollution Prevention and Control Act", year: "1999"}

    rules =
      Doc.new("UK_uksi_2000_800", [
        ~s"""
        <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>The Pollution Prevention and Control Act 1999 (Commencement No. 1) (England and Wales) Order 2000</dc:title><Secondary><Body><P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>Section 6(1) of and Schedule 2 to the Pollution Prevention and Control Act 1999 shall come into force on 21st March 2000 in so far as they extend to England and Wales.</Text></P1para></P1></Body></Secondary></Legislation>
        """
      ])
      |> Order.rules(act)

    assert lines(rules) == ["s.6(1), sch.2 — 2000-03-21 — E+W, fully — order_date"]
  end
end
