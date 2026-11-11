defmodule SertantaiLegal.Scraper.Sources.HeldDbTest do
  @moduledoc """
  The register's facts `mix lat.sources` reads (Environmental Protection:
  Measures, the parked inline reads): each law's validity date and update
  time, and its change statistics.
  """
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.Sources.Held

  setup do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test Regulations",
      type_code: "ssi",
      year: 2099,
      number: "1",
      md_dct_valid_date: ~D[2024-05-01],
      amended_by_stats_affected_by_count: 12,
      amended_by_stats_affected_by_laws_count: 3
    })
    |> Ash.create!()

    %{name: name}
  end

  test "valid_dates: each law's validity date and update time", %{name: name} do
    assert %{^name => {~D[2024-05-01], %NaiveDateTime{}}} = Held.valid_dates([name, name])
    assert Held.valid_dates(["UK_ssi_2099_0"]) == %{}
  end

  test "register: the law's change statistics, nil for a law not held", %{name: name} do
    assert Held.register(name) == %{effects: 12, laws: 3}
    assert Held.register("UK_ssi_2099_0") == nil
  end
end
