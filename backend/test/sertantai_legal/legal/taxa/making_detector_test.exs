defmodule SertantaiLegal.Legal.Taxa.MakingDetectorTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.MakingDetector

  describe "detect/1" do
    test "commencement title with low body -> not_making with high confidence" do
      result =
        MakingDetector.detect(%{
          title_en: "Environment Act 2024 (Commencement No. 3) Order",
          md_body_paras: 3,
          md_schedule_paras: 0,
          md_description: nil
        })

      assert result.classification == :not_making
      assert result.confidence < 0.10
      assert result.tier > 0
      assert length(result.signals) >= 1
      assert result.version == 1
    end

    test "appointed day title -> not_making with very high confidence" do
      result =
        MakingDetector.detect(%{
          title_en: "Harbours Act 1964 (Appointed Day) Order 2024",
          md_body_paras: 2,
          md_schedule_paras: 0,
          md_description: nil
        })

      assert result.classification == :not_making
      assert result.confidence < 0.05
    end

    test "amendment title with high body -> uncertain (needs AI)" do
      result =
        MakingDetector.detect(%{
          title_en: "Food Safety (Amendment) Regulations",
          md_body_paras: 150,
          md_schedule_paras: 0,
          md_description: "These Regulations amend the Food Safety Regulations"
        })

      assert result.classification == :uncertain
      assert result.confidence > 0.30
      assert result.confidence < 0.70
    end

    test "amendment title with low body -> not_making" do
      result =
        MakingDetector.detect(%{
          title_en: "Foo (Amendment) Regulations 2024",
          md_body_paras: 4,
          md_schedule_paras: 0,
          md_description: "Regulations to amend the Foo Regulations"
        })

      assert result.classification == :not_making
      assert result.confidence < 0.30
    end

    test "clean title with making description -> making" do
      result =
        MakingDetector.detect(%{
          title_en: "Workplace Health and Safety Regulations 2024",
          md_body_paras: 85,
          md_schedule_paras: 12,
          md_description:
            "An Act to make provision for securing the health, safety and welfare of persons at work"
        })

      assert result.classification == :making
      assert result.confidence >= 0.70
    end

    test "clean title with 'to prohibit' description -> making" do
      result =
        MakingDetector.detect(%{
          title_en: "Asbestos Prohibition Regulations 2024",
          md_body_paras: 60,
          md_schedule_paras: 5,
          md_description: "Regulations to prohibit the importation and use of asbestos"
        })

      assert result.classification == :making
      assert result.confidence >= 0.70
    end

    test "no metadata -> base rate not_making" do
      result = MakingDetector.detect(%{})

      assert result.classification == :not_making
      assert_in_delta result.confidence, 0.173, 0.001
      assert result.signals == []
      assert result.tier == 0
    end

    test "revocation title -> not_making with high confidence" do
      result =
        MakingDetector.detect(%{
          title_en: "Foo (Revocation) Order 2024",
          md_body_paras: 2,
          md_schedule_paras: 0,
          md_description: nil
        })

      assert result.classification == :not_making
      assert result.confidence < 0.10
    end

    test "low body + high schedule -> not_making (amending pattern)" do
      result =
        MakingDetector.detect(%{
          title_en: "Some Regulations 2024",
          md_body_paras: 2,
          md_schedule_paras: 80,
          md_description: nil
        })

      assert result.classification == :not_making
      assert result.confidence < 0.20
    end

    test "clean title, high body, no description -> uncertain" do
      result =
        MakingDetector.detect(%{
          title_en: "Transport Act 2024",
          md_body_paras: 60,
          md_schedule_paras: 10,
          md_description: nil
        })

      # High body pulls toward making but no description confirmation
      # Should be uncertain or making depending on body count
      assert result.classification in [:uncertain, :making]
    end
  end

  describe "to_parsed_law_fields/1" do
    test "converts detection result to persistence map" do
      result =
        MakingDetector.detect(%{
          title_en: "Act (Commencement) Order",
          md_body_paras: 2,
          md_schedule_paras: 0,
          md_description: nil
        })

      fields = MakingDetector.to_parsed_law_fields(result)

      assert is_float(fields.making_confidence)
      assert fields.making_classification in ["making", "not_making", "uncertain"]
      assert is_integer(fields.making_detection_tier)
      assert is_map(fields.making_detection_signals)
      assert fields.making_detection_signals["version"] == 1
      assert fields.making_detection_signals["detected_at"] == "metadata"
      assert is_list(fields.making_detection_signals["signals"])
    end

    test "signal maps have required keys" do
      result =
        MakingDetector.detect(%{
          title_en: "Act (Amendment) Regulations",
          md_body_paras: 100,
          md_schedule_paras: 0,
          md_description: "Regulations to require employers to assess risks"
        })

      fields = MakingDetector.to_parsed_law_fields(result)

      for signal <- fields.making_detection_signals["signals"] do
        assert Map.has_key?(signal, "tier")
        assert Map.has_key?(signal, "signal")
        assert Map.has_key?(signal, "direction")
        assert Map.has_key?(signal, "confidence")
        assert Map.has_key?(signal, "value")
        assert signal["direction"] in ["making", "not_making"]
        assert is_integer(signal["tier"])
        assert is_float(signal["confidence"])
      end
    end
  end

  describe "calculate_composite_score/1" do
    test "returns base rate for empty signals" do
      assert_in_delta MakingDetector.calculate_composite_score([]), 0.173, 0.001
    end

    test "single not_making signal pulls score below base rate" do
      signals = [
        %{tier: 1, signal: "test", direction: :not_making, confidence: 0.99, value: "x"}
      ]

      score = MakingDetector.calculate_composite_score(signals)
      assert score < 0.173
    end

    test "single making signal pulls score above base rate" do
      signals = [
        %{tier: 4, signal: "test", direction: :making, confidence: 0.80, value: "x"}
      ]

      score = MakingDetector.calculate_composite_score(signals)
      assert score > 0.173
    end

    test "opposing signals partially cancel" do
      signals = [
        %{tier: 2, signal: "amend", direction: :not_making, confidence: 0.80, value: "x"},
        %{tier: 3, signal: "body", direction: :making, confidence: 0.70, value: "x"}
      ]

      score = MakingDetector.calculate_composite_score(signals)
      # Should be between the extremes
      assert score > 0.05
      assert score < 0.60
    end
  end
end
