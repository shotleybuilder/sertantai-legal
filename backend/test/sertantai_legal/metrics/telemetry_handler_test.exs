defmodule SertantaiLegal.Metrics.TelemetryHandlerTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Metrics.{TelemetryHandler, FileStore}

  @test_dir Path.join(System.tmp_dir!(), "sertantai_legal_metrics_handler_test")

  setup do
    # Use a temp directory for tests
    Application.put_env(:sertantai_legal, :metrics_dir, @test_dir)

    # Clean up before each test
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    # Ensure handler is detached before each test
    TelemetryHandler.detach()

    on_exit(fn ->
      TelemetryHandler.detach()
      File.rm_rf!(@test_dir)
      Application.delete_env(:sertantai_legal, :metrics_dir)
    end)

    :ok
  end

  describe "attach/0" do
    test "attaches to telemetry events" do
      refute TelemetryHandler.attached?()
      assert :ok = TelemetryHandler.attach()
      assert TelemetryHandler.attached?()
    end

    test "returns error when already attached" do
      TelemetryHandler.attach()
      assert {:error, :already_exists} = TelemetryHandler.attach()
    end
  end

  describe "detach/0" do
    test "detaches handler" do
      TelemetryHandler.attach()
      assert TelemetryHandler.attached?()
      assert :ok = TelemetryHandler.detach()
      refute TelemetryHandler.attached?()
    end

    test "returns error when not attached" do
      assert {:error, :not_found} = TelemetryHandler.detach()
    end
  end

  describe "handle_event/4" do
    test "records taxa classify complete events to file store" do
      TelemetryHandler.attach()

      measurements = %{
        duration_us: 5000,
        actor_duration_us: 1000,
        duty_type_duration_us: 1000,
        popimar_duration_us: 2000,
        purpose_duration_us: 1000,
        text_length: 10_000
      }

      metadata = %{
        source: "body",
        actor_count: 10,
        duty_type_count: 2,
        popimar_count: 3,
        popimar_skipped: false
      }

      :telemetry.execute([:taxa, :classify, :complete], measurements, metadata)

      # Small delay to allow async file write
      Process.sleep(50)

      files = FileStore.list_files()
      assert length(files) == 1

      {:ok, events} = FileStore.load(hd(files))
      assert length(events) == 1

      event = hd(events)
      assert event["event"] == "taxa"
      assert event["measurements"]["duration_us"] == 5000
      assert event["measurements"]["text_length"] == 10_000
      assert event["metadata"]["source"] == "body"
      assert event["metadata"]["popimar_skipped"] == false
    end
  end
end
