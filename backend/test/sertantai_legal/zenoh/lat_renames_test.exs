defmodule SertantaiLegal.Zenoh.LatRenamesTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Zenoh.LatRenames

  setup do
    law = "UK_ssi_2099_#{System.unique_integer([:positive])}"
    reparse = Ecto.UUID.generate()

    Repo.query!(
      """
      INSERT INTO lat_section_id_renames (law_name, old_section_id, new_section_id, status, match, reparse_id, created_at)
      VALUES ($1, $1 || ':reg.3', $1 || ':reg.2(4)', 'renamed', 'unique_text', $2, '2026-09-26T10:00:00Z'),
             ($1, $1 || ':reg.9', NULL, 'dropped', NULL, $2, '2026-09-26T12:00:00Z')
      """,
      [law, Ecto.UUID.dump!(reparse)]
    )

    %{law: law, reparse: reparse}
  end

  test "one law as JSON, oldest first", %{law: law, reparse: reparse} do
    assert {:ok, json} = LatRenames.fetch({:law, law}, :json, nil)

    assert [
             %{
               "old_section_id" => o1,
               "new_section_id" => n1,
               "status" => "renamed",
               "match" => "unique_text",
               "reparse_id" => ^reparse
             },
             %{"status" => "dropped", "new_section_id" => nil}
           ] = Jason.decode!(json)

    assert o1 == "#{law}:reg.3"
    assert n1 == "#{law}:reg.2(4)"
  end

  test "since filters on created_at (exclusive)", %{law: law} do
    {:ok, json} = LatRenames.fetch({:law, law}, :json, ~U[2026-09-26 10:00:00Z])
    assert [%{"status" => "dropped"}] = Jason.decode!(json)
  end

  test "all laws as Arrow", %{law: law} do
    assert {:ok, ipc} = LatRenames.fetch(:all, :arrow, nil)
    rows = ipc |> Explorer.DataFrame.load_ipc_stream!() |> Explorer.DataFrame.to_rows()
    assert Enum.count(rows, &(&1["law_name"] == law)) == 2
  end

  test "parse_since/1 reads since=<ISO-8601> from query parameters" do
    assert LatRenames.parse_since("format=json&since=2026-09-26T10:00:00Z") ==
             ~U[2026-09-26 10:00:00Z]

    assert LatRenames.parse_since("format=json") == nil
    assert LatRenames.parse_since(nil) == nil
    assert LatRenames.parse_since("since=garbage") == nil
  end
end
