defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeOwnCommencementTest do
  @moduledoc "The law's own commencement read twice joins as one change (CV-S09 round 3, M1)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Merge.OwnCommencement

  @law "UK_nisr_1999_305"

  defp change(key, target, claims),
    do: %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }

  test "the feed's coming into force by the law itself joins the reader's record of the same day" do
    own =
      change("#{@law}:commencement:reg.20@1999-09-20", "reg.20", [
        {:commencement, :operation, :commenced},
        {:commencement, :date, ~D[1999-09-20]}
      ])

    feed =
      change("k-feed", "reg.20", [
        {:feed, :operation, :commenced},
        {:feed, :by, @law},
        {:feed, :date, ~D[1999-09-20]}
      ])

    assert [joined] = OwnCommencement.join([own, feed], @law)
    assert joined.key == own.key
    assert "k-feed" in joined.aliases
    assert Change.value(joined, :feed, :by) == @law
  end

  test "another law's commencement, or another day, stays apart" do
    own =
      change("#{@law}:commencement:reg.20@1999-09-20", "reg.20", [
        {:commencement, :date, ~D[1999-09-20]}
      ])

    order =
      change("k-order", "reg.20", [
        {:feed, :operation, :commenced},
        {:feed, :by, "UK_nisr_1999_999"},
        {:feed, :date, ~D[1999-09-20]}
      ])

    later =
      change("k-later", "reg.20", [
        {:feed, :operation, :commenced},
        {:feed, :by, @law},
        {:feed, :date, ~D[2000-01-01]}
      ])

    assert length(OwnCommencement.join([own, order, later], @law)) == 3
  end

  test "the feed's coming into force by the order the reader read joins it (ukpga 2007/19 s.2(4), SI 2008/401)" do
    law = "UK_ukpga_2007_19"

    own =
      change("#{law}:commencement:s.2(4)@2008-04-06", "s.2(4)", [
        {:commencement, :date, ~D[2008-04-06]},
        {:commencement, :commenced_by, "UK_uksi_2008_401"}
      ])

    feed =
      change("k-feed", "s.2(4)", [
        {:feed, :operation, :commenced},
        {:feed, :by, "UK_uksi_2008_401"},
        {:feed, :date, ~D[2008-04-06]}
      ])

    assert [joined] = OwnCommencement.join([own, feed], law)
    assert "k-feed" in joined.aliases
  end
end
