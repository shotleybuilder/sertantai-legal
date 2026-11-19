defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedUnconvertedRefsTest do
  @moduledoc """
  Refs the feed reader named no provision from (Waste, Water and Climate,
  2026-11-18): an EU Annex's pieces and Appendix, a bare Schedule's
  paragraph after "Sch,", a Scheme's own paragraph, a Part's heading id.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedAnnex}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(text, refs, type \\ "words substituted"),
    do: %Effect{
      effect_id: "key-1",
      type: type,
      affected_provisions: text,
      affected_refs: refs,
      affecting: "UK_uksi_2019_696"
    }

  defp targets(e, law, ids \\ %{}),
    do:
      [e]
      |> Feed.read(law, [], %{}, %{}, ids)
      |> Enum.map(&elem(&1, 1))
      |> Enum.uniq()

  describe "an EU Annex, named as a whole" do
    test "an unnumbered Annex's Section, Part and paragraph (Decision 2003/33 \"Annex s. 2.2.1\")" do
      law = "UK_eudn_2003_33"

      assert targets(effect("Annex s. 2.2.1", ["annex", "annex-section-2.2.1"]), law) == ["annex"]
      assert targets(effect("Annex Pt. 5", ["annex", "annex-part-5"]), law) == ["annex"]
      assert targets(effect("Annex para. 1", ["annex", "annex-paragraph-1"]), law) == ["annex"]
    end

    test "a Section the feed leaves unnumbered (Regulation 1191/2014 \"Annex SECTION 13\")" do
      assert targets(effect("Annex SECTION 13", ["annex-SECTION"]), "UK_eur_2014_1191") ==
               ["annex"]
    end

    test "an Annex numbered with a small letter (Directive 2008/98 \"Annex IVa\")" do
      assert targets(effect("Annex IVa", ["annex-IVa"], "inserted"), "UK_eudr_2008_98") ==
               ["annex.IVa"]
    end

    test "an Appendix, with the Section inside it (Decision 2003/33 \"Appendix A s. 1.1\")" do
      law = "UK_eudn_2003_33"

      assert targets(effect("Appendix A s. 1.1", ["appendix-A", "section-1.1"]), law) ==
               ["appendix.A"]

      assert targets(effect("Appendix B", ["appendix-B"]), law) == ["appendix.B"]
    end

    test "the namer: a piece's kind word is the unnumbered Annex; anything else is none" do
      assert FeedAnnex.ref("annex-section-2") == "annex"
      assert FeedAnnex.ref("annex-IVb") == "annex.IVb"
      assert FeedAnnex.ref("annex-XVII-part-2") == "annex.XVII"
      assert FeedAnnex.ref("appendix-A") == "appendix.A"
      assert FeedAnnex.ref("annex-") == nil
      assert FeedAnnex.ref("annex-words") == nil
      assert FeedAnnex.ref("regulation-3") == nil
    end
  end

  test "a bare Schedule paragraph after a comma (SI 1983/1182: Sch, Column (1), para 1)" do
    law = "UK_uksi_1983_1182"

    assert targets(effect("Sch, Column (1), para 1", ["schedule", "paragraph-1"]), law) ==
             ["sch.para.1"]

    assert targets(effect("Sch, Column (2), para 3(a)(b)", ["schedule", "paragraph-3-a-b"]), law) ==
             ["sch.para.3(a)(b)"]
  end

  describe "a Scheme's own paragraph" do
    @ids %{"section-2" => "reg.2", "section-2-1" => "reg.2(1)"}

    test "is the row the parse named it (SI 2000/2911 para. 2(1), row reg.2(1))" do
      assert targets(effect("para. 2(1)", ["paragraph-2-1"]), "UK_uksi_2000_2911", @ids) ==
               ["reg.2(1)"]
    end

    test "never a Schedule's paragraph, nor one no row holds" do
      e = effect("Sch. 3 para. 2(1)", ["schedule-3", "paragraph-2-1"])
      assert targets(e, "UK_uksi_2000_2911", @ids) == ["sch.3"]

      assert targets(effect("para. 9", ["paragraph-9"]), "UK_uksi_2000_2911", @ids) == ["?"]
    end
  end

  test "a Part's heading id is the Part (SI 2001/838 \"Pt. 3 heading\", row pt.III)" do
    ids = %{"part-II" => "pt.II", "part-III" => "pt.III"}

    assert targets(
             effect("Pt. 3 heading", ["part-3-heading"], "words inserted"),
             "UK_uksi_2001_838",
             ids
           ) ==
             ["pt.III"]
  end
end
