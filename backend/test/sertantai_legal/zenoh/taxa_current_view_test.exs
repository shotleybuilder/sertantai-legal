defmodule SertantaiLegal.Zenoh.TaxaCurrentViewTest do
  @moduledoc "fractalaw #73 R1a current view + #72 correlative holder lists on the law payload."
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Zenoh.TaxaSubscriber

  require Ash.Query

  describe "normalize_taxa/1" do
    test "current holder lists get the holder-class filter; correlative lists keep both classes" do
      t =
        TaxaSubscriber.normalize_taxa(%{
          "current_verdict" => "making",
          "current_duty_type" => ["Duty", "Responsibility"],
          "current_duty_holder" => ["Org: Employer", "Gvt: Minister"],
          "current_rights_holder" => [],
          "current_responsibility_holder" => ["Gvt: Minister", "Org: Employer"],
          "current_power_holder" => [],
          "claim_holder" => ["Ind: Employee", "Gvt: Agency: Health and Safety Executive"],
          "liability_holder" => ["Org: Company"],
          "protected_holder" => ["Ind: Person"]
        })

      assert t.current_verdict == "making"
      assert t.current_duty_type == %{values: ["Duty", "Responsibility"]}
      assert t.current_duty_holder == %{values: ["Org: Employer"]}
      assert t.current_responsibility_holder == %{values: ["Gvt: Minister"]}
      # [] is kept: it clears a stale list (#68 never-NULL contract)
      assert t.current_rights_holder == %{values: []}
      assert t.current_power_holder == %{values: []}
      # correlatives: both classes, unfiltered (layer 1b)
      assert t.claim_holder == %{
               values: ["Ind: Employee", "Gvt: Agency: Health and Safety Executive"]
             }

      assert t.liability_holder == %{values: ["Org: Company"]}
      assert t.protected_holder == %{values: ["Ind: Person"]}
    end

    test "an unknown current_verdict is dropped, not stored" do
      refute Map.has_key?(
               TaxaSubscriber.normalize_taxa(%{"current_verdict" => "maybe"}),
               :current_verdict
             )

      assert TaxaSubscriber.normalize_taxa(%{"current_verdict" => "revoked"}).current_verdict ==
               "revoked"
    end

    test "absent (NULL) fields stay absent: not in this payload" do
      t = TaxaSubscriber.normalize_taxa(%{"duty_holder" => ["Org: Employer"]})
      refute Map.has_key?(t, :current_verdict)
      refute Map.has_key?(t, :current_duty_holder)
      refute Map.has_key?(t, :claim_holder)
    end
  end

  describe "is_making stays as made" do
    test "current_verdict never changes the enrichment verdict" do
      record = %{duties: nil, rights: nil, responsibilities: nil, powers: nil}

      taxa =
        TaxaSubscriber.normalize_taxa(%{
          "duty_type" => ["Duty"],
          "duty_holder" => ["Org: Employer"],
          "current_verdict" => "revoked",
          "current_duty_type" => [],
          "current_duty_holder" => []
        })

      assert TaxaSubscriber.classify_enrichment(record, taxa).making_enrichment_verdict ==
               "making"
    end
  end

  describe "end to end (Arrow payload → legal_register)" do
    setup do
      name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test Regulations",
        type_code: "uksi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

      %{name: name}
    end

    test "the nine fields persist; the as-made fields and is_making are untouched", %{name: name} do
      ipc =
        %{
          duty_type: [["Duty"]],
          duty_holder: [["Org: Employer"]],
          current_verdict: ["revoked"],
          current_duty_type: [[]],
          current_duty_holder: [[]],
          current_rights_holder: [[]],
          current_responsibility_holder: [[]],
          current_power_holder: [[]],
          claim_holder: [["Ind: Employee"]],
          liability_holder: [[]],
          protected_holder: [["Ind: Person"]]
        }
        |> Explorer.DataFrame.new(
          dtypes: [
            current_duty_type: {:list, :string},
            current_duty_holder: {:list, :string},
            current_rights_holder: {:list, :string},
            current_responsibility_holder: {:list, :string},
            current_power_holder: {:list, :string},
            liability_holder: {:list, :string}
          ]
        )
        |> Explorer.DataFrame.dump_ipc_stream!()

      assert :ok = TaxaSubscriber.handle_payload(name, ipc)

      law =
        LegalRegister
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(name == ^name)
        |> Ash.read_one!()

      assert law.current_verdict == "revoked"
      assert law.current_duty_holder == %{"values" => []}
      assert law.claim_holder == %{"values" => ["Ind: Employee"]}
      assert law.protected_holder == %{"values" => ["Ind: Person"]}
      # as made: unchanged by the current view
      assert law.duty_holder == %{"values" => ["Org: Employer"]}
      assert law.making_enrichment_verdict == "making"
      assert law.is_making == true
    end
  end
end
