defmodule SertantaiLegal.Scraper.LatHashQueryTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatHash, LatPersister}
  alias SertantaiLegal.Scraper.LatHash.Query

  defp row(law_name, n, text, extra \\ %{}) do
    Map.merge(
      %{
        section_id: "#{law_name}:reg.#{n}",
        law_name: law_name,
        section_type: "article",
        part: nil,
        chapter: nil,
        heading_group: nil,
        schedule: nil,
        provision: "#{n}",
        sub: nil,
        paragraph: nil,
        sub_paragraph: nil,
        extent_code: "S",
        sort_key: String.pad_leading("#{n}", 5, "0") <> "~",
        position: n,
        depth: 1,
        hierarchy_path: "reg.#{n}",
        text: text,
        amendment_count: nil,
        modification_count: nil,
        commencement_count: nil,
        extent_count: nil
      },
      extra
    )
  end

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

    rows = [
      row(name, 1, "  A person  must   not\tdeploy.​ "),
      row(name, 2, "Caf" <> "é licence holder here"),
      row(name, 3, nil, %{section_type: "part", section_id: "#{name}:pt.1"}),
      row(name, 10, "Ten.")
    ]

    {:ok, _} = LatPersister.persist(rows, name, law.id)
    %{name: name, rows: rows}
  end

  test "SQL hash equals the pure reference implementation, over every served row", %{
    name: name,
    rows: rows
  } do
    served = Repo.all(Query.served_query(name))

    assert %{law_name: ^name, row_count: 4, lat_hash: hash, updated_at: %DateTime{}} =
             Query.for_law(name)

    assert length(served) == 4
    assert hash == LatHash.hash(served)
    assert hash == LatHash.hash(rows)
  end

  test "a law with no LAT has row_count 0 and the empty hash" do
    assert Query.for_law("UK_ssi_2099_none") == %{
             law_name: "UK_ssi_2099_none",
             row_count: 0,
             lat_hash: LatHash.empty_hash(),
             updated_at: nil
           }
  end

  test "all/0 lists every law with LAT, matching for_law/1", %{name: name} do
    assert Enum.find(Query.all(), &(&1.law_name == name)) == Query.for_law(name)
  end

  describe "stored lat_hash (trigger-maintained on legal_register)" do
    defp stored(name) do
      %{rows: [[hash, count]]} =
        Repo.query!("SELECT lat_hash, lat_count FROM legal_register WHERE name = $1", [name])

      {hash, count}
    end

    defp served_hash(name), do: name |> Query.served_query() |> Repo.all() |> LatHash.hash()

    test "is set on persist and equals the SQL definition", %{name: name} do
      assert {hash, 4} = stored(name)
      assert hash == served_hash(name)
      assert hash == Query.computed_hash(name)
    end

    test "follows a raw-SQL text edit and a section_id rename (paths that emit no event)", %{
      name: name
    } do
      before = elem(stored(name), 0)

      Repo.query!("UPDATE legal_articles SET text = 'Changed.' WHERE section_id = $1", [
        "#{name}:reg.10"
      ])

      after_text = elem(stored(name), 0)
      refute after_text == before
      assert after_text == served_hash(name)

      Repo.query!("UPDATE legal_articles SET section_id = $1 WHERE section_id = $2", [
        "#{name}:reg.11",
        "#{name}:reg.10"
      ])

      assert elem(stored(name), 0) == served_hash(name)
      refute elem(stored(name), 0) == after_text
    end

    test "follows a sort_key-only change", %{name: name} do
      before = elem(stored(name), 0)

      Repo.query!("UPDATE legal_articles SET sort_key = 'zzz' WHERE section_id = $1", [
        "#{name}:reg.1"
      ])

      refute elem(stored(name), 0) == before
      assert elem(stored(name), 0) == served_hash(name)
    end

    test "an enrichment-only update leaves it unchanged", %{name: name} do
      before = stored(name)

      Repo.query!("UPDATE legal_articles SET duty_family = 'x' WHERE law_name = $1", [name])

      assert stored(name) == before
    end

    test "deleting all rows leaves the empty hash", %{name: name} do
      Repo.query!("DELETE FROM legal_articles WHERE law_name = $1", [name])
      assert stored(name) == {LatHash.empty_hash(), 0}
      assert Query.for_law(name).lat_hash == LatHash.empty_hash()
      refute Enum.any?(Query.all(), &(&1.law_name == name))
    end
  end

  test "event_metadata/1 carries row_count and lat_hash", %{name: name} do
    %{lat_hash: hash} = Query.for_law(name)
    assert Query.event_metadata(name) == %{row_count: 4, lat_hash: hash}
  end
end
