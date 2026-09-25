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
    test "fractalaw fitness with DRRP → verdict inferred from duty types" do
      evidence =
        Backfill.infer_evidence(row(%{has_fitness: true, duty_type: %{"values" => ["Right"]}}))

      assert evidence.making_enrichment_verdict == "empowering"
    end

    test "fitness without DRRP → no verdict (ambiguous, fractalaw T1)" do
      refute Map.has_key?(
               Backfill.infer_evidence(row(%{has_fitness: true})),
               :making_enrichment_verdict
             )
    end

    test "DRRP without fitness stays legacy evidence → no verdict" do
      evidence = Backfill.infer_evidence(row(%{duty_type: %{"values" => ["Duty"]}}))

      refute Map.has_key?(evidence, :making_enrichment_verdict)
    end

    test "an existing verdict is kept" do
      evidence =
        Backfill.infer_evidence(
          row(%{
            has_fitness: true,
            duty_type: %{"values" => ["Duty"]},
            making_enrichment_verdict: "empowering"
          })
        )

      refute Map.has_key?(evidence, :making_enrichment_verdict)
    end
  end
end
