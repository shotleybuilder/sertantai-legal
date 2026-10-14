defmodule SertantaiLegal.Scraper.AmendingLaw.CommencingOrderTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{CommencingOrder, Doc}

  @act %{law: "UK_ukpga_2000_27", title: "Utilities Act", year: "2000"}
  defp order,
    do:
      Doc.new("UK_uksi_2001_3266", [File.read!("test/fixtures/amending_law/uksi_2001_3266.xml")])

  defp dates(id, act \\ @act), do: CommencingOrder.dates(order(), act, id)

  test "a listed section commences on the Schedule's day, for all purposes" do
    assert dates("section-60-5") == [%{date: ~D[2001-10-01], qualification: nil, ref: "schedule"}]
    assert dates("section-60") == [%{date: ~D[2001-10-01], qualification: nil, ref: "schedule"}]
  end

  test "subsections listed and ranged; a nested row under its section" do
    assert [%{date: ~D[2001-10-01]}] = dates("section-28-3-b")
    assert dates("section-28-3-a") == []
    assert [%{qualification: nil}] = dates("section-5-4")
    # "save in respect of …": partly in force
    assert [%{qualification: "for specified purposes"}] = dates("section-5-10")
  end

  test "Schedule paragraphs by range; a repeals Schedule 'so far as relating to' is partial" do
    assert [%{date: ~D[2001-10-01], qualification: nil}] = dates("schedule-6-paragraph-33-c")
    assert dates("schedule-6-paragraph-40") == []
    assert [%{qualification: "for specified purposes"}] = dates("schedule-8")
  end

  test "an order commencing another Act gives nothing" do
    assert dates("section-60-5", %{law: "UK_ukpga_1999_1", title: "Other Act", year: "1999"}) ==
             []
  end

  test "an SI's own commencement words: the whole order's date for listed provisions" do
    xml =
      ~s|<Legislation><Secondary><Body><P1 id="article-1"><P1para><Text>This Order may be cited as the Gas Act 1995 (Appointed Day) Order 1996. The provisions of the Gas Act 1995 specified below shall come into force on 1st March 1996—</Text><P3 id="article-1-a"><P3para><Text>section 10;</Text></P3para></P3><P3 id="article-1-b"><P3para><Text>Schedule 3, paragraph 22.</Text></P3para></P3></P1para></P1></Body></Secondary></Legislation>|

    d = Doc.new("UK_uksi_1996_218", [xml])
    act = %{law: "UK_ukpga_1995_45", title: "Gas Act", year: "1995"}

    assert CommencingOrder.dates(d, act, "section-10") == [
             %{date: ~D[1996-03-01], qualification: nil, ref: "article-1"}
           ]

    assert CommencingOrder.dates(d, act, "schedule-3-paragraph-22-2") == [
             %{date: ~D[1996-03-01], qualification: nil, ref: "article-1"}
           ]

    assert CommencingOrder.dates(d, act, "section-11") == []
  end
end
