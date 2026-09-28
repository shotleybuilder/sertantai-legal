defmodule SertantaiLegal.Scraper.LegislationGovUk.ChangesFeedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @fixture "test/fixtures/changes_feed/uksi_1996_972.feed"

  setup_all do
    %{xml: File.read!(@fixture)}
  end

  test "parses each effect with its extents and territorial application", %{xml: xml} do
    {effects, page} = ChangesFeed.parse(xml)

    assert length(effects) == 5
    assert page == %{page: 1, more_pages?: false}

    wsi = Enum.find(effects, &(&1.affecting == "UK_wsi_2005_1806"))

    assert %Effect{
             type: "revoked",
             affected_provisions: "Regulations",
             affected_extent: "E+W+S",
             effect_extent: "E+W",
             territorial_application: "W",
             applied: true
           } = wsi

    uksi = Enum.find(effects, &(&1.affecting == "UK_uksi_2005_894"))
    assert uksi.territorial_application == "E"
  end

  test "missing attributes are nil, not empty strings", %{xml: xml} do
    {effects, _} = ChangesFeed.parse(xml)
    amendment = Enum.find(effects, &(&1.type == "words substituted"))
    assert amendment.affected_provisions == "reg. 1(4)"
    assert Enum.all?(effects, &(&1.affecting =~ ~r/^UK_\w+_\d{4}_\w+$/))
  end

  test "more pages are reported" do
    xml =
      File.read!(@fixture)
      |> String.replace("<leg:morePages>0</leg:morePages>", "<leg:morePages>2</leg:morePages>")

    assert {_, %{more_pages?: true}} = ChangesFeed.parse(xml)
  end

  test "enrich/2 adds extents to the matching changes-table rows", %{xml: xml} do
    {effects, _} = ChangesFeed.parse(xml)

    rows = [
      %{name: "UK_wsi_2005_1806", target: "Regulations", affect: "revoked", applied?: "Yes"},
      %{name: "UK_uksi_2005_894", target: "Regulations ", affect: "Revoked", applied?: "Yes"},
      %{name: "UK_uksi_2099_1", target: "Regulations", affect: "revoked", applied?: "Yes"}
    ]

    [wsi, uksi, unmatched] = ChangesFeed.enrich(rows, effects)

    assert {wsi.affected_extent, wsi.effect_extent, wsi.territorial_application} ==
             {"E+W+S", "E+W", "W"}

    assert uksi.territorial_application == "E"
    refute Map.has_key?(unmatched, :effect_extent)

    assert "E+W+S" in ChangesFeed.affected_extents(effects)
  end

  test "law_name/1 builds the register name from an affecting URI" do
    assert ChangesFeed.law_name("http://www.legislation.gov.uk/id/uksi/2005/894") ==
             "UK_uksi_2005_894"

    assert ChangesFeed.law_name("http://www.legislation.gov.uk/id/asp/2018/8") == "UK_asp_2018_8"
    assert ChangesFeed.law_name(nil) == nil
  end
end
