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
    assert {wsi.feed, unmatched.feed} == {"matched", "unmatched"}
    assert ChangesFeed.enrich(rows, []) == rows

    assert "E+W+S" in ChangesFeed.affected_extents(effects)
  end

  test "lookup/4 falls back to the revoker's whole-instrument effect when the sources name it differently" do
    effects = [
      %Effect{
        type: "revoked",
        affecting: "UK_a",
        affected_provisions: "Regulation",
        effect_extent: "E+W+S+N.I."
      },
      %Effect{
        type: "repealed",
        affecting: "UK_b",
        affected_provisions: "Regulations",
        effect_extent: "E+W"
      },
      %Effect{
        type: "revoked",
        affecting: "UK_c",
        affected_provisions: "reg. 2",
        effect_extent: "S"
      }
    ]

    index = ChangesFeed.index(effects)

    assert %Effect{affecting: "UK_a"} = ChangesFeed.lookup(index, "UK_a", "", "revoked")
    assert %Effect{affecting: "UK_b"} = ChangesFeed.lookup(index, "UK_b", "Act", "revoked")
    # a section row never falls back to a whole-instrument effect
    assert ChangesFeed.lookup(index, "UK_a", "reg. 3", "revoked") == nil
    assert ChangesFeed.lookup(index, "UK_c", "", "revoked") == nil
  end

  test "affected_extents/1: whole-instrument extent first; a lone provision extent is not the law's" do
    e = fn provisions, extent ->
      %Effect{
        type: "amended",
        affecting: "UK_x",
        affected_provisions: provisions,
        affected_extent: extent
      }
    end

    assert ChangesFeed.affected_extents([e.("Regulations", "E+W+S"), e.("reg. 2", "E")]) == [
             "E+W+S"
           ]

    assert ChangesFeed.affected_extents([e.("reg. 2", "E+N.I."), e.("reg. 3", nil)]) == []

    assert ChangesFeed.affected_extents([
             e.("reg. 2", "E+W"),
             e.("reg. 3", "E+W"),
             e.("reg. 4", "S")
           ]) ==
             ["E+W", "S"]
  end

  test "law_name/1 builds the register name from an affecting URI" do
    assert ChangesFeed.law_name("http://www.legislation.gov.uk/id/uksi/2005/894") ==
             "UK_uksi_2005_894"

    assert ChangesFeed.law_name("http://www.legislation.gov.uk/id/asp/2018/8") == "UK_asp_2018_8"
    assert ChangesFeed.law_name(nil) == nil
  end

  describe "parse/1 in-force data (#168)" do
    setup do
      xml = File.read!("test/fixtures/changes_feed/anaw_2016_3_inforce.feed")
      {effects, _page} = ChangesFeed.parse(xml)
      %{effects: Map.new(effects, &{&1.affected_provisions, &1})}
    end

    test "a commenced effect: its in-force date and qualification", %{effects: effects} do
      e = effects["s. 84(4)(a)"]
      assert e.applied == true
      assert e.in_force_date == ~D[2024-11-16]
      assert e.prospective == false
      assert e.in_force_qualification == "wholly in force"
    end

    test "a prospective, unapplied effect: no date, prospective, with savings", %{
      effects: effects
    } do
      e = effects["s. 83(2)(a)"]
      assert e.applied == false
      assert e.in_force_date == nil
      assert e.prospective == true
      assert e.savings == ["section-144"]
    end

    test "structured affected refs come only from AffectedProvisions", %{effects: effects} do
      assert effects["s. 84(4)(a)"].affected_refs == ["section-84-4-a"]
      assert effects["s. 83(2)(a)"].affected_refs == ["section-83-2-a"]
    end
  end
end
