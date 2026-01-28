defmodule SertantaiLegal.Metrics.FileStoreTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Metrics.FileStore

  @test_dir Path.join(System.tmp_dir!(), "sertantai_legal_metrics_test")

  setup do
    # Use a temp directory for tests
    Application.put_env(:sertantai_legal, :metrics_dir, @test_dir)

    # Clean up before each test
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    on_exit(fn ->
      File.rm_rf!(@test_dir)
      Application.delete_env(:sertantai_legal, :metrics_dir)
    end)

    :ok
  end

  describe "record/3" do
    test "creates metrics file and appends NDJSON" do
      measurements = %{duration_us: 1000, text_length: 500}
      metadata = %{source: "body", actor_count: 5}

      assert :ok = FileStore.record(:taxa, measurements, metadata)

      files = FileStore.list_files()
      assert length(files) == 1
      assert String.starts_with?(hd(files), "taxa_")

      {:ok, events} = FileStore.load(hd(files))
      assert length(events) == 1

      event = hd(events)
      assert event["event"] == "taxa"
      assert event["measurements"]["duration_us"] == 1000
      assert event["metadata"]["source"] == "body"
      assert event["timestamp"] != nil
    end

    test "appends multiple events to same file" do
      FileStore.record(:taxa, %{duration_us: 1000}, %{})
      FileStore.record(:taxa, %{duration_us: 2000}, %{})
      FileStore.record(:taxa, %{duration_us: 3000}, %{})

      files = FileStore.list_files()
      assert length(files) == 1

      {:ok, events} = FileStore.load(hd(files))
      assert length(events) == 3

      durations = Enum.map(events, & &1["measurements"]["duration_us"])
      assert durations == [1000, 2000, 3000]
    end
  end

  describe "load/1" do
    test "returns empty list for non-existent file" do
      assert {:ok, []} = FileStore.load("taxa_2020-01-01")
    end

    test "loads events from file" do
      FileStore.record(:taxa, %{duration_us: 1500}, %{source: "test"})

      today = Date.utc_today() |> Date.to_iso8601()
      {:ok, events} = FileStore.load("taxa_#{today}")

      assert length(events) == 1
      assert hd(events)["measurements"]["duration_us"] == 1500
    end

    test "accepts just date (defaults to taxa prefix)" do
      FileStore.record(:taxa, %{duration_us: 1500}, %{})

      today = Date.utc_today() |> Date.to_iso8601()
      {:ok, events} = FileStore.load(today)

      assert length(events) == 1
    end
  end

  describe "load/2 with filters" do
    test "filters by after time" do
      # Create a test file with known timestamps
      file_path = Path.join(@test_dir, "taxa_2026-01-28.ndjson")

      events = [
        %{timestamp: "2026-01-28T10:00:00Z", measurements: %{duration_us: 1000}},
        %{timestamp: "2026-01-28T14:00:00Z", measurements: %{duration_us: 2000}},
        %{timestamp: "2026-01-28T16:00:00Z", measurements: %{duration_us: 3000}}
      ]

      content = events |> Enum.map(&Jason.encode!/1) |> Enum.join("\n")
      File.write!(file_path, content <> "\n")

      {:ok, filtered} =
        FileStore.load("taxa_2026-01-28", after: ~U[2026-01-28 13:00:00Z])

      assert length(filtered) == 2
      durations = Enum.map(filtered, & &1["measurements"]["duration_us"])
      assert durations == [2000, 3000]
    end

    test "filters by before time" do
      file_path = Path.join(@test_dir, "taxa_2026-01-28.ndjson")

      events = [
        %{timestamp: "2026-01-28T10:00:00Z", measurements: %{duration_us: 1000}},
        %{timestamp: "2026-01-28T14:00:00Z", measurements: %{duration_us: 2000}},
        %{timestamp: "2026-01-28T16:00:00Z", measurements: %{duration_us: 3000}}
      ]

      content = events |> Enum.map(&Jason.encode!/1) |> Enum.join("\n")
      File.write!(file_path, content <> "\n")

      {:ok, filtered} =
        FileStore.load("taxa_2026-01-28", before: ~U[2026-01-28 15:00:00Z])

      assert length(filtered) == 2
      durations = Enum.map(filtered, & &1["measurements"]["duration_us"])
      assert durations == [1000, 2000]
    end
  end

  describe "list_files/0" do
    test "returns empty list when no files exist" do
      assert FileStore.list_files() == []
    end

    test "returns files sorted descending" do
      File.write!(Path.join(@test_dir, "taxa_2026-01-26.ndjson"), "{}\n")
      File.write!(Path.join(@test_dir, "taxa_2026-01-28.ndjson"), "{}\n")
      File.write!(Path.join(@test_dir, "taxa_2026-01-27.ndjson"), "{}\n")

      files = FileStore.list_files()

      assert files == ["taxa_2026-01-28", "taxa_2026-01-27", "taxa_2026-01-26"]
    end
  end

  describe "clear/1" do
    test "removes specific file" do
      FileStore.record(:taxa, %{duration_us: 1000}, %{})
      today = Date.utc_today() |> Date.to_iso8601()

      assert length(FileStore.list_files()) == 1
      assert :ok = FileStore.clear("taxa_#{today}")
      assert FileStore.list_files() == []
    end

    test "returns ok for non-existent file" do
      assert :ok = FileStore.clear("taxa_2020-01-01")
    end
  end

  describe "clear_all/0" do
    test "removes all metric files" do
      FileStore.record(:taxa, %{duration_us: 1000}, %{})
      FileStore.record(:taxa, %{duration_us: 2000}, %{})

      assert length(FileStore.list_files()) == 1
      assert :ok = FileStore.clear_all()
      assert FileStore.list_files() == []
    end
  end
end
