defmodule SertantaiLegal.Scraper.CascadeAffectedLawTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Scraper.CascadeAffectedLaw

  @session_id "test-cascade-#{:erlang.unique_integer([:positive])}"

  describe "create/1" do
    test "creates a cascade entry with required fields" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_1974_37",
          update_type: :reparse
        })

      assert entry.session_id == @session_id
      assert entry.affected_law == "UK_ukpga_1974_37"
      assert entry.update_type == :reparse
      assert entry.status == :pending
      assert entry.source_laws == []
    end

    test "creates a cascade entry with source_laws" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_1974_38",
          update_type: :enacting_link,
          source_laws: ["UK_uksi_2025_100", "UK_uksi_2025_101"]
        })

      assert entry.update_type == :enacting_link
      assert entry.source_laws == ["UK_uksi_2025_100", "UK_uksi_2025_101"]
    end

    test "fails without required fields" do
      assert {:error, _} = CascadeAffectedLaw.create(%{})
      assert {:error, _} = CascadeAffectedLaw.create(%{session_id: @session_id})

      assert {:error, _} =
               CascadeAffectedLaw.create(%{
                 session_id: @session_id,
                 affected_law: "UK_ukpga_1974_39"
               })
    end

    test "enforces valid update_type values" do
      assert {:error, _} =
               CascadeAffectedLaw.create(%{
                 session_id: @session_id,
                 affected_law: "UK_ukpga_1974_40",
                 update_type: :invalid_type
               })
    end

    test "enforces valid status values" do
      assert {:error, _} =
               CascadeAffectedLaw.create(%{
                 session_id: @session_id,
                 affected_law: "UK_ukpga_1974_41",
                 update_type: :reparse,
                 status: :invalid_status
               })
    end
  end

  describe "unique constraint (session_id, affected_law)" do
    test "prevents duplicate entries for same session and affected_law" do
      {:ok, entry1} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2000_1",
          update_type: :reparse,
          source_laws: ["source1"]
        })

      # Direct create should fail due to unique constraint
      {:error, error} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2000_1",
          update_type: :enacting_link,
          source_laws: ["source2"]
        })

      assert inspect(error) =~ "unique" or inspect(error) =~ "constraint"

      # Verify original entry unchanged
      {:ok, fetched} = CascadeAffectedLaw.by_session_and_law(@session_id, "UK_ukpga_2000_1")
      assert fetched.id == entry1.id
      assert fetched.source_laws == ["source1"]
    end

    test "allows same affected_law in different sessions" do
      {:ok, entry1} =
        CascadeAffectedLaw.create(%{
          session_id: "session-x",
          affected_law: "UK_ukpga_2000_2",
          update_type: :reparse
        })

      {:ok, entry2} =
        CascadeAffectedLaw.create(%{
          session_id: "session-y",
          affected_law: "UK_ukpga_2000_2",
          update_type: :reparse
        })

      assert entry1.id != entry2.id
    end
  end

  describe "append_source_law/2" do
    setup do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2010_1",
          update_type: :reparse,
          source_laws: ["UK_uksi_2025_1"]
        })

      {:ok, entry: entry}
    end

    test "appends a new source law", %{entry: entry} do
      {:ok, updated} =
        CascadeAffectedLaw.append_source_law(entry, %{source_law: "UK_uksi_2025_2"})

      assert updated.source_laws == ["UK_uksi_2025_1", "UK_uksi_2025_2"]
    end

    test "does not duplicate existing source law", %{entry: entry} do
      {:ok, updated} =
        CascadeAffectedLaw.append_source_law(entry, %{source_law: "UK_uksi_2025_1"})

      # Should still have only one entry
      assert updated.source_laws == ["UK_uksi_2025_1"]
    end

    test "appends multiple source laws in sequence", %{entry: entry} do
      {:ok, updated1} =
        CascadeAffectedLaw.append_source_law(entry, %{source_law: "UK_uksi_2025_2"})

      {:ok, updated2} =
        CascadeAffectedLaw.append_source_law(updated1, %{source_law: "UK_uksi_2025_3"})

      {:ok, updated3} =
        CascadeAffectedLaw.append_source_law(updated2, %{source_law: "UK_uksi_2025_4"})

      assert updated3.source_laws == [
               "UK_uksi_2025_1",
               "UK_uksi_2025_2",
               "UK_uksi_2025_3",
               "UK_uksi_2025_4"
             ]
    end

    test "handles empty initial source_laws" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2010_2",
          update_type: :reparse,
          source_laws: []
        })

      {:ok, updated} =
        CascadeAffectedLaw.append_source_law(entry, %{source_law: "UK_uksi_2025_5"})

      assert updated.source_laws == ["UK_uksi_2025_5"]
    end
  end

  describe "upgrade_to_reparse/1" do
    test "upgrades enacting_link to reparse" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2020_1",
          update_type: :enacting_link
        })

      assert entry.update_type == :enacting_link

      {:ok, upgraded} = CascadeAffectedLaw.upgrade_to_reparse(entry)

      assert upgraded.update_type == :reparse
    end

    test "keeps reparse as reparse (no-op)" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2020_2",
          update_type: :reparse
        })

      {:ok, upgraded} = CascadeAffectedLaw.upgrade_to_reparse(entry)

      assert upgraded.update_type == :reparse
    end
  end

  describe "mark_processed/1" do
    test "marks entry as processed" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2030_1",
          update_type: :reparse
        })

      assert entry.status == :pending

      {:ok, processed} = CascadeAffectedLaw.mark_processed(entry)

      assert processed.status == :processed
    end

    test "can mark already processed entry (idempotent)" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2030_2",
          update_type: :reparse,
          status: :processed
        })

      {:ok, processed} = CascadeAffectedLaw.mark_processed(entry)

      assert processed.status == :processed
    end
  end

  describe "query actions" do
    setup do
      # Create entries across different sessions, types, and statuses
      {:ok, e1} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2040_1",
          update_type: :reparse,
          status: :pending
        })

      {:ok, e2} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2040_2",
          update_type: :reparse,
          status: :processed
        })

      {:ok, e3} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2040_3",
          update_type: :enacting_link,
          status: :pending
        })

      {:ok, e4} =
        CascadeAffectedLaw.create(%{
          session_id: "other-cascade-session",
          affected_law: "UK_ukpga_2040_4",
          update_type: :reparse
        })

      {:ok, entries: [e1, e2, e3, e4]}
    end

    test "by_session returns only entries for that session", %{entries: [e1, e2, e3, _e4]} do
      {:ok, entries} = CascadeAffectedLaw.by_session(@session_id)

      assert length(entries) == 3
      ids = Enum.map(entries, & &1.id)
      assert e1.id in ids
      assert e2.id in ids
      assert e3.id in ids
    end

    test "by_session_and_type filters by update_type", %{entries: [e1, e2, _e3, _e4]} do
      {:ok, entries} = CascadeAffectedLaw.by_session_and_type(@session_id, :reparse)

      assert length(entries) == 2
      ids = Enum.map(entries, & &1.id)
      assert e1.id in ids
      assert e2.id in ids
    end

    test "by_session_and_status filters by status", %{entries: [e1, _e2, e3, _e4]} do
      {:ok, entries} = CascadeAffectedLaw.by_session_and_status(@session_id, :pending)

      assert length(entries) == 2
      ids = Enum.map(entries, & &1.id)
      assert e1.id in ids
      assert e3.id in ids
    end

    test "pending_for_session returns pending entries", %{entries: [e1, _e2, e3, _e4]} do
      {:ok, entries} = CascadeAffectedLaw.pending_for_session(@session_id)

      assert length(entries) == 2
      ids = Enum.map(entries, & &1.id)
      assert e1.id in ids
      assert e3.id in ids
    end

    test "by_session_and_law returns specific entry", %{entries: [e1, _e2, _e3, _e4]} do
      {:ok, entry} = CascadeAffectedLaw.by_session_and_law(@session_id, "UK_ukpga_2040_1")

      assert entry.id == e1.id
    end

    test "by_session_and_law returns error for non-existent entry" do
      {:error, %Ash.Error.Invalid{}} =
        CascadeAffectedLaw.by_session_and_law(@session_id, "non-existent")
    end

    test "by_session returns empty list for non-existent session" do
      {:ok, []} = CascadeAffectedLaw.by_session("non-existent-session")
    end
  end

  describe "edge cases" do
    test "handles empty source_laws array" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2050_1",
          update_type: :reparse,
          source_laws: []
        })

      assert entry.source_laws == []
    end

    test "handles large source_laws array" do
      large_sources = Enum.map(1..100, fn i -> "UK_uksi_2025_#{i}" end)

      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2050_2",
          update_type: :reparse,
          source_laws: large_sources
        })

      assert length(entry.source_laws) == 100
    end

    test "handles special characters in affected_law" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukla_1845_149",
          update_type: :reparse
        })

      assert entry.affected_law == "UK_ukla_1845_149"
    end

    test "preserves source_laws order" do
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2050_3",
          update_type: :reparse,
          source_laws: ["z_last", "a_first", "m_middle"]
        })

      # Order should be preserved as inserted
      assert entry.source_laws == ["z_last", "a_first", "m_middle"]
    end

    test "full workflow: create -> append -> upgrade -> process" do
      # 1. Create as enacting_link
      {:ok, entry} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: "UK_ukpga_2050_4",
          update_type: :enacting_link,
          source_laws: ["source1"]
        })

      assert entry.update_type == :enacting_link
      assert entry.status == :pending

      # 2. Append another source
      {:ok, appended} = CascadeAffectedLaw.append_source_law(entry, %{source_law: "source2"})
      assert appended.source_laws == ["source1", "source2"]

      # 3. Upgrade to reparse (law now needs full re-scrape)
      {:ok, upgraded} = CascadeAffectedLaw.upgrade_to_reparse(appended)
      assert upgraded.update_type == :reparse

      # 4. Mark as processed
      {:ok, processed} = CascadeAffectedLaw.mark_processed(upgraded)
      assert processed.status == :processed

      # Verify final state
      {:ok, final} = CascadeAffectedLaw.by_session_and_law(@session_id, "UK_ukpga_2050_4")
      assert final.update_type == :reparse
      assert final.status == :processed
      assert final.source_laws == ["source1", "source2"]
    end
  end

  describe "deduplication scenario" do
    test "simulates real-world cascade deduplication" do
      # Scenario: Three laws (A, B, C) all amend the same parent law (P)
      # Only one cascade entry should exist for P with all three as sources

      parent_law = "UK_ukpga_1974_37"

      # First law A amends parent P
      {:ok, entry1} =
        CascadeAffectedLaw.create(%{
          session_id: @session_id,
          affected_law: parent_law,
          update_type: :reparse,
          source_laws: ["UK_uksi_2025_A"]
        })

      # Second law B also amends parent P - should append to existing
      {:ok, existing} = CascadeAffectedLaw.by_session_and_law(@session_id, parent_law)

      {:ok, _entry2} =
        CascadeAffectedLaw.append_source_law(existing, %{source_law: "UK_uksi_2025_B"})

      # Third law C also amends parent P - should append to existing
      {:ok, existing2} = CascadeAffectedLaw.by_session_and_law(@session_id, parent_law)

      {:ok, _entry3} =
        CascadeAffectedLaw.append_source_law(existing2, %{source_law: "UK_uksi_2025_C"})

      # Verify: Only one entry exists with all three sources
      {:ok, entries} = CascadeAffectedLaw.by_session(@session_id)
      parent_entries = Enum.filter(entries, &(&1.affected_law == parent_law))

      assert length(parent_entries) == 1

      final_entry = hd(parent_entries)
      assert final_entry.id == entry1.id
      assert final_entry.source_laws == ["UK_uksi_2025_A", "UK_uksi_2025_B", "UK_uksi_2025_C"]
    end
  end
end
