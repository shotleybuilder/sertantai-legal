defmodule SertantaiLegal.Scraper.LabelTimelineTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelTimeline

  test "undated_markup/1: markup explained by a dated law record pointing to the same note isn't undated" do
    changes = [
      %{section_id: "L:s.15A", source: "markup", pointer: "c950488", effective_from: nil},
      %{
        section_id: "L:s.15A",
        source: "law",
        pointer: "F:c950488",
        effective_from: ~D[2000-07-28]
      },
      # another note's markup on the row: still undated
      %{section_id: "L:s.16", source: "markup", pointer: "c1", effective_from: nil},
      %{section_id: "L:s.16", source: "law", pointer: "F:c2", effective_from: ~D[2000-07-28]},
      # the law record undated: the markup stays undated
      %{section_id: "L:s.17", source: "markup", pointer: "c3", effective_from: nil},
      %{section_id: "L:s.17", source: "law", pointer: "F:c3", effective_from: nil}
    ]

    assert LabelTimeline.undated_markup(changes) == MapSet.new(["L:s.16", "L:s.17"])
  end
end
