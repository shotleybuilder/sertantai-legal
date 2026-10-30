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

    ids = %{"title-I" => "pt.I", "title-I-chapter-1" => "pt.I.ch.1"}
    assert targets(effect("Title I", ["title-I"]), "UK_eur_2006_1907", ids) == ["pt.I"]

    assert targets(effect("Chapter 1", ["title-I-chapter-1"]), "UK_eur_2006_1907", ids) ==
             ["pt.I.ch.1"]
  end

  test "our rows' name first; the reader's own converter for ids they don't know" do
    assert targets(effect("reg. 3", ["regulation-3"]), "UK_uksi_2008_1597", %{}) == ["reg.3"]
  end

  test "a rule is named as the parse names Rules' rows: reg. (review H; SI 1998/1941 r. 2(da))" do
    assert targets(effect("r. 2(da)", ["rule-2-da"]), "UK_uksi_1998_1941", %{}) == ["reg.2(da)"]
  end

  test "bare words: the instrument (by the refs or the effect's own text) is the whole law; otherwise no provision" do
    assert targets(effect("Rules", ["Rules"]), "UK_uksi_1974_2068", %{}) == ["*"]
    assert targets(effect("Rules", ["rule"]), "UK_uksi_1974_2068", %{}) == ["*"]
    assert targets(effect("Sch.", ["schedule"]), "UK_uksi_1997_1713", %{}) == ["?"]
    assert targets(effect("Preamble", ["introduction"]), "UK_uksi_2009_716", %{}) == ["?"]
  end

  test "one path linked in pieces is one target; siblings stay two (D4)" do
    ids = %{"title-V" => "pt.V", "title-V-chapter-1" => "pt.V.ch.1"}

    assert targets(
             effect("Title 5 Ch. 1 heading", ["title-V", "title-V-chapter-1"]),
             "UK_eur_2008_1272",
             ids
           ) ==
             ["pt.V.ch.1"]

    assert targets(
             effect("Sch. 1 para. 2", ["schedule-1", "schedule-1-paragraph-2"]),
             "UK_uksi_1998_2307",
             %{}
           ) ==
             ["sch.1.para.2"]

    assert targets(
             effect("reg. 7(3A)(3B)", ["regulation-7-3A", "regulation-7-3B"]),
             "UK_uksi_1975_335",
             %{}
           ) ==
             ["reg.7(3A)", "reg.7(3B)"]

    # "regulation-1" is not a piece of "regulation-10"
    assert targets(
             effect("regs. 1, 10", ["regulation-1", "regulation-10"]),
             "UK_uksi_1975_335",
             %{}
           ) ==
             ["reg.1", "reg.10"]
  end

  describe "EU: the feed's words name finer than its ref (D3)" do
    @reach "UK_eur_2006_1907"
    @held %{
      "article-56" => "art.Article 56",
      "article-56-6" => "art.Article 56(6)",
      "article-56-6--b" => "art.Article 56(6)(b)",
      "article-25" => "art.Article 25",
      "article-25-7" => "art.Article 25(7)",
      "article-23" => "art.Article 23",
      "article-2" => "art.Article 2",
      "article-14" => "art.Article 14",
      "article-14a" => "art.Article 14a"
    }

    defp finer(text, ref) do
      [{_, target, claims} | _] = Feed.read([effect(text, [ref])], @reach, [], %{}, %{}, @held)
      {target, Enum.find_value(claims, &(&1.attribute == :finer_unheld && &1.value))}
    end

    test "para. and Point read down to the deepest row we hold" do
      assert finer("Art. 56 para. 6 Point (b)", "article-56") == {"art.Article 56(6)(b)", nil}
      assert finer("Art. 25 para. 7", "article-25") == {"art.Article 25(7)", nil}
    end

    test "\"Art. 14 BI\" is Article 14a, as \"BIS\" is (Directive 2006/25 by 2013/64, CV-S09 round 7)" do
      assert finer("Art. 14 BI", "article-14") == {"art.Article 14a", nil}
      assert finer("Art. 14 BIS", "article-14") == {"art.Article 14a", nil}
    end

    test "a finer form we don't hold: on the deepest we do, flagged as a tell-tale" do
      assert finer("Art. 25 para. 8", "article-25") == {"art.Article 25", "art.Article 25(8)"}
      assert finer("Art. 23 Point F)", "article-23") == {"art.Article 23", "art.Article 23(f)"}

      assert finer("Art. 2 Point B)III)", "article-2") ==
               {"art.Article 2", "art.Article 2(b)(iii)"}

      assert finer("Art. 56 para. 6 Point (c)", "article-56") ==
               {"art.Article 56(6)", "art.Article 56(6)(c)"}
    end

    test "a row with no XML id of its own is held too (an item row, CV-S02a #184)" do
      # REACH Art. 57(a): a numbered ListItem with no id, a row since CV-S02a
      rows = ["art.Article 57", "art.Article 57(a)"]

      [{_, target, claims}] =
        Feed.read(
          [effect("Art. 57 Point (a)", ["article-57"])],
          @reach,
          [],
          %{},
          %{},
          %{"article-57" => "art.Article 57"},
          rows
        )

      assert target == "art.Article 57(a)"
      refute Enum.any?(claims, &(&1.attribute == :finer_unheld and &1.value))
    end

    test "EUR-Lex paragraph forms: \".2 L2\" and \"(7)\" (the subparagraph names no row)" do
      assert finer("Art. 56 .6 L2", "article-56") == {"art.Article 56(6)", nil}
      assert finer("Art. 25 (7) L1", "article-25") == {"art.Article 25(7)", nil}
      assert finer("Art. 25 .9", "article-25") == {"art.Article 25", "art.Article 25(9)"}
    end

    test "nothing finer, or what names no row: the article, nothing flagged" do
      assert finer("Art. 56", "article-56") == {"art.Article 56", nil}
      assert finer("Art. 25 Sentence 2", "article-25") == {"art.Article 25", nil}
      assert finer("Art. 25 para. 7 Sentence 2", "article-25") == {"art.Article 25(7)", nil}
    end

    test "only EU law, and only one ref" do
      [{_, t, _}] =
        Feed.read(
          [effect("Art. 25 para. 7", ["article-25"])],
          "UK_uksi_2008_1597",
          [],
          %{},
          %{},
          @held
        )

      assert t == "art.Article 25"
    end
  end
end
