defmodule SertantaiLegal.Sync.ComplianceMetricsTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Sync.Templates.{ComplianceMetrics, WebhookEvent}

  @test_org_id "test-metrics-org-001"

  setup do
    ComplianceMetrics.init()
    # Clear any previous test data
    :ets.delete_all_objects(:compliance_metrics)
    :ok
  end

  describe "process_event/2 — assessment status changes" do
    test "tracks compliant status" do
      event = build_event(%{"SA_Compliance_Status" => "Compliant"})
      assert :ok = ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.compliant == 1
    end

    test "tracks non-compliant status" do
      event = build_event(%{"SA_Compliance_Status" => "Non-Compliant"})
      assert :ok = ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.non_compliant == 1
    end

    test "tracks partially compliant status" do
      event = build_event(%{"SA_Compliance_Status" => "Partially Compliant"})
      assert :ok = ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.partially_compliant == 1
    end

    test "accumulates multiple events" do
      ComplianceMetrics.process_event(
        build_event(%{"SA_Compliance_Status" => "Compliant"}),
        @test_org_id
      )

      ComplianceMetrics.process_event(
        build_event(%{"SA_Compliance_Status" => "Compliant"}),
        @test_org_id
      )

      ComplianceMetrics.process_event(
        build_event(%{"SA_Compliance_Status" => "Non-Compliant"}),
        @test_org_id
      )

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.compliant == 2
      assert metrics.non_compliant == 1
    end

    test "updates last_assessment_at timestamp" do
      event = build_event(%{"SA_Compliance_Status" => "Compliant"})
      ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.last_assessment_at != nil
    end
  end

  describe "process_event/2 — action status changes" do
    test "tracks completed actions" do
      event = build_event(%{"SA_Status" => "Completed"})
      assert :ok = ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.actions_completed == 1
    end

    test "tracks open actions on create" do
      event = %WebhookEvent{
        event_type: :row_created,
        changed_fields: %{"SA_Status" => "Open"},
        timestamp: DateTime.utc_now(),
        provider: :baserow,
        table_id: 1,
        row_id: 1
      }

      assert :ok = ComplianceMetrics.process_event(event, @test_org_id)

      metrics = ComplianceMetrics.get_metrics(@test_org_id)
      assert metrics.actions_open == 1
    end
  end

  describe "process_event/2 — irrelevant events" do
    test "ignores events without compliance fields" do
      event = build_event(%{"SA_Notes" => "some text"})
      assert :ignored = ComplianceMetrics.process_event(event, @test_org_id)
    end

    test "ignores delete events" do
      event = %WebhookEvent{
        event_type: :row_deleted,
        changed_fields: %{},
        timestamp: DateTime.utc_now(),
        provider: :baserow,
        table_id: 1,
        row_id: 1
      }

      assert :ignored = ComplianceMetrics.process_event(event, @test_org_id)
    end
  end

  describe "get_metrics/1" do
    test "returns defaults for unknown org" do
      metrics = ComplianceMetrics.get_metrics("unknown-org")
      assert metrics.compliant == 0
      assert metrics.non_compliant == 0
      assert metrics.actions_open == 0
    end
  end

  describe "isolation between orgs" do
    test "metrics are per-org" do
      ComplianceMetrics.process_event(
        build_event(%{"SA_Compliance_Status" => "Compliant"}),
        "org-a"
      )

      ComplianceMetrics.process_event(
        build_event(%{"SA_Compliance_Status" => "Non-Compliant"}),
        "org-b"
      )

      assert ComplianceMetrics.get_metrics("org-a").compliant == 1
      assert ComplianceMetrics.get_metrics("org-a").non_compliant == 0
      assert ComplianceMetrics.get_metrics("org-b").compliant == 0
      assert ComplianceMetrics.get_metrics("org-b").non_compliant == 1
    end
  end

  defp build_event(changed_fields) do
    %WebhookEvent{
      event_type: :row_updated,
      changed_fields: changed_fields,
      timestamp: DateTime.utc_now(),
      provider: :baserow,
      table_id: 1,
      row_id: 1
    }
  end
end
