defmodule SertantaiLegal.Legal.Taxa.MakingResolverTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Taxa.MakingResolver
  alias SertantaiLegal.Legal.Taxa.MakingResolver.{Decision, Evidence}

  defp evidence(attrs) do
    struct!(
      Evidence,
      Map.merge(
        %{
          review: nil,
          enrichment: nil,
          legacy_duty_types: nil,
          triage: nil,
          detector: nil,
          current: nil
        },
        Map.new(attrs)
      )
    )
  end

  describe "resolve/1 tier precedence" do
    test "human review beats every other tier" do
      decision =
        MakingResolver.resolve(
          evidence(review: "not_making", enrichment: "making", triage: "making")
        )

      assert %Decision{is_making: false, source: :review} = decision
      assert decision.dissent == [:enrichment, :triage]
    end

    test "enrichment beats triage (taxa wins by design, #120)" do
      decision = MakingResolver.resolve(evidence(enrichment: "making", triage: "not_making"))

      assert %Decision{is_making: true, source: :enrichment, dissent: [:triage]} = decision
    end

    test "enrichment empowering (Rights/Powers only) is not Making" do
      decision = MakingResolver.resolve(evidence(enrichment: "empowering", triage: "making"))

      assert %Decision{is_making: false, source: :enrichment} = decision
      assert decision.reason =~ "empowering"
    end

    test "enrichment no_obligations is not Making" do
      assert %Decision{is_making: false, source: :enrichment} =
               MakingResolver.resolve(evidence(enrichment: "no_obligations"))
    end

    test "enrichment overrides legacy duty types" do
      decision =
        MakingResolver.resolve(evidence(enrichment: "empowering", legacy_duty_types: ["Duty"]))

      assert %Decision{is_making: false, source: :enrichment, dissent: [:legacy_drrp]} = decision
    end

    test "legacy Duty or Responsibility beats triage" do
      decision =
        MakingResolver.resolve(
          evidence(legacy_duty_types: ["Responsibility", "Power"], triage: "not_making")
        )

      assert %Decision{is_making: true, source: :legacy_drrp, dissent: [:triage]} = decision
    end

    test "legacy Obligation counts as Making" do
      assert %Decision{is_making: true, source: :legacy_drrp} =
               MakingResolver.resolve(evidence(legacy_duty_types: ["Obligation"]))
    end

    test "legacy Rights/Powers only gives no verdict and defers to triage" do
      assert %Decision{is_making: true, source: :triage} =
               MakingResolver.resolve(
                 evidence(legacy_duty_types: ["Right", "Power"], triage: "making")
               )
    end

    test "triage beats detector" do
      decision = MakingResolver.resolve(evidence(triage: "not_making", detector: "making"))

      assert %Decision{is_making: false, source: :triage, dissent: [:detector]} = decision
    end

    test "detector decides when nothing higher has a verdict" do
      assert %Decision{is_making: true, source: :detector} =
               MakingResolver.resolve(evidence(detector: "making"))
    end
  end

  describe "resolve/1 uncertain and missing evidence" do
    test "uncertain triage gives no verdict and defers to the detector" do
      assert %Decision{is_making: false, source: :detector} =
               MakingResolver.resolve(evidence(triage: "uncertain", detector: "not_making"))
    end

    test "uncertain everywhere keeps the existing value" do
      decision =
        MakingResolver.resolve(
          evidence(triage: "uncertain", detector: "uncertain", current: true)
        )

      assert %Decision{is_making: true, source: :default} = decision
      assert decision.reason =~ "no verdict"
    end

    test "no evidence and never set defaults to false" do
      assert %Decision{is_making: false, source: :default, dissent: []} =
               MakingResolver.resolve(evidence([]))
    end

    test "empty legacy duty types give no verdict" do
      assert %Decision{source: :default} =
               MakingResolver.resolve(evidence(legacy_duty_types: []))
    end

    test "unknown verdict strings are ignored rather than guessed" do
      assert %Decision{is_making: true, source: :detector} =
               MakingResolver.resolve(evidence(review: "maybe", detector: "making"))
    end
  end

  describe "resolve/1 dissent" do
    test "lists only lower tiers whose verdict disagrees, in tier order" do
      decision =
        MakingResolver.resolve(
          evidence(
            enrichment: "making",
            legacy_duty_types: ["Duty"],
            triage: "not_making",
            detector: "not_making"
          )
        )

      assert decision.dissent == [:triage, :detector]
    end

    test "tiers without a verdict never dissent" do
      decision =
        MakingResolver.resolve(evidence(enrichment: "making", triage: "uncertain"))

      assert decision.dissent == []
    end
  end

  describe "resolve/1 reason" do
    test "names the deciding tier and its evidence" do
      assert MakingResolver.resolve(evidence(legacy_duty_types: ["Duty", "Power"])).reason ==
               "legacy_drrp: duty types Duty, Power"
    end
  end

  describe "enrichment_verdict/1" do
    test "Duty or Responsibility entries give making" do
      assert MakingResolver.enrichment_verdict(["Duty", "Right"]) == "making"
    end

    test "only Rights or Powers give empowering" do
      assert MakingResolver.enrichment_verdict(["Right", "Power"]) == "empowering"
    end

    test "no DRRP gives no_obligations" do
      assert MakingResolver.enrichment_verdict([]) == "no_obligations"
    end
  end
end
