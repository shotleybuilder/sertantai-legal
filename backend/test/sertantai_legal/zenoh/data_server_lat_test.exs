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

  test "LAT rows serve effective_from / changed_by; notes serve their parsed fields (#167 L8.2)",
       %{name: name} do
    law_id =
      SertantaiLegal.Repo.query!("SELECT id FROM legal_register WHERE name = $1", [name]).rows
      |> hd()
      |> hd()

    SertantaiLegal.Repo.query!(
      """
      INSERT INTO amendment_annotations (id, country, law_name, law_id, code, code_type, source, text, affected_sections, created_at, updated_at)
      VALUES ($1, 'uk', $2, $3, 'F1', 'amendment', 'test', $4, $5, now(), now())
      """,
      [
        "#{name}_F1",
        name,
        law_id,
        "Reg. 1 revoked (1.4.2021) by S.I. 2021/5 reg. 3",
        ["#{name}:reg.1"]
      ]
    )

    SertantaiLegal.Scraper.LatStatus.Apply.refresh(name)

    {:ok, json} = DataServer.fetch_lat_by_law(name, :json)

    assert [%{"effective_from" => "2021-04-01", "changed_by" => "UK_uksi_2021_5"}] =
             Jason.decode!(json)

    {:ok, ipc} = DataServer.fetch_lat_by_law(name, :arrow)

    assert [%{"effective_from" => ~D[2021-04-01], "changed_by" => "UK_uksi_2021_5"}] =
             ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()

    {:ok, json} = DataServer.fetch_amendments_by_law(name, :json)

    assert [
             %{
               "effect" => "repealed",
               "effective_dates" => ["2021-04-01"],
               "effective_from" => "2021-04-01",
               "changed_by" => "UK_uksi_2021_5",
               "change_id" => <<_::binary-size(32)>>
             }
           ] = Jason.decode!(json)

    {:ok, ipc} = DataServer.fetch_amendments_by_law(name, :arrow)

    assert [
             %{
               "effective_dates" => [~D[2021-04-01]],
               "change_id" => <<_::binary-size(32)>>,
               "affected_sections" => [section]
             }
           ] = ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()

    assert section == "#{name}:reg.1"
  end
end
