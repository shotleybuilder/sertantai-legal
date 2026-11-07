defmodule SertantaiLegal.Scraper.Checks.StoreScanTest do
  @moduledoc """
  The store scan (#192): every stored feed effect, once, through a named
  form; and its first form, a Part, Chapter or Title beside a provision
  that no provision lies under (Maritime Safety: Switch-over's scan,
  `backend/data/reports/store-scan/bracketed_container.py` with the true
  Ref, Decision 2).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Checks.StoreScan
  alias SertantaiLegal.Scraper.Checks.StoreScan.Forms.BracketedContainer
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(refs, text, type \\ "applied"),
    do: %Effect{
      effect_id: "k",
      affecting: "UK_x",
      type: type,
      affected_refs: refs,
      affected_provisions: text
    }

  describe "BracketedContainer" do
    test "a Part in brackets beside sections" do
      assert BracketedContainer.match(
               effect(~w(section-100A section-100K part-5A), "s. 100A-100K (Pt. 5A)")
             ) ==
               "bracketed"
    end

    test "a Part named without brackets beside a section" do
      assert BracketedContainer.match(effect(~w(section-13 part-4), "s. 13 Pt. 4")) ==
               "unbracketed"
    end

    test "a Part a provision lies under is no container beside it" do
      assert BracketedContainer.match(effect(~w(part-2 part-2-chapter-1-section-3), "Pt. 2 s. 3")) ==
               nil
    end

    test "only provisions, or only containers: no match" do
      assert BracketedContainer.match(effect(~w(section-1 section-2), "s. 1 s. 2")) == nil
      assert BracketedContainer.match(effect(~w(part-1 chapter-2), "Pt. 1 Ch. 2")) == nil
      assert BracketedContainer.match(effect([], nil)) == nil
    end
  end

  describe "the scan" do
    # laws in order, each with its effects as `{id, nil | {type, class, text}}`, as the workers give them
    test "an effect is counted once, at its first law in path order, its class from there" do
      per_law = [
        {"UK_a", [{"e1", {"added", "bracketed", "s. 1 (Pt. 1)"}}, {"e2", nil}]},
        {"UK_b", [{"e1", nil}, {"e3", {"repealed", "unbracketed", "s. 2 Pt. 2"}}]}
      ]

      result = StoreScan.reduce(per_law)
      assert result.effects == 3

      assert result.matches == [
               {"UK_a", "e1", "added", "bracketed", "s. 1 (Pt. 1)"},
               {"UK_b", "e3", "repealed", "unbracketed", "s. 2 Pt. 2"}
             ]

      assert result.classes == %{"bracketed" => {1, 1}, "unbracketed" => {1, 1}}
    end

    test "the listing: every match, sorted, tab-separated" do
      matches = [
        {"UK_b", "e3", "repealed", "unbracketed", "x"},
        {"UK_a", "e1", "added", "bracketed", "y"}
      ]

      assert StoreScan.listing(matches) ==
               "UK_a\te1\tadded\tbracketed\ty\nUK_b\te3\trepealed\tunbracketed\tx\n"
    end
  end
end
