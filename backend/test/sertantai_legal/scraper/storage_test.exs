defmodule SertantaiLegal.Scraper.StorageTest do
  use ExUnit.Case

  alias SertantaiLegal.Scraper.Storage

  @test_session_id "test-session-#{:rand.uniform(100_000)}"

  setup do
    # Clean up any existing test session
    Storage.delete_session(@test_session_id)
    on_exit(fn -> Storage.delete_session(@test_session_id) end)
    :ok
  end

  describe "session_path/1" do
    test "returns correct path structure" do
      path = Storage.session_path("2024-12-01-to-05")
      assert path =~ "priv/scraper/2024-12-01-to-05"
    end
  end

  describe "file_path/2" do
    test "returns correct path for raw file" do
      path = Storage.file_path("test-session", :raw)
      assert path =~ "test-session/raw.json"
    end

    test "returns correct path for group1 file" do
      path = Storage.file_path("test-session", :group1)
      assert path =~ "test-session/inc_w_si.json"
    end

    test "returns correct path for group2 file" do
      path = Storage.file_path("test-session", :group2)
      assert path =~ "test-session/inc_wo_si.json"
    end

    test "returns correct path for group3 file" do
      path = Storage.file_path("test-session", :group3)
      assert path =~ "test-session/exc.json"
    end

    test "returns correct path for metadata file" do
      path = Storage.file_path("test-session", :metadata)
      assert path =~ "test-session/metadata.json"
    end
  end

  describe "relative_path/2" do
    test "returns session-relative path for raw file" do
      path = Storage.relative_path("test-session", :raw)
      assert path == "test-session/raw.json"
    end
  end

  describe "save_json/3 and read_json/2" do
    test "saves and reads list of records" do
      records = [
        %{Title_EN: "Test Law 1", Year: 2024},
        %{Title_EN: "Test Law 2", Year: 2024}
      ]

      assert :ok = Storage.save_json(@test_session_id, :raw, records)
      assert {:ok, read_records} = Storage.read_json(@test_session_id, :raw)

      assert length(read_records) == 2
      # Keys are atoms when read back
      assert hd(read_records)[:Title_EN] == "Test Law 1"
    end

    test "saves and reads map (indexed) records" do
      records = %{
        "1" => %{Title_EN: "Test Law 1"},
        "2" => %{Title_EN: "Test Law 2"}
      }

      assert :ok = Storage.save_json(@test_session_id, :group3, records)
      assert {:ok, read_records} = Storage.read_json(@test_session_id, :group3)

      assert is_map(read_records)
      assert Map.has_key?(read_records, :"1") or Map.has_key?(read_records, "1")
    end

    test "creates session directory if it doesn't exist" do
      records = [%{test: true}]
      assert :ok = Storage.save_json(@test_session_id, :raw, records)
      assert Storage.session_exists?(@test_session_id)
    end

    test "returns error for non-existent file" do
      {:error, reason} = Storage.read_json("nonexistent-session", :raw)
      assert reason =~ "Failed to read"
    end
  end

  describe "session_exists?/1" do
    test "returns false for non-existent session" do
      refute Storage.session_exists?("nonexistent-session-#{:rand.uniform(100_000)}")
    end

    test "returns true after creating session" do
      Storage.save_json(@test_session_id, :raw, [])
      assert Storage.session_exists?(@test_session_id)
    end
  end

  describe "file_exists?/2" do
    test "returns false for non-existent file" do
      refute Storage.file_exists?(@test_session_id, :raw)
    end

    test "returns true after saving file" do
      Storage.save_json(@test_session_id, :raw, [])
      assert Storage.file_exists?(@test_session_id, :raw)
    end
  end

  describe "delete_session/1" do
    test "deletes session directory and files" do
      Storage.save_json(@test_session_id, :raw, [])
      Storage.save_json(@test_session_id, :group1, [])

      assert Storage.session_exists?(@test_session_id)

      assert :ok = Storage.delete_session(@test_session_id)

      refute Storage.session_exists?(@test_session_id)
    end

    test "handles non-existent session gracefully" do
      assert :ok = Storage.delete_session("nonexistent-#{:rand.uniform(100_000)}")
    end
  end

  describe "index_records/1" do
    test "creates indexed map with string keys" do
      records = [
        %{Title_EN: "Law 1"},
        %{Title_EN: "Law 2"},
        %{Title_EN: "Law 3"}
      ]

      indexed = Storage.index_records(records)

      assert is_map(indexed)
      assert Map.has_key?(indexed, "1")
      assert Map.has_key?(indexed, "2")
      assert Map.has_key?(indexed, "3")
      assert indexed["1"][:Title_EN] == "Law 1"
    end

    test "handles empty list" do
      indexed = Storage.index_records([])
      assert indexed == %{}
    end
  end

  describe "save_metadata/2" do
    test "saves metadata to metadata.json" do
      metadata = %{
        session_id: @test_session_id,
        categorized_at: "2024-12-01T12:00:00Z",
        counts: %{group1: 5, group2: 10}
      }

      assert :ok = Storage.save_metadata(@test_session_id, metadata)
      assert {:ok, read_metadata} = Storage.read_json(@test_session_id, :metadata)

      assert read_metadata.session_id == @test_session_id
    end
  end

  # ============================================================================
  # Affected Laws Tests (Cascade Update)
  # ============================================================================

  describe "add_affected_laws/5" do
    test "adds affected laws with amending only" do
      amending = ["ukpga/2020/1", "ukpga/2021/2"]
      rescinding = []
      enacted_by = []

      assert :ok = Storage.add_affected_laws(@test_session_id, "uksi/2025/100", amending, rescinding, enacted_by)

      data = Storage.read_affected_laws(@test_session_id)

      assert length(data[:entries]) == 1
      assert hd(data[:entries])[:source_law] == "uksi/2025/100"
      assert hd(data[:entries])[:amending] == amending
      assert data[:all_amending] == amending
      assert data[:all_rescinding] == []
      assert data[:all_enacting_parents] == []
    end

    test "adds affected laws with enacted_by" do
      amending = []
      rescinding = []
      enacted_by = ["ukpga/1974/37", "ukpga/2008/29"]

      assert :ok = Storage.add_affected_laws(@test_session_id, "uksi/2025/100", amending, rescinding, enacted_by)

      data = Storage.read_affected_laws(@test_session_id)

      assert length(data[:entries]) == 1
      assert hd(data[:entries])[:enacted_by] == enacted_by
      assert data[:all_enacting_parents] == enacted_by
    end

    test "accumulates multiple source laws" do
      # First law amends ukpga/2020/1 and is enacted by ukpga/1974/37
      Storage.add_affected_laws(@test_session_id, "uksi/2025/100", ["ukpga/2020/1"], [], ["ukpga/1974/37"])

      # Second law amends ukpga/2020/1 and ukpga/2021/2, enacted by same parent
      Storage.add_affected_laws(@test_session_id, "uksi/2025/101", ["ukpga/2020/1", "ukpga/2021/2"], [], ["ukpga/1974/37"])

      data = Storage.read_affected_laws(@test_session_id)

      assert length(data[:entries]) == 2

      # all_amending should be deduplicated
      assert "ukpga/2020/1" in data[:all_amending]
      assert "ukpga/2021/2" in data[:all_amending]
      assert length(data[:all_amending]) == 2

      # all_enacting_parents should be deduplicated
      assert data[:all_enacting_parents] == ["ukpga/1974/37"]
    end

    test "skips when no affected laws" do
      assert :ok = Storage.add_affected_laws(@test_session_id, "uksi/2025/100", [], [], [])

      # Should not create a file when nothing to add
      refute Storage.file_exists?(@test_session_id, :affected_laws)
    end

    test "handles nil values gracefully" do
      assert :ok = Storage.add_affected_laws(@test_session_id, "uksi/2025/100", nil, nil, nil)
      refute Storage.file_exists?(@test_session_id, :affected_laws)
    end
  end

  describe "read_affected_laws/1" do
    test "returns empty structure when no file exists" do
      data = Storage.read_affected_laws("nonexistent-session")

      assert data[:entries] == []
      assert data[:all_amending] == []
      assert data[:all_rescinding] == []
      assert data[:all_enacting_parents] == []
    end

    test "reads saved affected laws" do
      Storage.add_affected_laws(@test_session_id, "uksi/2025/100", ["ukpga/2020/1"], ["ukpga/2019/1"], ["ukpga/1974/37"])

      data = Storage.read_affected_laws(@test_session_id)

      assert length(data[:entries]) == 1
      assert data[:all_amending] == ["ukpga/2020/1"]
      assert data[:all_rescinding] == ["ukpga/2019/1"]
      assert data[:all_enacting_parents] == ["ukpga/1974/37"]
    end
  end

  describe "get_affected_laws_summary/1" do
    test "returns summary with counts" do
      Storage.add_affected_laws(@test_session_id, "uksi/2025/100", ["ukpga/2020/1", "ukpga/2021/2"], ["ukpga/2019/1"], ["ukpga/1974/37"])
      Storage.add_affected_laws(@test_session_id, "uksi/2025/101", ["ukpga/2020/1"], [], ["ukpga/1974/37", "ukpga/2008/29"])

      summary = Storage.get_affected_laws_summary(@test_session_id)

      assert summary.source_count == 2
      assert "uksi/2025/100" in summary.source_laws
      assert "uksi/2025/101" in summary.source_laws

      assert summary.amending_count == 2
      assert summary.rescinding_count == 1
      assert summary.all_affected_count == 3  # 2 amending + 1 rescinding (deduplicated)

      assert summary.enacting_parents_count == 2
      assert "ukpga/1974/37" in summary.enacting_parents
      assert "ukpga/2008/29" in summary.enacting_parents
    end

    test "returns zeros for empty session" do
      summary = Storage.get_affected_laws_summary("nonexistent-session")

      assert summary.source_count == 0
      assert summary.amending_count == 0
      assert summary.rescinding_count == 0
      assert summary.all_affected_count == 0
      assert summary.enacting_parents_count == 0
    end
  end

  describe "clear_affected_laws/1" do
    test "clears affected laws file" do
      Storage.add_affected_laws(@test_session_id, "uksi/2025/100", ["ukpga/2020/1"], [], ["ukpga/1974/37"])
      assert Storage.file_exists?(@test_session_id, :affected_laws)

      assert :ok = Storage.clear_affected_laws(@test_session_id)
      refute Storage.file_exists?(@test_session_id, :affected_laws)
    end

    test "handles non-existent file gracefully" do
      assert :ok = Storage.clear_affected_laws("nonexistent-session")
    end
  end
end
