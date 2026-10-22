defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedTargetsTest do
  @moduledoc """
  The feed reader places an effect on the provision our rows hold (CV-S02):
  an XML id named as the parse named it (`source_xml_id`, one namer); a
  bare word in the feed's refs is the whole instrument, or no provision.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(text, refs),
    do: %Effect{
      effect_id: "key-1",
      type: "heading substituted",
      affected_provisions: text,
      affected_refs: refs,
      affecting: "UK_uksi_2019_696"
    }

  defp targets(e, law, ids),
    do:
      e
      |> List.wrap()
      |> Feed.read(law, [], %{}, %{}, ids)
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()

  test "a Part and an EU title, as our rows name them (SI 2008/1597 Pt. 4 heading; REACH Title I Ch. 1)" do
    assert targets(effect("Pt. 4 heading", ["part-4"]), "UK_uksi_2008_1597", %{"part-4" => "pt.4"}) ==
             ["pt.4"]

    assert targets(
             effect("Title I Chapter 1", ["title-I", "title-I-chapter-1"]),
             "UK_eur_2006_1907",
             %{
               "title-I" => "pt.I",
               "title-I-chapter-1" => "pt.I.ch.1"
             }
           ) == ["pt.I", "pt.I.ch.1"]
  end

  test "our rows' name first; the reader's own converter for ids they don't know" do
    assert targets(effect("reg. 3", ["regulation-3"]), "UK_uksi_2008_1597", %{}) == ["reg.3"]
  end

  test "bare words: the instrument (by the refs or the effect's own text) is the whole law; otherwise no provision" do
    assert targets(effect("Rules", ["Rules"]), "UK_uksi_1974_2068", %{}) == ["*"]
    assert targets(effect("Rules", ["rule"]), "UK_uksi_1974_2068", %{}) == ["*"]
    assert targets(effect("Sch.", ["schedule"]), "UK_uksi_1997_1713", %{}) == ["?"]
    assert targets(effect("Preamble", ["introduction"]), "UK_uksi_2009_716", %{}) == ["?"]
  end
end
