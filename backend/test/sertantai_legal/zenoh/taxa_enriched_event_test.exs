defmodule SertantaiLegal.Zenoh.TaxaEnrichedEventTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.LatEvent.Provenance
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Zenoh.TaxaSubscriber

  describe "Provenance.entries/1 (pure)" do
    test "no provenance column: one entry with nothing asserted" do
      assert Provenance.entries(nil) == [
               %{
                 family: nil,
                 enrichment_run_id: nil,
                 enrichment_version: nil,
                 lat_hash: nil,
                 struct_hash: nil,
                 provenance: nil
               }
             ]
    end

    test "a JSON list of per-family entries (fractalaw's carrier) maps to one entry per family" do
      json =
        Jason.encode!([
          %{
            "family" => "taxa",
            "enrichment_run_id" => "run-1",
            "run_started_at" => "2026-10-01T09:00:00Z",
            "fractalaw_version" => "abc123",
            "enriched_against" => %{"lat_hash" => "h1", "struct_hash" => "s1"},
            "stages" => [%{"stage" => "reconcile", "method" => "reconciled"}],
            "provision_method_counts" => %{"slm" => 10, "regex" => 2}
          },
          %{
            "family" => "fitness",
            "enrichment_run_id" => "run-1",
            "fractalaw_version" => "abc123"
          }
        ])

      assert [taxa, fitness] = Provenance.entries(json)

      assert taxa.family == "taxa"
      assert taxa.enrichment_run_id == "run-1"
      assert taxa.enrichment_version == "abc123"
      assert {taxa.lat_hash, taxa.struct_hash} == {"h1", "s1"}

      assert taxa.provenance == %{
               "run_started_at" => "2026-10-01T09:00:00Z",
               "stages" => [%{"stage" => "reconcile", "method" => "reconciled"}],
               "provision_method_counts" => %{"slm" => 10, "regex" => 2}
             }

      assert fitness.family == "fitness"
      assert fitness.lat_hash == nil
    end

    test "unparseable provenance is kept raw rather than dropped" do
      assert [%{family: nil, provenance: %{"raw" => "not json"}}] = Provenance.entries("not json")
    end
  end

  describe "TaxaSubscriber records enriched events" do
    setup do
      name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test Regulations",
        type_code: "ssi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

      %{name: name}
    end

    defp ipc(cols) do
      cols |> Explorer.DataFrame.new() |> Explorer.DataFrame.dump_ipc_stream!()
    end

    defp enriched(name) do
      %{rows: rows} =
        Repo.query!(
          "SELECT family, verdict, source, enrichment_run_id, lat_hash FROM lat_events WHERE law_name = $1 AND event = 'enriched' ORDER BY id",
          [name]
        )

      rows
    end

    test "a publish without provenance records one enriched event with the verdict", %{name: name} do
      payload =
        ipc(%{
          duty_type: [["Duty"]],
          duties: [
            Jason.encode!([
              %{"holder" => "Org: Employer", "duty_type" => "Duty", "clause" => "must"}
            ])
          ]
        })

      assert :ok = TaxaSubscriber.handle_payload(name, payload)
      assert [[nil, verdict, "taxa_subscriber", nil, nil]] = enriched(name)
      assert verdict in ["making", "no_obligations", "empowering"]
    end

    test "a publish with a provenance list records one enriched event per family", %{name: name} do
      prov =
        Jason.encode!([
          %{
            "family" => "taxa",
            "enrichment_run_id" => "run-9",
            "enriched_against" => %{"lat_hash" => "h9"}
          },
          %{"family" => "significance", "enrichment_run_id" => "run-9"}
        ])

      payload = ipc(%{duty_type: [["Duty"]], provenance: [prov]})

      assert :ok = TaxaSubscriber.handle_payload(name, payload)

      assert [["taxa", _, "taxa_subscriber", "run-9", "h9"], ["significance", _, _, "run-9", nil]] =
               enriched(name)
    end

    test "an empty payload (housekeeping) records an enriched no_obligations event", %{name: name} do
      payload = ipc(%{x: []})

      assert :ok = TaxaSubscriber.handle_payload(name, payload)
      assert [[nil, "no_obligations", "taxa_subscriber", nil, nil]] = enriched(name)
    end
  end
end
