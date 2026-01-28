defmodule SertantaiLegal.Metrics.ReporterTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  alias SertantaiLegal.Metrics.Reporter

  @test_dir Path.join(System.tmp_dir!(), "sertantai_legal_metrics_reporter_test")

  setup do
    Application.put_env(:sertantai_legal, :metrics_dir, @test_dir)
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    on_exit(fn ->
      File.rm_rf!(@test_dir)
      Application.delete_env(:sertantai_legal, :metrics_dir)
    end)

    :ok
  end

  describe "summary/1" do
    test "shows no metrics message for empty file" do
      output = capture_io(fn -> Reporter.summary("2026-01-01") end)
      assert output =~ "No metrics found"
    end

    test "displays summary statistics" do
      create_test_metrics("taxa_2026-01-28", [
        %{
          duration_us: 1000,
          actor_duration_us: 200,
          duty_type_duration_us: 200,
          popimar_duration_us: 400,
          purpose_duration_us: 200,
          text_length: 5000
        },
        %{
          duration_us: 2000,
          actor_duration_us: 400,
          duty_type_duration_us: 400,
          popimar_duration_us: 800,
          purpose_duration_us: 400,
          text_length: 10000
        },
        %{
          duration_us: 3000,
          actor_duration_us: 600,
          duty_type_duration_us: 600,
          popimar_duration_us: 1200,
          purpose_duration_us: 600,
          text_length: 15000
        }
      ])

      output = capture_io(fn -> Reporter.summary("taxa_2026-01-28") end)

      assert output =~ "Taxa Metrics Summary"
      assert output =~ "2026-01-28"
      assert output =~ "Total events: 3"
      assert output =~ "Total Duration"
      assert output =~ "Actor Stage"
      assert output =~ "P50"
      assert output =~ "P95"
    end

    test "shows popimar skip percentage" do
      create_test_metrics_with_metadata("taxa_2026-01-28", [
        {%{duration_us: 1000}, %{popimar_skipped: true}},
        {%{duration_us: 2000}, %{popimar_skipped: true}},
        {%{duration_us: 3000}, %{popimar_skipped: false}}
      ])

      output = capture_io(fn -> Reporter.summary("taxa_2026-01-28") end)

      assert output =~ "POPIMAR skipped: 2/3"
      assert output =~ "66.7%"
    end
  end

  describe "compare/2" do
    test "shows comparison between two dates" do
      create_test_metrics("taxa_2026-01-27", [
        %{duration_us: 2000, actor_duration_us: 500},
        %{duration_us: 2200, actor_duration_us: 550}
      ])

      create_test_metrics("taxa_2026-01-28", [
        %{duration_us: 1000, actor_duration_us: 250},
        %{duration_us: 1100, actor_duration_us: 275}
      ])

      output = capture_io(fn -> Reporter.compare("taxa_2026-01-28", "taxa_2026-01-27") end)

      assert output =~ "Taxa Metrics Comparison"
      assert output =~ "2026-01-28"
      assert output =~ "2026-01-27"
      assert output =~ "Change"
      # Should show improvement (negative percentage in green)
      assert output =~ "-"
    end

    test "shows insufficient data message for empty files" do
      output = capture_io(fn -> Reporter.compare("2026-01-28", "2026-01-27") end)
      assert output =~ "Insufficient data"
    end
  end

  describe "list/0" do
    test "shows no files message when empty" do
      output = capture_io(fn -> Reporter.list() end)
      assert output =~ "No metric files found"
    end

    test "lists available files with event counts" do
      create_test_metrics("taxa_2026-01-27", [%{duration_us: 1000}])
      create_test_metrics("taxa_2026-01-28", [%{duration_us: 1000}, %{duration_us: 2000}])

      output = capture_io(fn -> Reporter.list() end)

      assert output =~ "Available metric files"
      assert output =~ "taxa_2026-01-28 (2 events)"
      assert output =~ "taxa_2026-01-27 (1 events)"
    end
  end

  describe "export/2" do
    test "exports as table format" do
      create_test_metrics("taxa_2026-01-28", [
        %{
          duration_us: 1000,
          actor_duration_us: 200,
          duty_type_duration_us: 200,
          popimar_duration_us: 400,
          purpose_duration_us: 200,
          text_length: 5000
        }
      ])

      output = capture_io(fn -> Reporter.export("taxa_2026-01-28") end)

      assert output =~ "Timestamp"
      assert output =~ "Total"
      assert output =~ "Actor"
      assert output =~ "5000"
    end

    test "exports as csv format" do
      create_test_metrics_with_metadata("taxa_2026-01-28", [
        {%{
           duration_us: 1000,
           actor_duration_us: 200,
           duty_type_duration_us: 200,
           popimar_duration_us: 400,
           purpose_duration_us: 200,
           text_length: 5000
         }, %{popimar_skipped: false}}
      ])

      output = capture_io(fn -> Reporter.export("taxa_2026-01-28", format: :csv) end)

      assert output =~
               "timestamp,total_ms,actor_ms,duty_type_ms,popimar_ms,purpose_ms,text_length,popimar_skipped"

      assert output =~ "5000"
      assert output =~ "false"
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp create_test_metrics(filename, measurements_list) do
    file_path = Path.join(@test_dir, "#{filename}.ndjson")

    events =
      Enum.map(measurements_list, fn measurements ->
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          event: "taxa",
          measurements: measurements,
          metadata: %{}
        }
      end)

    content = events |> Enum.map(&Jason.encode!/1) |> Enum.join("\n")
    File.write!(file_path, content <> "\n")
  end

  defp create_test_metrics_with_metadata(filename, items) do
    file_path = Path.join(@test_dir, "#{filename}.ndjson")

    events =
      Enum.map(items, fn {measurements, metadata} ->
        %{
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          event: "taxa",
          measurements: measurements,
          metadata: metadata
        }
      end)

    content = events |> Enum.map(&Jason.encode!/1) |> Enum.join("\n")
    File.write!(file_path, content <> "\n")
  end
end
