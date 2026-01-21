defmodule SertantaiLegal.Scraper.ScrapeSessionRecordTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Scraper.ScrapeSessionRecord

  @session_id "test-session-#{:erlang.unique_integer([:positive])}"

  describe "create/1" do
    test "creates a session record with required fields" do
      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_100",
          group: :group1
        })

      assert record.session_id == @session_id
      assert record.law_name == "UK_uksi_2025_100"
      assert record.group == :group1
      assert record.status == :pending
      assert record.selected == false
      assert record.parse_count == 0
      assert record.parsed_data == nil
    end

    test "creates a session record with all fields" do
      parsed_data = %{"title" => "Test Law", "year" => 2025}

      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_101",
          group: :group2,
          status: :parsed,
          selected: true,
          parsed_data: parsed_data
        })

      assert record.status == :parsed
      assert record.selected == true
      assert record.parsed_data == parsed_data
    end

    test "fails without required fields" do
      assert {:error, _} = ScrapeSessionRecord.create(%{})
      assert {:error, _} = ScrapeSessionRecord.create(%{session_id: @session_id})

      assert {:error, _} =
               ScrapeSessionRecord.create(%{
                 session_id: @session_id,
                 law_name: "UK_uksi_2025_102"
               })
    end

    test "enforces valid group values" do
      assert {:error, _} =
               ScrapeSessionRecord.create(%{
                 session_id: @session_id,
                 law_name: "UK_uksi_2025_103",
                 group: :invalid_group
               })
    end

    test "enforces valid status values" do
      assert {:error, _} =
               ScrapeSessionRecord.create(%{
                 session_id: @session_id,
                 law_name: "UK_uksi_2025_104",
                 group: :group1,
                 status: :invalid_status
               })
    end
  end

  describe "unique constraint (session_id, law_name)" do
    test "upserts when creating duplicate record" do
      attrs = %{
        session_id: @session_id,
        law_name: "UK_uksi_2025_200",
        group: :group1
      }

      {:ok, record1} = ScrapeSessionRecord.create(attrs)
      assert record1.status == :pending

      # Create with same session_id + law_name but different group - should upsert
      {:ok, record2} =
        ScrapeSessionRecord.create(Map.merge(attrs, %{group: :group2, status: :parsed}))

      # Should be same record (upserted)
      assert record1.id == record2.id
      assert record2.group == :group2
      assert record2.status == :parsed
    end

    test "allows same law_name in different sessions" do
      {:ok, record1} =
        ScrapeSessionRecord.create(%{
          session_id: "session-a",
          law_name: "UK_uksi_2025_201",
          group: :group1
        })

      {:ok, record2} =
        ScrapeSessionRecord.create(%{
          session_id: "session-b",
          law_name: "UK_uksi_2025_201",
          group: :group1
        })

      assert record1.id != record2.id
    end
  end

  describe "status transitions" do
    setup do
      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_300",
          group: :group1
        })

      {:ok, record: record}
    end

    test "mark_parsed updates status and increments parse_count", %{record: record} do
      parsed_data = %{"title" => "Parsed Law"}

      {:ok, updated} = ScrapeSessionRecord.mark_parsed(record, %{parsed_data: parsed_data})

      assert updated.status == :parsed
      assert updated.parse_count == 1
      assert updated.parsed_data == parsed_data
    end

    test "mark_parsed increments parse_count on subsequent parses", %{record: record} do
      {:ok, parsed1} = ScrapeSessionRecord.mark_parsed(record, %{parsed_data: %{"v" => 1}})
      assert parsed1.parse_count == 1

      {:ok, parsed2} = ScrapeSessionRecord.mark_parsed(parsed1, %{parsed_data: %{"v" => 2}})
      assert parsed2.parse_count == 2

      {:ok, parsed3} = ScrapeSessionRecord.mark_parsed(parsed2, %{parsed_data: %{"v" => 3}})
      assert parsed3.parse_count == 3
    end

    test "mark_confirmed updates status", %{record: record} do
      {:ok, confirmed} = ScrapeSessionRecord.mark_confirmed(record)

      assert confirmed.status == :confirmed
    end

    test "mark_skipped updates status", %{record: record} do
      {:ok, skipped} = ScrapeSessionRecord.mark_skipped(record)

      assert skipped.status == :skipped
    end
  end

  describe "selection" do
    setup do
      {:ok, r1} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_400",
          group: :group1
        })

      {:ok, r2} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_401",
          group: :group1,
          selected: true
        })

      {:ok, r3} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_402",
          group: :group2,
          selected: true
        })

      {:ok, records: [r1, r2, r3]}
    end

    test "set_selected toggles selection", %{records: [r1 | _]} do
      assert r1.selected == false

      {:ok, selected} = ScrapeSessionRecord.set_selected(r1, %{selected: true})
      assert selected.selected == true

      {:ok, deselected} = ScrapeSessionRecord.set_selected(selected, %{selected: false})
      assert deselected.selected == false
    end

    test "selected_in_session returns all selected records", %{records: [_r1, r2, r3]} do
      {:ok, selected} = ScrapeSessionRecord.selected_in_session(@session_id)

      assert length(selected) == 2
      ids = Enum.map(selected, & &1.id)
      assert r2.id in ids
      assert r3.id in ids
    end

    test "selected_in_group returns selected records for specific group", %{
      records: [_r1, r2, _r3]
    } do
      {:ok, selected} = ScrapeSessionRecord.selected_in_group(@session_id, :group1)

      assert length(selected) == 1
      assert hd(selected).id == r2.id
    end
  end

  describe "query actions" do
    setup do
      # Create records across different sessions, groups, and statuses
      {:ok, r1} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_500",
          group: :group1,
          status: :pending
        })

      {:ok, r2} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_501",
          group: :group1,
          status: :parsed
        })

      {:ok, r3} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_502",
          group: :group2,
          status: :confirmed
        })

      {:ok, r4} =
        ScrapeSessionRecord.create(%{
          session_id: "other-session",
          law_name: "UK_uksi_2025_503",
          group: :group1
        })

      {:ok, records: [r1, r2, r3, r4]}
    end

    test "by_session returns only records for that session", %{records: [r1, r2, r3, _r4]} do
      {:ok, records} = ScrapeSessionRecord.by_session(@session_id)

      assert length(records) == 3
      ids = Enum.map(records, & &1.id)
      assert r1.id in ids
      assert r2.id in ids
      assert r3.id in ids
    end

    test "by_session_and_group filters by group", %{records: [r1, r2, _r3, _r4]} do
      {:ok, records} = ScrapeSessionRecord.by_session_and_group(@session_id, :group1)

      assert length(records) == 2
      ids = Enum.map(records, & &1.id)
      assert r1.id in ids
      assert r2.id in ids
    end

    test "by_session_and_status filters by status", %{records: [r1, _r2, _r3, _r4]} do
      {:ok, records} = ScrapeSessionRecord.by_session_and_status(@session_id, :pending)

      assert length(records) == 1
      assert hd(records).id == r1.id
    end

    test "by_session_and_name returns specific record", %{records: [r1, _r2, _r3, _r4]} do
      {:ok, record} = ScrapeSessionRecord.by_session_and_name(@session_id, "UK_uksi_2025_500")

      assert record.id == r1.id
    end

    test "by_session_and_name returns error for non-existent record" do
      {:error, %Ash.Error.Invalid{}} =
        ScrapeSessionRecord.by_session_and_name(@session_id, "non-existent")
    end

    test "by_session returns empty list for non-existent session" do
      {:ok, []} = ScrapeSessionRecord.by_session("non-existent-session")
    end
  end

  describe "edge cases" do
    test "handles empty parsed_data map" do
      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_600",
          group: :group1,
          parsed_data: %{}
        })

      assert record.parsed_data == %{}
    end

    test "handles complex nested parsed_data" do
      complex_data = %{
        "metadata" => %{
          "title" => "Test",
          "nested" => %{"deep" => [1, 2, 3]}
        },
        "amendments" => [
          %{"law" => "ukpga/1974/37", "type" => "amends"}
        ]
      }

      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_uksi_2025_601",
          group: :group1,
          parsed_data: complex_data
        })

      assert record.parsed_data == complex_data
    end

    test "handles special characters in law_name" do
      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: @session_id,
          law_name: "UK_ukla_1845_149",
          group: :group1
        })

      assert record.law_name == "UK_ukla_1845_149"
    end

    test "handles very long session_id" do
      long_session_id = String.duplicate("a", 255)

      {:ok, record} =
        ScrapeSessionRecord.create(%{
          session_id: long_session_id,
          law_name: "UK_uksi_2025_602",
          group: :group1
        })

      assert record.session_id == long_session_id
    end
  end
end
