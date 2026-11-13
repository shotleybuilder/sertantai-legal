defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedTitleLocatorTest do
  @moduledoc """
  A word the feed writes after a provision names the part of it the effect
  changes: its title ("reg. 10 Title": SI 2009/995 by SI 2012/630 reg.
  19(2)(a), Welsh text only), its sidenote, its shoulder note, the
  cross-heading above it. The change is within the provision (words
  level), never the whole provision — a container ("Title 14A") and a
  provision inserted "and cross-heading" stay whole.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(text, refs, type \\ "substituted"),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affecting: "UK_uksi_2012_630",
      in_force_date: ~D[2012-04-06]
    }

  # {target, operation, level, heading} per change the reader makes
  defp read(e, law \\ "UK_wsi_2009_995", ids \\ %{}) do
    for {_key, target, claims} <- Feed.read([e], law, [], %{}, %{}, ids) do
      v = fn a -> Enum.find_value(claims, &(&1.attribute == a && &1.value)) end
      {target, v.(:operation), v.(:level), v.(:heading)}
    end
  end

  test "a provision's Title substituted changes its heading, not the provision (SI 2009/995 reg. 10 Title)" do
    assert read(effect("reg. 10 Title", ["regulation-10"])) ==
             [{"reg.10", :substituted, :words, true}]
  end

  test "in either case, on a section, a Schedule and a Part (asp 2002/3 s. 42 title; asp 2005/13 Sch. 1 title)" do
    for {text, refs} <- [
          {"s. 42 title", ["section-42"]},
          {"reg. 22 title", ["regulation-22"]},
          {"Sch. 1 title", ["schedule-1"]},
          {"Pt. 1 title", ["part-1"]},
          {"sch. 1 para. 9 title", ["schedule-1", "schedule-1-paragraph-9"]}
        ] do
      assert [{_, :substituted, :words, true}] = read(effect(text, refs)), text
    end
  end

  test "an EU article's Title replaced (Directive 2010/63 Art. 54 Title)" do
    assert [{_, :substituted, :words, true}] =
             read(effect("Art. 54 Title", ["article-54"], "replacement"), "UK_eudr_2010_63")
  end

  test "a section's sidenote and a Schedule's shoulder note (1986 c.44 s. 33BC sidenote; 2003 c.44 Sch. 15 shoulder note)" do
    assert [{_, :substituted, :words, true}] =
             read(effect("s. 33BC sidenote", ["section-33BC"]), "UK_ukpga_1986_44")

    assert [{_, :substituted, :words, _}] =
             read(effect("Sch. 15 shoulder note", ["schedule-15"]), "UK_ukpga_2003_44")
  end

  test "a cross-heading the feed links to the provision under it (asp 2004/6 s. 1 cross-heading inserted)" do
    assert [{_, :inserted, :words, true}] =
             read(effect("s. 1 cross-heading", ["section-1"], "inserted"), "UK_asp_2004_6")
  end

  test "a cross-heading the feed links itself stays whole (anaw 2016/3 s. 7 cross-heading inserted)" do
    ref = "part-1-crossheading-general-duties-of-public-authorities"

    assert [{_, :inserted, :provision, true}] =
             read(effect("s. 7 cross-heading", [ref], "inserted"), "UK_anaw_2016_3", %{
               ref => "pt.1.h.1"
             })
  end

  test "a provision inserted and cross-heading stays whole (anaw 2017/2 s. 17A and cross-heading)" do
    assert [{_, :inserted, :provision, _}] =
             read(effect("s. 17A and cross-heading", ["section-17A"], "inserted"))
  end

  test "a Title that is a container stays whole (REACH Title 14A inserted; Title 3 omitted)" do
    ids = %{"title-14A" => "pt.XIVA", "title-3" => "pt.III"}

    assert read(effect("Title 14A", ["title-14A"], "inserted"), "UK_eur_2006_1907", ids) ==
             [{"pt.XIVA", :inserted, :provision, nil}]

    assert read(effect("Title 3", ["title-3"], "omitted"), "UK_eur_2006_1013", ids) ==
             [{"pt.III", :repealed, :provision, nil}]
  end

  test "a title with no operation has no level (1991 c.56 Sch. 2 title applied)" do
    assert [{_, nil, nil, true}] =
             read(effect("Sch. 2 title", ["schedule-2"], "applied (with modifications)"))
  end

  test "a whole substitution of the provision is unchanged" do
    assert read(effect("reg. 10", ["regulation-10"])) ==
             [{"reg.10", :substituted, :provision, nil}]
  end
end
