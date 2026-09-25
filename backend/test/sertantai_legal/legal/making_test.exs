defmodule SertantaiLegal.Legal.MakingTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Making

  @now ~U[2026-09-25 12:00:00.000000Z]

  defp current(attrs \\ %{}) do
    Map.merge(
      %{
        is_making: nil,
        is_making_source: nil,
        is_making_reason: nil,
        is_making_decided_at: nil,
        making_review: nil,
        making_review_at: nil,
        making_enrichment_verdict: nil,
        making_enriched_at: nil,
        making_classification: nil,
        making_classification_source: nil,
        making_confidence: nil,
        making_detection_tier: nil,
        making_detection_signals: nil,
        duty_type: nil,
        record_change_log: nil
      },
      attrs
    )
  end

  describe "plan/4 resolution" do
    test "triage evidence resolves is_making and records the source and reason" do
      attrs =
        Making.plan(
          current(),
          %{making_classification: "making", making_classification_source: "triage"},
          "triage_subscriber",
          @now
        )

      assert attrs.is_making == true
      assert attrs.is_making_source == "triage"
      assert attrs.is_making_reason == "triage: making"
      assert attrs.is_making_decided_at == @now
    end

    test "a triage estimate cannot overturn enrichment evidence (the 26-law bug)" do
      attrs =
        Making.plan(
          current(%{
            is_making: true,
            making_enrichment_verdict: "making",
            duty_type: %{values: ["Duty"]}
          }),
          %{making_classification: "not_making", making_classification_source: "triage"},
          "triage_subscriber",
          @now
        )

      assert attrs.is_making == true
      assert attrs.is_making_source == "enrichment"
    end

    test "legacy duty types keep a law Making against a not_making triage" do
      attrs =
        Making.plan(
          current(%{is_making: false, duty_type: %{"values" => ["Duty", "Power"]}}),
          %{making_classification: "not_making", making_classification_source: "triage"},
          "triage_subscriber",
          @now
        )

      assert attrs.is_making == true
      assert attrs.is_making_source == "legacy_drrp"
    end

    test "callers cannot set is_making directly" do
      attrs = Making.plan(current(%{is_making: false}), %{is_making: true}, "admin_ui", @now)

      assert attrs.is_making == false
      assert attrs.is_making_source == "legacy_is_making"
    end

    test "a human review wins and gets a review timestamp" do
      attrs =
        Making.plan(
          current(%{making_enrichment_verdict: "empowering"}),
          %{making_review: "making"},
          "making_review",
          @now
        )

      assert attrs.is_making == true
      assert attrs.is_making_source == "review"
      assert attrs.making_review_at == @now
    end
  end

  describe "plan/4 detector guard" do
    test "the detector never overwrites a triage classification" do
      attrs =
        Making.plan(
          current(%{
            making_classification: "not_making",
            making_classification_source: "triage",
            making_confidence: 0.2
          }),
          %{
            making_classification: "making",
            making_classification_source: "detector",
            making_confidence: 0.9,
            making_detection_tier: 4
          },
          "persister",
          @now
        )

      refute Map.has_key?(attrs, :making_classification)
      refute Map.has_key?(attrs, :making_confidence)
      refute Map.has_key?(attrs, :making_detection_tier)
      assert attrs.is_making == false
      assert attrs.is_making_source == "triage"
    end

    test "the detector may overwrite an earlier detector classification" do
      attrs =
        Making.plan(
          current(%{
            making_classification: "uncertain",
            making_classification_source: "detector"
          }),
          %{making_classification: "making", making_classification_source: "detector"},
          "persister",
          @now
        )

      assert attrs.making_classification == "making"
      assert attrs.is_making_source == "detector"
    end
  end

  describe "plan/4 change log" do
    test "appends a making entry with changed_by, reason and dissent" do
      attrs =
        Making.plan(
          current(%{is_making: false, making_enrichment_verdict: "making"}),
          %{making_classification: "not_making", making_classification_source: "triage"},
          "triage_subscriber",
          @now
        )

      assert [entry] = attrs.record_change_log
      assert entry["source"] == "making"
      assert entry["changed_by"] == "triage_subscriber"
      assert entry["reason"] =~ "enrichment: making"
      assert entry["dissent"] == ["triage", "legacy_is_making"]
      assert entry["changes"]["is_making"] == %{"old" => false, "new" => true}
    end

    test "a note is stored on the change-log entry" do
      attrs =
        Making.plan(
          current(),
          %{making_review: "not_making"},
          "making_review",
          @now,
          note: "amending SI: duties sit in the principal Act"
        )

      assert [entry] = attrs.record_change_log
      assert entry["note"] == "amending SI: duties sit in the principal Act"
    end

    test "keeps earlier log entries" do
      earlier = %{"source" => "scraper", "changes" => %{}}

      attrs =
        Making.plan(
          current(%{record_change_log: [earlier]}),
          %{making_classification: "making", making_classification_source: "detector"},
          "persister",
          @now
        )

      assert [^earlier, %{"source" => "making"}] = attrs.record_change_log
    end

    test "re-delivered identical evidence changes nothing and logs nothing" do
      state =
        current(%{
          is_making: true,
          is_making_source: "triage",
          is_making_reason: "triage: making",
          making_classification: "making",
          making_classification_source: "triage"
        })

      attrs =
        Making.plan(
          state,
          %{making_classification: "making", making_classification_source: "triage"},
          "triage_subscriber",
          @now
        )

      refute Map.has_key?(attrs, :record_change_log)
      refute Map.has_key?(attrs, :is_making_decided_at)
    end
  end

  describe "plan/4 idempotency" do
    test "re-planning a legacy-resolved law changes nothing, even with a detector estimate" do
      first =
        Making.plan(
          current(%{
            is_making: false,
            making_classification: "making",
            making_classification_source: "detector"
          }),
          %{},
          "backfill",
          @now
        )

      assert first.is_making_source == "legacy_is_making"

      resolved =
        current(%{
          is_making: false,
          making_classification: "making",
          making_classification_source: "detector"
        })
        |> Map.merge(Map.drop(first, [:record_change_log]))

      second = Making.plan(resolved, %{}, "backfill", @now)

      assert second.is_making == false
      assert second.is_making_source == "legacy_is_making"
      refute Map.has_key?(second, :record_change_log)
    end
  end

  describe "evidence/1" do
    test "is_making with no recorded source is legacy evidence" do
      assert Making.evidence(current(%{is_making: false})).legacy_is_making == false
    end

    test "a value already resolved as legacy stays legacy evidence on re-runs" do
      evidence =
        Making.evidence(current(%{is_making: false, is_making_source: "legacy_is_making"}))

      assert evidence.legacy_is_making == false
    end

    test "is_making decided by the resolver is not legacy evidence" do
      evidence = Making.evidence(current(%{is_making: true, is_making_source: "detector"}))

      assert evidence.legacy_is_making == nil
    end

    test "maps a triage-sourced classification to the triage tier" do
      evidence =
        Making.evidence(
          current(%{making_classification: "making", making_classification_source: "triage"})
        )

      assert evidence.triage == "making"
      assert evidence.detector == nil
    end

    test "an unsourced classification counts only as a detector estimate" do
      evidence = Making.evidence(current(%{making_classification: "making"}))

      assert evidence.triage == nil
      assert evidence.detector == "making"
    end

    test "reads duty_type values with atom or string keys" do
      assert Making.evidence(current(%{duty_type: %{values: ["Duty"]}})).legacy_duty_types ==
               ["Duty"]

      assert Making.evidence(current(%{duty_type: %{"values" => ["Right"]}})).legacy_duty_types ==
               ["Right"]
    end
  end

  describe "split_evidence/1" do
    test "separates Making evidence from other attrs, drops is_making, tags detector" do
      {evidence, rest} =
        Making.split_evidence(%{
          title_en: "X",
          is_making: true,
          making_classification: "making",
          making_confidence: 0.9
        })

      assert rest == %{title_en: "X"}

      assert evidence == %{
               making_classification: "making",
               making_classification_source: "detector",
               making_confidence: 0.9
             }
    end

    test "keeps an explicit classification source" do
      {evidence, _} =
        Making.split_evidence(%{
          making_classification: "making",
          making_classification_source: "triage"
        })

      assert evidence.making_classification_source == "triage"
    end
  end
end
