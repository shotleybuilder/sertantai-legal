defmodule SertantaiLegal.Legal.MakingRecordTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Making

  defp create_law(attrs) do
    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          country: "uk",
          name: "UK_uksi_2099_#{System.unique_integer([:positive])}",
          title_en: "Test Regulations",
          type_code: "uksi",
          year: 2099,
          number: "1"
        },
        attrs
      )
    )
    |> Ash.create!()
  end

  describe "record/3" do
    test "persists the resolved decision, provenance and a making change-log entry" do
      law = create_law(%{is_making: false, duty_type: %{values: ["Duty"]}})

      {:ok, updated} =
        Making.record(
          law,
          %{making_classification: "not_making", making_classification_source: "triage"},
          "triage_subscriber"
        )

      assert updated.is_making == true
      assert updated.is_making_source == "legacy_drrp"
      assert updated.is_making_decided_at
      assert updated.making_classification == "not_making"

      assert [entry] = Enum.filter(updated.record_change_log, &(&1["source"] == "making"))
      assert entry["changed_by"] == "triage_subscriber"
      assert entry["dissent"] == ["triage", "legacy_is_making"]
    end

    test "records an enrichment verdict that overrides triage" do
      law =
        create_law(%{
          is_making: true,
          making_classification: "making",
          making_classification_source: "triage"
        })

      {:ok, updated} =
        Making.record(law, %{making_enrichment_verdict: "empowering"}, "taxa_subscriber")

      assert updated.is_making == false
      assert updated.is_making_source == "enrichment"
      assert updated.making_enrichment_verdict == "empowering"
    end
  end
end
