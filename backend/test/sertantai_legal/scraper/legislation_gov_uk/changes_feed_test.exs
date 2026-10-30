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

  test "each effect keeps its id, the affecting provisions and when it was modified (LR-03)", %{
    xml: xml
  } do
    {effects, _} = ChangesFeed.parse(xml)
    wsi = Enum.find(effects, &(&1.affecting == "UK_wsi_2005_1806"))

    assert wsi.effect_id == "effect-fixture"
    assert wsi.affecting_provisions == "reg. 72(1)"
    assert wsi.modified == "2026-03-24T16:07:27Z"
  end

  test "missing attributes are nil, not empty strings", %{xml: xml} do
    {effects, _} = ChangesFeed.parse(xml)
    amendment = Enum.find(effects, &(&1.type == "words substituted"))
    assert amendment.affected_provisions == "reg. 1(4)"
    assert Enum.all?(effects, &(&1.affecting =~ ~r/^UK_\w+_\d{4}_\w+$/))
  end

  test "'same as affected' (spelled S+A+M+E+A+S+A+F+F+E+C+T+E+D) is no extent of its own (LR-26)",
       %{
         xml: xml
       } do
    garbled =
      String.replace(
        xml,
        ~s(AffectingEffectsExtent="E+W"),
        ~s(AffectingEffectsExtent="S+A+M+E+A+S+A+F+F+E+C+T+E+D")
      )

    {effects, _} = ChangesFeed.parse(garbled)
    assert Enum.find(effects, &(&1.affecting == "UK_wsi_2005_1806")).effect_extent == nil
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
      # every qualification, in order (LR-03: a removal in force per territory)
      assert e.in_force_qualifications == ["wholly in force"]
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

  test "a provision range is kept as {start, end} (LR-03: \"Ss. 1-30 repealed\")" do
    xml = """
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><entry><content>
    <ukm:Effect EffectId="effect-fixture" Type="repealed" Applied="true" AffectedProvisions="ss. 1-30" AffectingURI="http://www.legislation.gov.uk/id/ukpga/1990/43">
    <ukm:AffectedProvisions><ukm:SectionRange Start="section-1" End="section-30"><ukm:Section Ref="section-1">ss. 1</ukm:Section>-<ukm:Section Ref="section-30">30</ukm:Section></ukm:SectionRange></ukm:AffectedProvisions>
    </ukm:Effect></content></entry></feed>
    """

    {[effect], _} = ChangesFeed.parse(xml)
    assert effect.affected_ranges == [{"section-1", "section-30"}]
  end

  test "a lowercase \"other\" reads OtherQualification too (SI 1992/3004: CV-S02 NEW-D)" do
    xml = """
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><entry><content>
    <ukm:Effect EffectId="effect-fixture" Type="coming into force" Applied="true" AffectedProvisions="reg. 4" AffectingURI="http://www.legislation.gov.uk/id/uksi/1992/3004">
    <ukm:InForceDates>
    <ukm:InForce Date="1993-01-01" Qualification="other" OtherQualification="for specified purposes and 1.1.1996 in so far as not already in force"/>
    </ukm:InForceDates>
    </ukm:Effect></content></entry></feed>
    """

    {[effect], _} = ChangesFeed.parse(xml)
    q = "for specified purposes and 1.1.1996 in so far as not already in force"
    assert effect.in_force_qualifications == [q]
    assert [%{date: ~D[1993-01-01], qualification: ^q}] = effect.in_force
  end

  test "in-force qualifications: \"Other\" reads OtherQualification; undated or unapplied entries don't count (LR-03)" do
    xml = """
    <feed xmlns="http://www.w3.org/2005/Atom" xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><entry><content>
    <ukm:Effect EffectId="effect-fixture" Type="substituted" Applied="true" AffectedProvisions="s. 402(2)(aa)" AffectingURI="http://www.legislation.gov.uk/id/ukpga/2021/30">
    <ukm:InForceDates>
    <ukm:InForce Applied="false" Prospective="true" Qualification=""/>
    <ukm:InForce Applied="true" Date="2021-03-15" Qualification="for specified purposes"/>
    <ukm:InForce Date="2022-12-26" Qualification="Other" OtherQualification="for E.W. in so far as not already in force"/>
    <ukm:InForce Applied="false" Date="2030-01-01" Qualification="for N.I."/>
    </ukm:InForceDates>
    </ukm:Effect></content></entry></feed>
    """

    {[effect], _} = ChangesFeed.parse(xml)

    assert effect.in_force_qualifications == [
             "for specified purposes",
             "for E.W. in so far as not already in force"
           ]

    # LR-07: every InForce entry, in order ("Other" reads OtherQualification)
    assert effect.in_force == [
             %{date: nil, prospective: true, qualification: nil, applied: false, commencing: nil},
             %{
               date: ~D[2021-03-15],
               prospective: false,
               qualification: "for specified purposes",
               applied: true,
               commencing: nil
             },
             %{
               date: ~D[2022-12-26],
               prospective: false,
               qualification: "for E.W. in so far as not already in force",
               applied: nil,
               commencing: nil
             },
             %{
               date: ~D[2030-01-01],
               prospective: false,
               qualification: "for N.I.",
               applied: false,
               commencing: nil
             }
           ]
  end
end
