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

  describe "lat stats triggers (statement-level)" do
    defp create_law do
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

      {name, law}
    end

    defp stats(name) do
      %{rows: [[count, latest]]} =
        Repo.query!(
          "SELECT lat_count, latest_lat_updated_at FROM legal_register WHERE name = $1",
          [name]
        )

      {count, latest}
    end

    test "insert (via the lat view), update (via the parent) and delete keep lat_count and latest_lat_updated_at right" do
      {name, law} = create_law()

      {:ok, _} = LatPersister.persist(Enum.map(1..5, &row(name, &1)), name, law.id)
      assert {5, %DateTime{} = t1} = stats(name)

      Repo.query!(
        "UPDATE legal_articles SET updated_at = now() + interval '1 hour' WHERE law_name = $1 AND position = 1",
        [name]
      )

      assert {5, t2} = stats(name)
      assert DateTime.compare(t2, t1) == :gt

      Repo.query!("DELETE FROM legal_articles WHERE law_name = $1 AND position <= 2", [name])
      assert {3, _} = stats(name)

      {:ok, %{inserted: 2, deleted: 3}} =
        LatPersister.persist([row(name, 7), row(name, 8)], name, law.id)

      assert {2, _} = stats(name)
    end

    test "a large law persists in linear time (was O(n^2) with the per-row trigger)" do
      {name, law} = create_law()
      rows = Enum.map(1..6_000, &row(name, &1))

      {micros, result} = :timer.tc(fn -> LatPersister.persist(rows, name, law.id) end)

      assert {:ok, %{inserted: 6_000}} = result
      assert {6_000, _} = stats(name)
      assert micros < 10_000_000, "6,000-row persist took #{div(micros, 1000)}ms"
    end
  end
end
