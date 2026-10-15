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

    # LR-25: today's labels come from the timeline, not the row
    SertantaiLegal.Repo.query!(
      """
      INSERT INTO lat_label_timeline (law_name, section_id, valid_from, status, in_force_from, changed_by, code_version)
      VALUES ($1, $2, '2001-01-01', 'repealed', '2001-01-01', 'UK_ssi_2000_1', 'test')
      """,
      [name, row.section_id]
    )

    %{name: name}
  end

  test "the LAT queryable serves each row's status (#167), JSON and Arrow", %{name: name} do
    assert {:ok, json} = DataServer.fetch_lat_by_law(name, :json)
    assert [%{"status" => "repealed"}] = Jason.decode!(json)

    assert {:ok, ipc} = DataServer.fetch_lat_by_law(name, :arrow)
    df = Explorer.DataFrame.load_ipc_stream!(ipc)
    assert [%{"status" => "repealed"}] = Explorer.DataFrame.to_rows(df)
  end

  test "LAT rows serve today's effective_from / changed_by from the timeline (LR-25)", %{
    name: name
  } do
    {:ok, json} = DataServer.fetch_lat_by_law(name, :json)

    assert [%{"effective_from" => "2001-01-01", "changed_by" => "UK_ssi_2000_1"}] =
             Jason.decode!(json)

    {:ok, ipc} = DataServer.fetch_lat_by_law(name, :arrow)

    assert [%{"effective_from" => ~D[2001-01-01], "changed_by" => "UK_ssi_2000_1"}] =
             ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()
  end

  test "a row with no timeline period today serves nil labels (unknown, never a default)", %{
    name: name
  } do
    SertantaiLegal.Repo.query!("DELETE FROM lat_label_timeline WHERE law_name = $1", [name])
    {:ok, json} = DataServer.fetch_lat_by_law(name, :json)

    assert [%{"status" => nil, "effective_from" => nil, "changed_by" => nil}] =
             Jason.decode!(json)
  end

  test "notes serve as notes: text, placement, the law they point to and their id — no facts (LR-25)",
       %{name: name} do
    law_id =
      SertantaiLegal.Repo.query!("SELECT id FROM legal_register WHERE name = $1", [name]).rows
      |> hd()
      |> hd()

    SertantaiLegal.Repo.query!(
      """
      INSERT INTO amendment_annotations (id, country, law_name, law_id, code, code_type, source, text, affected_sections, changed_by, change_id, created_at, updated_at)
      VALUES ($1, 'uk', $2, $3, 'F1', 'amendment', 'test', $4, $5, 'UK_uksi_2021_5', 'c0ffee', now(), now())
      """,
      [
        "#{name}_F1",
        name,
        law_id,
        "Reg. 1 revoked (1.4.2021) by S.I. 2021/5 reg. 3",
        ["#{name}:reg.1"]
      ]
    )

    {:ok, json} = DataServer.fetch_amendments_by_law(name, :json)
    assert [note] = Jason.decode!(json)
    assert %{"changed_by" => "UK_uksi_2021_5", "change_id" => "c0ffee"} = note
    for k <- ~w(effect effective_dates effective_from), do: refute(Map.has_key?(note, k), k)

    {:ok, ipc} = DataServer.fetch_amendments_by_law(name, :arrow)

    assert [%{"change_id" => "c0ffee", "affected_sections" => [section]} = row] =
             ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()

    assert section == "#{name}:reg.1"
    refute Map.has_key?(row, "effective_dates")
  end
end
