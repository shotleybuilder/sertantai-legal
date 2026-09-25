defmodule SertantaiLegal.Legal.Making.BackfillTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Making.Backfill

  defp row(attrs) do
    Map.merge(
      %{
        making_classification: nil,
        making_classification_source: nil,
        making_detection_signals: nil,
        making_enrichment_verdict: nil,
        has_fitness: false,
        duty_type: nil
      },
      attrs
    )
  end

  describe "infer_evidence/1 classification source" do
    test "detector signals (detected_at: metadata) → detector" do
      evidence =
        Backfill.infer_evidence(
          row(%{
            making_classification: "making",
            making_detection_signals: %{"detected_at" => "metadata", "signals" => []}
          })
        )

      assert evidence.making_classification_source == "detector"
    end

    test "triage counts → triage" do
      evidence =
        Backfill.infer_evidence(
          row(%{
            making_classification: "not_making",
            making_detection_signals: %{"amendment" => 3, "total" => 10, "with_actor" => 0}
          })
        )

      assert evidence.making_classification_source == "triage"
    end

    test "double-encoded detector signals → decoded and detector" do
      encoded = Jason.encode!(%{"classification" => "uncertain", "composite_score" => 0.5})

      evidence =
        Backfill.infer_evidence(
          row(%{making_classification: "uncertain", making_detection_signals: encoded})
        )

      assert evidence.making_classification_source == "detector"

      assert evidence.making_detection_signals == %{
               "classification" => "uncertain",
               "composite_score" => 0.5
             }
    end

    test "classification without signals → detector (the weaker estimate)" do
      assert Backfill.infer_evidence(row(%{making_classification: "making"})).making_classification_source ==
               "detector"
    end

    test "an existing source is kept" do
      evidence =
        Backfill.infer_evidence(
          row(%{making_classification: "making", making_classification_source: "triage"})
        )

      refute Map.has_key?(evidence, :making_classification_source)
    end

    test "no classification → no source" do
      refute Map.has_key?(Backfill.infer_evidence(row(%{})), :making_classification_source)
    end
  end

  describe "infer_evidence/1 enrichment verdict" do
    # Historical duty_type is not trusted as enrichment evidence: fractalaw's
    # published aggregates were stale (pre-hub regex pass, fractalaw QQ T2).
    # It counts only as legacy_drrp; real verdicts come from fresh publishes.
    test "fractalaw fitness with DRRP → no inferred verdict" do
      evidence =
        Backfill.infer_evidence(row(%{has_fitness: true, duty_type: %{"values" => ["Right"]}}))

      refute Map.has_key?(evidence, :making_enrichment_verdict)
    end

    test "fitness without DRRP → no verdict" do
      refute Map.has_key?(
               Backfill.infer_evidence(row(%{has_fitness: true})),
               :making_enrichment_verdict
             )
    end
  end
end
