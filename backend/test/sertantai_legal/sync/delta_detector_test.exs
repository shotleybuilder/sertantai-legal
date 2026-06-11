defmodule SertantaiLegal.Sync.DeltaDetectorTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Sync.DeltaDetector

  @now DateTime.utc_now()
  @hour_ago DateTime.add(@now, -3600, :second)
  @two_hours_ago DateTime.add(@now, -7200, :second)

  describe "detect/3" do
    test "new rows — source_id not in mappings" do
      source = [
        %{"_source_id" => "law-1", "Title" => "HSWA"},
        %{"_source_id" => "law-2", "Title" => "CDM"}
      ]

      result = DeltaDetector.detect(source, [])

      assert length(result.new) == 2
      assert result.updated == []
      assert result.deleted == []
      assert result.unchanged == 0
    end

    test "unchanged rows — source_id in mappings, not updated" do
      source = [%{"_source_id" => "law-1", "Title" => "HSWA"}]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now}
      ]

      timestamps = %{"law-1" => @hour_ago}

      result = DeltaDetector.detect(source, mappings, timestamps)

      assert result.new == []
      assert result.updated == []
      assert result.unchanged == 1
    end

    test "updated rows — source updated_at > mapping last_synced_at" do
      source = [%{"_source_id" => "law-1", "Title" => "HSWA Updated"}]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @two_hours_ago}
      ]

      timestamps = %{"law-1" => @hour_ago}

      result = DeltaDetector.detect(source, mappings, timestamps)

      assert length(result.updated) == 1
      [updated] = result.updated
      assert updated["id"] == 100
      assert updated["Title"] == "HSWA Updated"
      assert result.new == []
    end

    test "deleted rows — in mappings but not in source" do
      source = [%{"_source_id" => "law-1", "Title" => "HSWA"}]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now},
        %{source_id: "law-2", external_row_id: 101, last_synced_at: @now}
      ]

      result = DeltaDetector.detect(source, mappings)

      assert length(result.deleted) == 1
      [deleted] = result.deleted
      assert deleted.source_id == "law-2"
      assert deleted.external_row_id == 101
    end

    test "mixed: new + updated + deleted + unchanged" do
      source = [
        %{"_source_id" => "law-1", "Title" => "Unchanged"},
        %{"_source_id" => "law-2", "Title" => "Updated"},
        %{"_source_id" => "law-4", "Title" => "Brand New"}
      ]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now},
        %{source_id: "law-2", external_row_id: 101, last_synced_at: @two_hours_ago},
        %{source_id: "law-3", external_row_id: 102, last_synced_at: @now}
      ]

      timestamps = %{
        "law-1" => @hour_ago,
        "law-2" => @hour_ago,
        "law-4" => @now
      }

      result = DeltaDetector.detect(source, mappings, timestamps)

      assert length(result.new) == 1
      assert hd(result.new)["_source_id"] == "law-4"

      assert length(result.updated) == 1
      assert hd(result.updated)["_source_id"] == "law-2"
      assert hd(result.updated)["id"] == 101

      assert length(result.deleted) == 1
      assert hd(result.deleted).source_id == "law-3"

      assert result.unchanged == 1
    end

    test "no timestamps — all matched rows treated as updated" do
      source = [%{"_source_id" => "law-1", "Title" => "HSWA"}]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now}
      ]

      # No timestamps passed — should treat as updated (safe default)
      result = DeltaDetector.detect(source, mappings)

      assert length(result.updated) == 1
    end

    test "empty source — all mappings become deleted" do
      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now},
        %{source_id: "law-2", external_row_id: 101, last_synced_at: @now}
      ]

      result = DeltaDetector.detect([], mappings)

      assert result.new == []
      assert result.updated == []
      assert length(result.deleted) == 2
    end

    test "idempotent — same source with timestamps before last_synced = all unchanged" do
      source = [
        %{"_source_id" => "law-1", "Title" => "HSWA"},
        %{"_source_id" => "law-2", "Title" => "CDM"}
      ]

      mappings = [
        %{source_id: "law-1", external_row_id: 100, last_synced_at: @now},
        %{source_id: "law-2", external_row_id: 101, last_synced_at: @now}
      ]

      timestamps = %{"law-1" => @hour_ago, "law-2" => @hour_ago}

      result = DeltaDetector.detect(source, mappings, timestamps)

      assert result.new == []
      assert result.updated == []
      assert result.deleted == []
      assert result.unchanged == 2
    end
  end
end
