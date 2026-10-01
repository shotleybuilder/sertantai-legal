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
             "struct_hash" => LatHash.empty_hash(),
             "updated_at" => nil,
             "coverage" => "full",
             "scope" => nil,
             "status_hash" => LatHash.empty_hash(),
             "cause" => nil,
             "source_hash" => nil,
             "amended" => false,
             "as_of" => nil,
             "effects_unapplied" => "[]"
           }
  end

  test "all laws as one Arrow IPC batch", %{name: name} do
    assert {:ok, ipc} = LatManifest.fetch(:all, :arrow)
    df = Explorer.DataFrame.load_ipc_stream!(ipc)

    assert Explorer.DataFrame.names(df) |> Enum.sort() ==
             ~w(amended as_of cause coverage effects_unapplied lat_hash law_name row_count scope source_hash status_hash struct_hash updated_at)

    rows = Explorer.DataFrame.to_rows(df)
    assert %{"row_count" => 1, "lat_hash" => hash} = Enum.find(rows, &(&1["law_name"] == name))
    assert hash == Query.for_law(name).lat_hash
  end

  test "status_hash: the SQL aggregate equals LatHash.status_hash/1 (#167)", %{name: name} do
    rows =
      SertantaiLegal.Repo.query!("SELECT section_id, status FROM lat WHERE law_name = $1", [name]).rows
      |> Enum.map(fn [sid, status] -> %{section_id: sid, status: status} end)

    SertantaiLegal.Repo.query!(
      "UPDATE legal_articles SET status = 'in_force' WHERE law_name = $1",
      [name]
    )

    rows = Enum.map(rows, &%{&1 | status: "in_force"})

    assert Query.for_law(name).status_hash == LatHash.status_hash(rows)
    assert Enum.find(Query.all(), &(&1.law_name == name)).status_hash == LatHash.status_hash(rows)

    SertantaiLegal.Repo.query!("UPDATE legal_articles SET status = NULL WHERE law_name = $1", [
      name
    ])

    assert Query.for_law(name).status_hash == nil
  end

  test "cause and source_hash of the law's latest parse (#167 L8.3)", %{name: name} do
    assert %{cause: nil, source_hash: nil} = Query.for_law(name)

    SertantaiLegal.Repo.query!(
      "UPDATE lat_events SET cause = 'initial', source_hash = 'abc' WHERE law_name = $1 AND event = 'parsed'",
      [name]
    )

    assert %{cause: "initial", source_hash: "abc"} = Query.for_law(name)
    assert %{cause: "initial"} = Enum.find(Query.all(), &(&1.law_name == name))
  end

  test "amended, as_of and effects_unapplied (#167 L8.4)", %{name: name} do
    assert %{amended: false, as_of: nil, effects_unapplied: "[]"} = Query.for_law(name)

    law_id =
      SertantaiLegal.Repo.query!("SELECT id FROM legal_register WHERE name = $1", [name]).rows
      |> hd()
      |> hd()

    SertantaiLegal.Repo.query!(
      """
      INSERT INTO amendment_annotations (id, country, law_name, law_id, code, code_type, source, text, affected_sections, created_at, updated_at)
      VALUES ($1, 'uk', $2, $3, 'F1', 'amendment', 'test', 'Reg. 1 substituted (1.4.2021) by S.I. 2021/5', $4, now(), now())
      """,
      ["#{name}_F1", name, law_id, ["#{name}:reg.1"]]
    )

    stats = %{
      "UK_ssi_2099_9" => %{
        "details" => [
          %{"affect" => "inserted", "target" => "reg. 1(5)", "applied" => "Not yet"},
          %{"affect" => "words substituted", "target" => "reg. 1", "applied" => "Yes"}
        ]
      }
    }

    SertantaiLegal.Repo.query!(
      ~s|UPDATE legal_register SET md_dct_valid_date = '2023-05-01', "🔻_affected_by_stats_per_law" = $2 WHERE name = $1|,
      [name, stats]
    )

    assert %{amended: true, as_of: ~D[2023-05-01], effects_unapplied: json} = Query.for_law(name)

    assert Jason.decode!(json) == [
             %{
               "by" => "UK_ssi_2099_9",
               "affect" => "inserted",
               "target" => "reg. 1(5)",
               "section_id" => "#{name}:reg.1",
               "exact" => false,
               # #168 in-force data: null until the law's feed is re-fetched
               "in_force_date" => nil,
               "prospective" => nil,
               "saved" => nil
             }
           ]

    assert Enum.find(Query.all(), &(&1.law_name == name)).effects_unapplied == json

    SertantaiLegal.Repo.query!(
      "UPDATE lat_events SET source_valid_date = '2025-02-01' WHERE law_name = $1 AND event = 'parsed'",
      [name]
    )

    assert %{as_of: ~D[2025-02-01]} = Query.for_law(name)
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
