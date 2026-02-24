defmodule SertantaiLegal.Legal.Taxa.MakingDetectorSignalsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.MakingDetectorSignals, as: Signals

  describe "tier1_title_definitive/2" do
    test "detects Commencement title" do
      signals =
        Signals.tier1_title_definitive([], %{
          title_en: "Environment Act 2024 (Commencement No. 3) Order"
        })

      assert [%{tier: 1, signal: "title_commencement", direction: :not_making}] = signals
      assert hd(signals).confidence == 0.99
    end

    test "detects Appointed Day title" do
      signals =
        Signals.tier1_title_definitive([], %{
          title_en: "Harbours Act 1964 (Appointed Day) Order 2024"
        })

      assert [%{tier: 1, signal: "title_appointed_day", direction: :not_making}] = signals
      assert hd(signals).confidence == 1.0
    end

    test "returns empty for non-matching title" do
      signals =
        Signals.tier1_title_definitive([], %{
          title_en: "Health and Safety at Work etc. Act 1974"
        })

      assert signals == []
    end

    test "returns empty for nil title" do
      assert Signals.tier1_title_definitive([], %{title_en: nil}) == []
    end

    test "returns empty for missing title key" do
      assert Signals.tier1_title_definitive([], %{}) == []
    end

    test "accumulates with existing signals" do
      existing = [%{tier: 3, signal: "test", direction: :making, confidence: 0.5, value: "x"}]

      signals =
        Signals.tier1_title_definitive(existing, %{
          title_en: "Act (Commencement) Order"
        })

      assert length(signals) == 2
    end
  end

  describe "tier2_title_strong/2" do
    test "detects Amendment title" do
      signals = Signals.tier2_title_strong([], %{title_en: "Foo (Amendment) Regulations 2024"})
      assert [%{signal: "title_amendment", direction: :not_making}] = signals
      assert hd(signals).confidence == 0.80
    end

    test "detects Revocation title" do
      signals =
        Signals.tier2_title_strong([], %{title_en: "Foo (Revocation) Regulations 2024"})

      assert Enum.any?(signals, &(&1.signal == "title_revocation"))
    end

    test "detects Repeal title" do
      signals = Signals.tier2_title_strong([], %{title_en: "Foo (Repeal) Act 2024"})
      assert Enum.any?(signals, &(&1.signal == "title_repeal"))
    end

    test "detects Consequential title" do
      signals =
        Signals.tier2_title_strong([], %{
          title_en: "Foo (Consequential Amendments) Order 2024"
        })

      assert Enum.any?(signals, &(&1.signal == "title_consequential"))
    end

    test "detects Transitional title" do
      signals =
        Signals.tier2_title_strong([], %{
          title_en: "Foo (Transitional Provisions) Regulations 2024"
        })

      assert Enum.any?(signals, &(&1.signal == "title_transitional"))
    end

    test "detects multiple title signals" do
      # A law with both Amendment and Repeal in title
      signals =
        Signals.tier2_title_strong([], %{
          title_en: "Foo (Amendment) (Repeal) Regulations 2024"
        })

      signal_names = Enum.map(signals, & &1.signal)
      assert "title_amendment" in signal_names
      assert "title_repeal" in signal_names
    end

    test "returns empty for clean title" do
      signals =
        Signals.tier2_title_strong([], %{
          title_en: "Health and Safety at Work etc. Act 1974"
        })

      assert signals == []
    end
  end

  describe "tier3_structural/2" do
    test "detects low body + high schedule (amending pattern)" do
      signals = Signals.tier3_structural([], %{md_body_paras: 2, md_schedule_paras: 80})
      assert Enum.any?(signals, &(&1.signal == "low_body_high_schedule"))
    end

    test "detects high body paragraphs (substantive content)" do
      signals = Signals.tier3_structural([], %{md_body_paras: 100})
      making_signals = Enum.filter(signals, &(&1.direction == :making))
      assert [%{signal: "high_body_paras"}] = making_signals
    end

    test "high body confidence scales with paragraph count" do
      signals_low = Signals.tier3_structural([], %{md_body_paras: 60})
      signals_high = Signals.tier3_structural([], %{md_body_paras: 200})

      low_conf =
        signals_low |> Enum.find(&(&1.signal == "high_body_paras")) |> Map.get(:confidence)

      high_conf =
        signals_high |> Enum.find(&(&1.signal == "high_body_paras")) |> Map.get(:confidence)

      assert high_conf > low_conf
    end

    test "high body confidence caps at 0.85" do
      signals = Signals.tier3_structural([], %{md_body_paras: 5000})

      conf =
        signals |> Enum.find(&(&1.signal == "high_body_paras")) |> Map.get(:confidence)

      assert conf == 0.85
    end

    test "detects very low body paragraphs" do
      signals = Signals.tier3_structural([], %{md_body_paras: 3})
      assert Enum.any?(signals, &(&1.signal == "very_low_body_paras"))
    end

    test "returns empty for nil paragraph counts" do
      assert Signals.tier3_structural([], %{md_body_paras: nil}) == []
      assert Signals.tier3_structural([], %{}) == []
    end

    test "body=3 with sched=80 fires both low_body_high_schedule and very_low_body" do
      signals = Signals.tier3_structural([], %{md_body_paras: 3, md_schedule_paras: 80})
      signal_names = Enum.map(signals, & &1.signal)
      assert "low_body_high_schedule" in signal_names
      assert "very_low_body_paras" in signal_names
    end
  end

  describe "tier4_description/2" do
    test "detects making language in description" do
      signals =
        Signals.tier4_description([], %{
          md_description:
            "An Act to make provision for securing the health, safety and welfare of persons at work"
        })

      making_signals = Enum.filter(signals, &(&1.direction == :making))
      signal_names = Enum.map(making_signals, & &1.signal)
      assert "provision_securing" in signal_names
      assert "provision_for" in signal_names
    end

    test "detects 'to require' making language" do
      signals =
        Signals.tier4_description([], %{
          md_description: "Regulations to require employers to carry out risk assessments"
        })

      assert Enum.any?(signals, &(&1.signal == "to_require"))
    end

    test "detects 'to prohibit' making language" do
      signals =
        Signals.tier4_description([], %{
          md_description: "An Act to prohibit the use of asbestos"
        })

      assert Enum.any?(signals, &(&1.signal == "to_prohibit"))
    end

    test "detects not-making language in description" do
      signals =
        Signals.tier4_description([], %{
          md_description: "Regulations to amend the Health and Safety Regulations 2019"
        })

      not_making = Enum.filter(signals, &(&1.direction == :not_making))
      assert Enum.any?(not_making, &(&1.signal == "desc_to_amend"))
    end

    test "case insensitive matching" do
      signals =
        Signals.tier4_description([], %{
          md_description: "An Act TO MAKE PROVISION FOR SECURING the health"
        })

      assert Enum.any?(signals, &(&1.signal == "provision_securing"))
    end

    test "returns empty for nil description" do
      assert Signals.tier4_description([], %{md_description: nil}) == []
    end

    test "returns empty for empty description" do
      assert Signals.tier4_description([], %{md_description: ""}) == []
    end

    test "returns empty for missing description key" do
      assert Signals.tier4_description([], %{}) == []
    end

    test "truncates long value to 200 chars" do
      long_desc = String.duplicate("An Act to require ", 20)

      signals = Signals.tier4_description([], %{md_description: long_desc})

      signal = Enum.find(signals, &(&1.signal == "to_require"))
      assert String.length(to_string(signal.value)) <= 200
    end
  end
end
