defmodule SertantaiLegal.Scraper.LatPersisterTest do
  use SertantaiLegal.DataCase

  require Ash.Query

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatPersister

  defp row(law_name, n, extra \\ %{}) do
    Map.merge(
      %{
        section_id: "#{law_name}:reg.#{n}",
        law_name: law_name,
        section_type: "regulation",
        part: nil,
        chapter: nil,
        heading_group: nil,
        schedule: nil,
        provision: "#{n}",
        sub: nil,
        paragraph: nil,
        sub_paragraph: nil,
        extent_code: "S",
        sort_key: String.pad_leading("#{n}", 5, "0"),
        position: n,
        depth: 1,
        hierarchy_path: "reg.#{n}",
        text: "The occupier must keep a record.",
        amendment_count: nil,
        modification_count: nil,
        commencement_count: nil,
        extent_count: nil
      },
      extra
    )
  end

  test "persists LAT rows, including sub_provision, and refreshes the law's extent" do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    law =
      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test (Scotland) Regulations",
        type_code: "ssi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

    rows = [row(name, 1), row(name, 2, %{sub: "1"})]

    assert {:ok, %{inserted: 2, deleted: 0}} = LatPersister.persist(rows, name, law.id)

    %{rows: [[subs]]} =
      Repo.query!(
        "SELECT array_agg(sub_provision ORDER BY position) FROM legal_articles WHERE law_name = $1",
        [name]
      )

    assert subs == [nil, "1"]

    [refreshed] = LegalRegister |> Ash.Query.filter(name == ^name) |> Ash.read!()
    assert refreshed.geo_extent == "S"
    assert refreshed.geo_extent_source == "lat_provisions"
  end
end
