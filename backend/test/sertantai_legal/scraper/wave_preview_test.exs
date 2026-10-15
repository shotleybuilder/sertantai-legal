defmodule SertantaiLegal.Scraper.WavePreviewTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.WavePreview

  defp l(status, from \\ nil, by \\ nil, territory \\ nil),
    do: %{status: status, effective_from: from, changed_by: by, territory: territory}

  test "label_diffs/2: each field that differs as at today, a provision with no period is unknown (nil)" do
    before = %{
      "L:s.1" => l("in_force", ~D[2001-01-01], "UK_uksi_2001_1", "E+W"),
      "L:s.2" => l("in_force"),
      "L:s.4" => l("in_force")
    }

    after_ = %{
      "L:s.1" => l("repealed", ~D[2001-01-01], "UK_uksi_2001_1", "E+W"),
      "L:s.2" => l("in_force", ~D[2010-05-01], "UK_uksi_2010_9"),
      "L:s.3" => l("prospective")
    }

    assert WavePreview.label_diffs(before, after_) == [
             {"L:s.1", :status, "in_force", "repealed"},
             {"L:s.2", :effective_from, nil, ~D[2010-05-01]},
             {"L:s.2", :changed_by, nil, "UK_uksi_2010_9"},
             {"L:s.3", :status, nil, "prospective"},
             {"L:s.4", :status, "in_force", nil}
           ]
  end

  test "class/1: a diff's class — status transitions by value, dates gained / emptied / moved, law and territory changes" do
    assert WavePreview.class({"x", :status, "in_force", "repealed"}) == "status in_force→repealed"
    assert WavePreview.class({"x", :status, nil, "in_force"}) == "status unknown→in_force"

    assert WavePreview.class({"x", :effective_from, nil, ~D[2010-05-01]}) ==
             "effective_from gained"

    assert WavePreview.class({"x", :effective_from, ~D[2010-05-01], nil}) ==
             "effective_from emptied"

    assert WavePreview.class({"x", :effective_from, ~D[2009-01-01], ~D[2010-05-01]}) ==
             "effective_from moved"

    assert WavePreview.class({"x", :changed_by, "A", "B"}) == "changed_by changed"
    assert WavePreview.class({"x", :territory, "E+W", nil}) == "territory E+W→unknown"
  end

  test "column_drift/2: rows whose parse-time columns change, by column" do
    before = %{
      "L:s.1" => %{effect_ids: ["e1"], excluded_extent: nil, territory_provenance: []},
      "L:s.2" => %{effect_ids: nil, excluded_extent: "S", territory_provenance: []}
    }

    after_ = %{
      "L:s.1" => %{effect_ids: ["e1", "e2"], excluded_extent: nil, territory_provenance: []},
      "L:s.2" => %{effect_ids: nil, excluded_extent: "S", territory_provenance: []},
      "L:s.3" => %{effect_ids: nil, excluded_extent: nil, territory_provenance: []}
    }

    assert WavePreview.column_drift(before, after_) == %{
             effect_ids: 1,
             excluded_extent: 0,
             territory_provenance: 0,
             rows_added: 1,
             rows_removed: 0
           }
  end
end
