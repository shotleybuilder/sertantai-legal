defmodule SertantaiLegal.Scraper.Commencement.FeedErrorsTest do
  @moduledoc """
  The register of proven feed errors (Decision 12, Jason 2026-11-22): a row
  whose feed record the law's text proves wrong is counted apart, with its
  entry, and an entry that no longer holds is stale and fails the gate.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.FeedErrors

  # Water Act 2003 s.100(2)(b): SI 2007/1021 art.2(c) brings s.100(2) in
  # "for all remaining purposes" on 1 April 2007; the feed has no completion
  @entry %{
    "feed" => ["2005-10-01", nil],
    "ours" => [nil, "2007-04-01"],
    "wrong" => "no_record",
    "feed_by" => ["UK_uksi_2005_2714"],
    "proof" => %{
      "law" => "UK_uksi_2007_1021",
      "provision" => "art.2(c)",
      "words" =>
        "in section 100 (devolution: Wales), subsections (2), (3), (6) and (7) for all remaining purposes"
    },
    "decided" => %{
      "by" => "Jason",
      "on" => "2026-11-22",
      "session" => "2026-11-20-waste-water-and-climate-commencement-reader",
      "decision" => "12"
    }
  }

  @register %{"UK_ukpga_2003_37 s.100(2)(b)" => @entry}

  defp row(overrides \\ %{}),
    do:
      Map.merge(
        %{
          law: "UK_ukpga_2003_37",
          id: "s.100(2)(b)",
          partial_from: nil,
          full_from: ~D[2007-04-01],
          feed: {~D[2005-10-01], nil},
          yardstick: :feed_partial_only
        },
        overrides
      )

  test "a row the register names, its record and our reading as entered, is a proven feed error" do
    assert {[r], []} = FeedErrors.mark([row()], @register, ["UK_ukpga_2003_37"])
    assert r.yardstick == :feed_error
    assert r.feed_error["proof"]["law"] == "UK_uksi_2007_1021"
  end

  test "other rows are left as they are" do
    other = row(%{id: "s.100(3)"})
    assert {[^other, _], []} = FeedErrors.mark([other, row()], @register, ["UK_ukpga_2003_37"])
  end

  test "an entry is stale when our reading changed, the feed's record changed, or the row is gone" do
    assert {[r], [{"UK_ukpga_2003_37 s.100(2)(b)", :ours_changed}]} =
             FeedErrors.mark([row(%{full_from: ~D[2008-01-01]})], @register, ["UK_ukpga_2003_37"])

    assert r.yardstick == :feed_partial_only

    assert {_, [{_, :feed_changed}]} =
             FeedErrors.mark([row(%{feed: {~D[2005-10-01], ~D[2007-04-01]}})], @register, [
               "UK_ukpga_2003_37"
             ])

    assert {[], [{_, :row_gone}]} = FeedErrors.mark([], @register, ["UK_ukpga_2003_37"])
  end

  test "an entry for a law outside the run is neither applied nor stale" do
    assert {[], []} = FeedErrors.mark([], @register, ["UK_other"])
  end

  test "entry/2 fills a proposal's feed record and our reading from the row" do
    proposal = Map.drop(@entry, ["feed", "ours"])
    assert FeedErrors.entry(proposal, row()) == @entry
  end

  test "an entry lacking its proof or its decision is refused" do
    assert {:error, _} = FeedErrors.validate(Map.delete(@entry, "proof"))
    assert {:error, _} = FeedErrors.validate(put_in(@entry, ["decided", "by"], ""))
    assert :ok = FeedErrors.validate(@entry)
    assert FeedErrors.invalid(%{"k" => Map.delete(@entry, "proof")}) == [{"k", :invalid}]
  end
end
