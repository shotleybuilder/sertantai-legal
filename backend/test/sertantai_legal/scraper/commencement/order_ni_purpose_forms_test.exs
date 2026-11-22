defmodule SertantaiLegal.Scraper.Commencement.OrderNiPurposeFormsTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — two purpose forms of the
  Northern Ireland orders fetched for the laws whose orders were never
  searched:

  - a Schedule table's bracket opening "both paragraphs" or "both Articles"
    before its purpose: "Article 3(3)(a) and 3(6) (both paragraphs for the
    purposes of Article 40(5))" (NISR 1999/325 Sch.1, 105 rows of the Waste
    and Contaminated Land (NI) Order 1997 had been dated fully);
  - "so much of Article 280 … as is necessary to enable regulations under
    Article 7B(5) of the Water (Northern Ireland) Order 1999 to be made shall
    come into operation on the date of this Order" (NISR 2007/282
    art.2(1)): a purpose, on the order's made date, the other Order's
    Article only the purpose's.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  defp doc(law, title, made, body, schedules \\ "") do
    Doc.new(law, [
      ~s"""
      <Legislation xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><ukm:SecondaryMetadata><ukm:Made Date="#{made}"/></ukm:SecondaryMetadata><dc:title>#{title}</dc:title><Secondary><Body>#{body}</Body>#{schedules}</Secondary></Legislation>
      """
    ])
  end

  test "\"on the date of this Order\" is its made date" do
    assert Clause.tail_date("on the date of this Order.", ~D[2007-05-04]) ==
             {:clause_made_relative, ~D[2007-05-04]}

    assert Clause.tail_date("on the date of these Regulations.", ~D[2007-05-04]) ==
             {:clause_made_relative, ~D[2007-05-04]}
  end

  test "a bracket opening \"both paragraphs\" before its purpose qualifies both items" do
    act = %{
      law: "UK_nisi_1997_2778",
      title: "Waste and Contaminated Land (Northern Ireland) Order",
      year: "1997"
    }

    rules =
      doc(
        "UK_nisr_1999_325",
        "The Waste and Contaminated Land (1997 Order) (Commencement No. 3) Order (Northern Ireland) 1999",
        "1999-07-09",
        ~s|<P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order “the Order” means the Waste and Contaminated Land (Northern Ireland) Order 1997.</Text></P1para></P1><P1 id="article-2"><Pnumber>2</Pnumber><P1para><Text>The day appointed for the coming into operation of the provisions of the Order specified in Schedule 1 shall be 19th August 1999.</Text></P1para></P1>|,
        ~s|<Schedules><Schedule id="schedule-1"><Number>SCHEDULE 1</Number><TitleBlock><Title>Provisions of the Order for which 19th August 1999 is appointed as the day of coming into operation</Title></TitleBlock><ScheduleBody><Tabular><table xmlns="http://www.w3.org/1999/xhtml"><thead><tr><th>Provisions of the Order</th><th>Subject Matter</th></tr></thead><tbody><tr><td>Article 3(3)(a) and 3(6) (both paragraphs for the purposes of Article 40(5))</td><td>Meaning “another relevant person”</td></tr><tr><td>Article 39</td><td>Registration of carriers</td></tr></tbody></table></Tabular></ScheduleBody></Schedule></Schedules>|
      )
      |> Order.rules(act)

    by_scope = Map.new(rules, &{&1.scope, &1})

    assert by_scope[["reg.3(3)(a)", "reg.3(6)"]].purposes not in [nil, :fully]
    assert by_scope[["reg.39"]].purposes in [nil, :fully]
    assert Enum.all?(rules, &(&1.when == {:date, ~D[1999-08-19]}))
  end

  test "\"so much of Article 280 … as is necessary to enable regulations under another Order's Article to be made\" is Article 280's, for making them, on the made date" do
    act = %{
      law: "UK_nisi_2006_3336",
      title: "Water and Sewerage Services (Northern Ireland) Order",
      year: "2006"
    }

    [rule] =
      doc(
        "UK_nisr_2007_282",
        "The Water and Sewerage Services (2006 Order) (Commencement No. 2) Order (Northern Ireland) 2007",
        "2007-05-04",
        ~s|<P1 id="article-1"><Pnumber>1</Pnumber><P1para><Text>In this Order—</Text><UnorderedList Decoration="none" Class="Definition"><ListItem><Para><Text>“the 2006 Order” means the Water and Sewerage Services (Northern Ireland) Order 2006.</Text></Para></ListItem></UnorderedList></P1para></P1><P1 id="article-2"><Pnumber>2</Pnumber><P1para><P2 id="article-2-1"><Pnumber>1</Pnumber><P2para><Text>To the extent that it is not already in operation, so much of Article 280 of the 2006 Order as is necessary to enable regulations under Article 7B(5) of the Water (Northern Ireland) Order 1999 to be made shall come into operation on the date of this Order.</Text></P2para></P2></P1para></P1>|
      )
      |> Order.rules(act)

    assert rule.scope == ["reg.280"]
    assert rule.when == {:date, ~D[2007-05-04]}
    assert rule.purposes == :for_making_secondary_legislation
  end
end
