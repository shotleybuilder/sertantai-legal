defmodule SertantaiLegal.Zenoh.LatChangesTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatPersister
  alias SertantaiLegal.Zenoh.LatChanges

  setup do
    name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

    law =
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
      text: "A duty.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }

    {:ok, %{op_id: op_id}} = LatPersister.persist([row], name, law.id)

    Repo.query!(
      "UPDATE lat_events SET cause = 'legislative', source_hash = 'h1' WHERE op_key = $1",
      [op_id]
    )

    Repo.query!(
      """
      INSERT INTO lat_changes (law_name, op_key, section_id, change, cause, change_ids, created_at)
      VALUES ($1, $2, $3, 'text_changed', 'legislative', ARRAY['abc'], '2026-10-01T10:00:00Z')
      """,
      [name, op_id, "#{name}:reg.1"]
    )

    %{name: name, op_id: op_id}
  end

  test "one law as JSON, with the parse's op_cause and source_hash", %{name: name, op_id: op_id} do
    assert {:ok, json} = LatChanges.fetch({:law, name}, :json, nil)

    assert [
             %{
               "id" => id,
               "op_key" => ^op_id,
               "change" => "text_changed",
               "cause" => "legislative",
               "change_ids" => ["abc"],
               "op_cause" => "legislative",
               "source_hash" => "h1"
             }
           ] = Jason.decode!(json)

    # the entry's stable id: fractalaw keys provision_versions on it (#167 L9/D5)
    assert is_integer(id)
  end

  test "Arrow, and since filters by created_at", %{name: name} do
    assert {:ok, ipc} = LatChanges.fetch({:law, name}, :arrow, nil)

    assert [%{"id" => id, "change_ids" => ["abc"], "cause" => "legislative"}] =
             ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()

    assert is_integer(id)

    {:ok, later, 0} = DateTime.from_iso8601("2026-10-01T11:00:00Z")
    assert {:ok, "[]"} = LatChanges.fetch({:law, name}, :json, later)
  end

  test "target/1 and parse_since/1" do
    assert LatChanges.target("*") == :all
    assert LatChanges.target("UK_x") == {:law, "UK_x"}
    assert %DateTime{} = LatChanges.parse_since("since=2026-10-01T00:00:00Z")
  end

  test "parse_since/1 accepts Zenoh ';' as well as '&' between parameters" do
    expected = ~U[2026-10-01 00:00:00Z]
    assert LatChanges.parse_since("since=2026-10-01T00:00:00Z;format=json") == expected
    assert LatChanges.parse_since("format=json;since=2026-10-01T00:00:00Z") == expected
    assert LatChanges.parse_since("since=2026-10-01T00:00:00Z&format=json") == expected
    assert LatChanges.parse_since("format=json") == nil
  end
end
