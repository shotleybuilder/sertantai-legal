defmodule SertantaiLegal.Scraper.ExtentBackfillRefreshTest do
  use SertantaiLegal.DataCase

  require Ash.Query

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.ExtentBackfill

  test "refresh/1 re-resolves one law's extent and logs the change" do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test (Scotland) Regulations",
      type_code: "ssi",
      year: 2099,
      number: "1",
      geo_extent: "UK",
      geo_region: ["England", "Wales", "Scotland", "Northern Ireland"]
    })
    |> Ash.create!()

    assert ExtentBackfill.refresh(name) == 1
    assert ExtentBackfill.refresh(name) == 0

    [law] = LegalRegister |> Ash.Query.filter(name == ^name) |> Ash.read!()
    assert law.geo_extent == "S"
    assert law.geo_region == ["Scotland"]
    assert law.geo_extent_source == "type_code"
    assert Enum.any?(law.record_change_log, &(&1["source"] == "extent"))
  end
end
