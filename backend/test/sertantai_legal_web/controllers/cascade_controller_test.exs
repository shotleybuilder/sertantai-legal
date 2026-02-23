defmodule SertantaiLegalWeb.CascadeControllerTest do
  use SertantaiLegalWeb.ConnCase

  alias SertantaiLegal.Scraper.CascadeAffectedLaw

  @test_session_id "test-cascade-clear-#{System.unique_integer([:positive])}"

  setup :setup_auth
  setup :setup_admin_session

  setup %{conn: conn} do
    # Note: We don't need to create actual sessions for cascade clear tests
    # The endpoint works with any session_id, even if the session doesn't exist

    # Create some test cascade entries
    {:ok, pending_reparse} =
      CascadeAffectedLaw.create(%{
        session_id: @test_session_id,
        affected_law: "UK_uksi_2025_100",
        update_type: :reparse,
        status: :pending,
        source_laws: ["UK_uksi_2025_1"],
        layer: 1
      })

    {:ok, pending_enacting} =
      CascadeAffectedLaw.create(%{
        session_id: @test_session_id,
        affected_law: "UK_uksi_2025_200",
        update_type: :enacting_link,
        status: :pending,
        source_laws: ["UK_uksi_2025_2"],
        layer: 1
      })

    {:ok, processed_entry} =
      CascadeAffectedLaw.create(%{
        session_id: @test_session_id,
        affected_law: "UK_uksi_2025_300",
        update_type: :reparse,
        status: :processed,
        source_laws: ["UK_uksi_2025_3"],
        layer: 2
      })

    # Create entry in different session (should not be deleted)
    {:ok, other_session_entry} =
      CascadeAffectedLaw.create(%{
        session_id: "other-session",
        affected_law: "UK_uksi_2025_999",
        update_type: :reparse,
        status: :pending,
        source_laws: [],
        layer: 1
      })

    on_exit(fn ->
      # Cleanup: delete test cascade entries
      CascadeAffectedLaw.destroy(other_session_entry)
    end)

    {:ok,
     conn: conn,
     pending_reparse: pending_reparse,
     pending_enacting: pending_enacting,
     processed_entry: processed_entry,
     other_session_entry: other_session_entry}
  end

  describe "DELETE /api/cascade/session/:session_id" do
    test "clears all cascade entries for session", %{conn: conn} do
      # Verify entries exist before clearing
      {:ok, before} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(before) == 3

      # Clear cascade
      conn = delete(conn, ~p"/api/cascade/session/#{@test_session_id}")

      assert json_response(conn, 200) == %{
               "message" => "Cleared all cascade entries for session (database and JSON)",
               "session_id" => @test_session_id,
               "deleted_count" => 3
             }

      # Verify entries were deleted
      {:ok, after_clear} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(after_clear) == 0
    end

    test "clears both pending and processed entries", %{conn: conn} do
      # Verify mix of statuses before clearing
      {:ok, pending} = CascadeAffectedLaw.by_session_and_status(@test_session_id, :pending)
      {:ok, processed} = CascadeAffectedLaw.by_session_and_status(@test_session_id, :processed)

      assert length(pending) == 2
      assert length(processed) == 1

      # Clear cascade
      conn = delete(conn, ~p"/api/cascade/session/#{@test_session_id}")
      assert json_response(conn, 200)["deleted_count"] == 3

      # Verify both statuses were cleared
      {:ok, pending_after} = CascadeAffectedLaw.by_session_and_status(@test_session_id, :pending)

      {:ok, processed_after} =
        CascadeAffectedLaw.by_session_and_status(@test_session_id, :processed)

      assert length(pending_after) == 0
      assert length(processed_after) == 0
    end

    test "does not affect other sessions", %{conn: conn, other_session_entry: other_entry} do
      # Clear test session
      conn = delete(conn, ~p"/api/cascade/session/#{@test_session_id}")
      assert json_response(conn, 200)["deleted_count"] == 3

      # Verify other session entry still exists
      {:ok, other_entries} = CascadeAffectedLaw.by_session("other-session")
      assert length(other_entries) == 1
      assert hd(other_entries).id == other_entry.id
    end

    test "returns 0 deleted_count for session with no cascade entries", %{conn: conn} do
      # Test with a session that has no cascade entries (doesn't need to exist)
      empty_session_id = "empty-cascade-session-#{System.unique_integer([:positive])}"

      conn = delete(conn, ~p"/api/cascade/session/#{empty_session_id}")

      assert json_response(conn, 200) == %{
               "message" => "Cleared all cascade entries for session (database and JSON)",
               "session_id" => empty_session_id,
               "deleted_count" => 0
             }
    end

    test "handles non-existent session gracefully", %{conn: conn} do
      conn = delete(conn, ~p"/api/cascade/session/non-existent-session")

      assert json_response(conn, 200) == %{
               "message" => "Cleared all cascade entries for session (database and JSON)",
               "session_id" => "non-existent-session",
               "deleted_count" => 0
             }
    end
  end

  describe "cascade rebuild workflow" do
    test "cascade can be rebuilt after clearing", %{conn: conn} do
      # 1. Verify initial cascade entries exist
      {:ok, initial} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(initial) == 3

      # 2. Clear cascade
      conn = delete(conn, ~p"/api/cascade/session/#{@test_session_id}")
      assert json_response(conn, 200)["deleted_count"] == 3

      # 3. Verify cleared
      {:ok, after_clear} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(after_clear) == 0

      # 4. Simulate rebuild by creating new cascade entries (with layer tracking)
      {:ok, _new_entry} =
        CascadeAffectedLaw.create(%{
          session_id: @test_session_id,
          affected_law: "UK_uksi_2025_400",
          update_type: :reparse,
          status: :pending,
          source_laws: ["UK_uksi_2025_4"],
          layer: 1
        })

      # 5. Verify rebuild
      {:ok, after_rebuild} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(after_rebuild) == 1
      rebuilt_entry = hd(after_rebuild)
      assert rebuilt_entry.layer == 1
      assert rebuilt_entry.affected_law == "UK_uksi_2025_400"
    end

    test "layer tracking works correctly after rebuild", %{conn: conn} do
      # Clear cascade
      delete(conn, ~p"/api/cascade/session/#{@test_session_id}")

      # Rebuild with multiple layers
      {:ok, _layer1} =
        CascadeAffectedLaw.create(%{
          session_id: @test_session_id,
          affected_law: "UK_uksi_2025_L1",
          update_type: :reparse,
          status: :pending,
          source_laws: ["UK_uksi_2025_source"],
          layer: 1
        })

      {:ok, _layer2} =
        CascadeAffectedLaw.create(%{
          session_id: @test_session_id,
          affected_law: "UK_uksi_2025_L2",
          update_type: :reparse,
          status: :pending,
          source_laws: ["UK_uksi_2025_L1"],
          layer: 2
        })

      {:ok, _layer3_deferred} =
        CascadeAffectedLaw.create(%{
          session_id: @test_session_id,
          affected_law: "UK_uksi_2025_L3",
          update_type: :reparse,
          status: :deferred,
          source_laws: ["UK_uksi_2025_L2"],
          layer: 4
        })

      # Verify layers
      {:ok, entries} = CascadeAffectedLaw.by_session(@test_session_id)
      assert length(entries) == 3

      layers = Enum.map(entries, & &1.layer) |> Enum.sort()
      assert layers == [1, 2, 4]

      # Verify layer 3+ is deferred
      deferred = Enum.find(entries, &(&1.status == :deferred))
      assert deferred.layer == 4
    end
  end

  describe "integration with cascade index endpoint" do
    test "index shows correct counts after clearing", %{conn: conn} do
      # Check initial counts
      conn_get = get(conn, ~p"/api/cascade", %{session_id: @test_session_id})
      initial_summary = json_response(conn_get, 200)["summary"]
      assert initial_summary["total_pending"] == 2

      # Clear cascade
      conn_delete = delete(conn, ~p"/api/cascade/session/#{@test_session_id}")
      assert json_response(conn_delete, 200)["deleted_count"] == 3

      # Check counts after clearing
      conn_get_after = get(conn, ~p"/api/cascade", %{session_id: @test_session_id})
      after_summary = json_response(conn_get_after, 200)["summary"]

      assert after_summary["total_pending"] == 0
      assert after_summary["reparse_in_db_count"] == 0
      assert after_summary["enacting_in_db_count"] == 0
    end
  end
end
