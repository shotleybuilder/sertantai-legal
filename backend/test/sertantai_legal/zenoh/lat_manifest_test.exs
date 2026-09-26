defmodule SertantaiLegal.Zenoh.LatManifestTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.{LatHash, LatPersister}
  alias SertantaiLegal.Scraper.LatHash.Query
  alias SertantaiLegal.Zenoh.LatManifest

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
      text: "The occupier must keep a record.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }

    {:ok, _} = LatPersister.persist([row], name, law.id)
    %{name: name}
  end

  test "one law as JSON", %{name: name} do
    assert {:ok, json} = LatManifest.fetch({:law, name}, :json)

    assert %{"law_name" => ^name, "row_count" => 1, "lat_hash" => hash, "updated_at" => ts} =
             Jason.decode!(json)

    assert hash == Query.for_law(name).lat_hash
    assert is_binary(ts)
  end

  test "an unknown law as JSON: row_count 0, empty hash, updated_at null" do
    assert {:ok, json} = LatManifest.fetch({:law, "UK_ssi_2099_none"}, :json)

    assert Jason.decode!(json) == %{
             "law_name" => "UK_ssi_2099_none",
             "row_count" => 0,
             "lat_hash" => LatHash.empty_hash(),
             "updated_at" => nil
           }
  end

  test "all laws as one Arrow IPC batch", %{name: name} do
    assert {:ok, ipc} = LatManifest.fetch(:all, :arrow)
    df = Explorer.DataFrame.load_ipc_stream!(ipc)

    assert Explorer.DataFrame.names(df) |> Enum.sort() ==
             ~w(lat_hash law_name row_count updated_at)

    rows = Explorer.DataFrame.to_rows(df)
    assert %{"row_count" => 1, "lat_hash" => hash} = Enum.find(rows, &(&1["law_name"] == name))
    assert hash == Query.for_law(name).lat_hash
  end

  test "all laws as JSON", %{name: name} do
    assert {:ok, json} = LatManifest.fetch(:all, :json)
    assert Enum.any?(Jason.decode!(json), &(&1["law_name"] == name))
  end

  test "target/1 parses the key suffix" do
    assert LatManifest.target("*") == :all
    assert LatManifest.target("**") == :all
    assert LatManifest.target("UK_ssi_2016_88") == {:law, "UK_ssi_2016_88"}
  end
end
