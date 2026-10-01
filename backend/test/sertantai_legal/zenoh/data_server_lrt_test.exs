defmodule SertantaiLegal.Zenoh.DataServerLrtTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Zenoh.DataServer

  setup do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"
    url = "https://www.legislation.gov.uk/ssi/2099/1"

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test Regulations",
      type_code: "ssi",
      year: 2099,
      number: "1",
      source_url: url
    })
    |> Ash.create!()

    %{name: name, url: url}
  end

  # LegalRegister holds `source_url`; only the uk_lrt view aliases it as
  # leg_gov_uk_url. The JSON payload keeps the spec's key (ZENOH-SPEC LRT Record).
  test "JSON lrt record carries leg_gov_uk_url from source_url", %{name: name, url: url} do
    assert {:ok, json} = DataServer.fetch_lrt_by_name(name, :json)
    assert %{"name" => ^name, "leg_gov_uk_url" => ^url} = Jason.decode!(json)
  end

  test "Arrow lrt record carries source_url", %{name: name} do
    assert {:ok, ipc} = DataServer.fetch_lrt_by_name(name, :arrow)
    assert ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.n_rows() == 1
  end

  test "unknown law is not_found" do
    assert {:error, :not_found} = DataServer.fetch_lrt_by_name("UK_ssi_2099_0", :json)
  end
end
