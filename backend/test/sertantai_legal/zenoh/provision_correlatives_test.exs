defmodule SertantaiLegal.Zenoh.ProvisionCorrelativesTest do
  @moduledoc """
  Layer 1b correlatives on `actors[]` (fractalatai #72): stored as received,
  never feed DRRP, and checked for consistency with the actor's position.
  Examples from fractalaw DRRP-CLASSIFICATION.md layer 1b.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Zenoh.ProvisionSubscriber

  defp actor(label, position, drrp, correlatives, reason \\ "rule") do
    %{
      "label" => label,
      "position" => position,
      "drrp" => drrp,
      "reason" => reason,
      "correlatives" => correlatives
    }
  end

  defp hswa_2_1 do
    # HSWA s.2(1): the employer owes the duty to employees (counterparty)
    [
      actor("Org: Employer", "active", "Obligation", []),
      actor("Ind: Employee", "counterparty", "none", [
        %{"type" => "claim_right", "to" => "Org: Employer"}
      ])
    ]
  end

  defp hswa_3_1 do
    # HSWA s.3(1): persons not employed benefit (beneficiary)
    [
      actor("Org: Employer", "active", "Obligation", []),
      actor("Ind: Person", "beneficiary", "none", [
        %{"type" => "protected", "to" => "Org: Employer"}
      ])
    ]
  end

  defp water_82 do
    # Water Act s.82(2)(c): subject to the authority's power
    [
      actor("Gvt: Authority", "active", "Liberty", []),
      actor("Org: Owner", "counterparty", "none", [
        %{"type" => "liability", "to" => "Gvt: Authority"}
      ])
    ]
  end

  defp epa_20_7 do
    # EPA s.20(7): register open to the public — #67 inferred Liberty + claim_right
    [
      actor("Gvt: Authority", "active", "Obligation", []),
      actor(
        "Public",
        "active",
        "Liberty",
        [%{"type" => "claim_right", "to" => "Gvt: Authority"}],
        "inferred"
      )
    ]
  end

  describe "normalize_taxa/1" do
    test "correlatives pass through on actors and never feed drrp_types" do
      taxa =
        ProvisionSubscriber.normalize_taxa(%{
          "drrp_types" => ["Obligation"],
          "actors" => Jason.encode!(hswa_2_1())
        })

      assert taxa.drrp_types == ["Duty"]

      employee = Enum.find(taxa.actors, &(&1["label"] == "Ind: Employee"))
      assert employee["correlatives"] == [%{"type" => "claim_right", "to" => "Org: Employer"}]
    end

    test "the EPA s.20(7) claim_right leaves DRRP as Responsibility + Right" do
      taxa =
        ProvisionSubscriber.normalize_taxa(%{
          "drrp_types" => ["Obligation", "Liberty"],
          "actors" => epa_20_7()
        })

      assert Enum.sort(taxa.drrp_types) == ["Responsibility", "Right"]
    end
  end

  describe "correlative_violations/1" do
    test "the spec's worked examples are consistent" do
      for actors <- [hswa_2_1(), hswa_3_1(), water_82(), epa_20_7()] do
        assert ProvisionSubscriber.correlative_violations(actors) == []
      end
    end

    test "actors without correlatives (older payloads) are consistent" do
      assert ProvisionSubscriber.correlative_violations([
               %{"label" => "Org: Employer", "position" => "active", "drrp" => "Obligation"}
             ]) == []
    end

    test "an active actor not inferred by #67 holds no correlative" do
      actors = [
        actor("Org: Employer", "active", "Obligation", []),
        actor("Org: Contractor", "active", "Obligation", [
          %{"type" => "claim_right", "to" => "Org: Employer"}
        ])
      ]

      assert [%{"label" => "Org: Contractor"}] =
               ProvisionSubscriber.correlative_violations(actors)
    end

    test "a #67-inferred active actor holds only a claim_right" do
      actors = [
        actor("Gvt: Authority", "active", "Obligation", []),
        actor(
          "Public",
          "active",
          "Liberty",
          [%{"type" => "liability", "to" => "Gvt: Authority"}],
          "inferred"
        )
      ]

      assert [%{"label" => "Public"}] = ProvisionSubscriber.correlative_violations(actors)
    end

    test "act (fractalatai#75) is valid on a claim_right from the fixed list, or absent" do
      actors = [
        actor("Org: Operator", "active", "Obligation", []),
        actor("Gvt: Authority", "counterparty", "none", [
          %{"type" => "claim_right", "to" => "Org: Operator", "act" => "notify"}
        ]),
        actor("Ind: Employee", "counterparty", "none", [
          %{"type" => "claim_right", "to" => "Org: Operator"}
        ])
      ]

      assert ProvisionSubscriber.correlative_violations(actors) == []
    end

    test "act off a claim_right, or outside the fixed list, is a violation" do
      actors = [
        actor("Gvt: Authority", "active", "Liberty", []),
        actor("Org: Owner", "counterparty", "none", [
          %{"type" => "liability", "to" => "Gvt: Authority", "act" => "serve"}
        ]),
        actor("Org: Operator", "active", "Obligation", []),
        actor("Gvt: Regulator", "counterparty", "none", [
          %{"type" => "claim_right", "to" => "Org: Operator", "act" => "telephone"}
        ])
      ]

      assert actors |> ProvisionSubscriber.correlative_violations() |> Enum.map(& &1["label"]) ==
               ["Org: Owner", "Gvt: Regulator"]
    end

    test "correlative types must match the position" do
      actors = [
        actor("Org: Employer", "active", "Obligation", []),
        actor("Ind: Person", "beneficiary", "none", [
          %{"type" => "claim_right", "to" => "Org: Employer"}
        ]),
        actor("Ind: Employee", "counterparty", "none", [
          %{"type" => "protected", "to" => "Org: Employer"}
        ]),
        actor("Gvt: Minister", "mentioned", "none", [
          %{"type" => "liability", "to" => "Org: Employer"}
        ])
      ]

      assert actors |> ProvisionSubscriber.correlative_violations() |> Enum.map(& &1["label"]) ==
               ["Ind: Person", "Ind: Employee", "Gvt: Minister"]
    end
  end
end
