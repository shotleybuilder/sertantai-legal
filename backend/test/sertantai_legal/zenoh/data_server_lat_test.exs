defmodule SertantaiLegal.Zenoh.DataServerLatTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.LatPersister
  alias SertantaiLegal.Zenoh.DataServer

  setup do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    law =
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

    row = %{
      section_id: "#{name}:reg.1",
      law_name: name,
      section_type: "article",
      part: nil,
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: "1",
      sub: nil,
      paragraph: nil,
      sub_paragraph: nil,
      extent_code: "S",
      sort_key: "00001~",
      position: 1,
      depth: 1,
      hierarchy_path: "reg.1",
      text: ". . . . ",
      status: "repealed",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }

    {:ok, _} = LatPersister.persist([row], name, law.id)
    %{name: name}
  end

  test "the LAT queryable serves each row's status (#167), JSON and Arrow", %{name: name} do
    assert {:ok, json} = DataServer.fetch_lat_by_law(name, :json)
    assert [%{"status" => "repealed"}] = Jason.decode!(json)

    assert {:ok, ipc} = DataServer.fetch_lat_by_law(name, :arrow)
    df = Explorer.DataFrame.load_ipc_stream!(ipc)
    assert [%{"status" => "repealed"}] = Explorer.DataFrame.to_rows(df)
  end
end
