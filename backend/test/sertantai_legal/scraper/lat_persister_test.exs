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

  test "refuses an empty row list, so an empty parse never wipes a law's LAT" do
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

    {:ok, _} = LatPersister.persist([row(name, 1)], name, law.id)

    assert {:error, reason} = LatPersister.persist([], name, law.id)
    assert reason =~ "no LAT rows"

    %{rows: [[n]]} = Repo.query!("SELECT count(*) FROM lat WHERE law_name = $1", [name])
    assert n == 1
  end

  describe "re-parse merge keeps enrichment" do
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

      rows = for n <- 1..3, do: row(name, n, %{text: "Text #{n}."})
      {:ok, _} = LatPersister.persist(rows, name, law.id)

      Repo.query!(
        """
        UPDATE legal_articles
        SET drrp_types = '{Duty}', duty_family = 'Records', taxa_enriched_at = now()
        WHERE law_name = $1
        """,
        [name]
      )

      %{name: name, law: law, rows: rows}
    end

    defp enrichment(name) do
      %{rows: rows} =
        Repo.query!(
          "SELECT section_id, drrp_types, duty_family FROM legal_articles WHERE law_name = $1 ORDER BY section_id",
          [name]
        )

      Map.new(rows, fn [id, drrp, fam] -> {String.replace(id, name <> ":", ""), {drrp, fam}} end)
    end

    defp renames(name) do
      %{rows: rows} =
        Repo.query!(
          "SELECT old_section_id, new_section_id, status, match FROM lat_section_id_renames WHERE law_name = $1 ORDER BY old_section_id",
          [name]
        )

      rows
    end

    test "an unchanged re-parse keeps every row's enrichment", %{name: name, law: law, rows: rows} do
      assert {:ok, %{inserted: 3, deleted: 3, carried: 3, renamed: 0}} =
               LatPersister.persist(rows, name, law.id)

      assert enrichment(name) |> Map.values() |> Enum.uniq() == [{["Duty"], "Records"}]
      assert renames(name) == []
    end

    test "a renamed id carries enrichment, migrates control_mappings and is logged", %{
      name: name,
      law: law
    } do
      %{rows: [[control_id]]} =
        Repo.query!(
          "INSERT INTO controls (law_name, control_id) VALUES ($1, 'C1') RETURNING id",
          [name]
        )

      Repo.query!(
        "INSERT INTO control_mappings (control_id, law_name, section_id) VALUES ($1, $2, $3)",
        [control_id, name, "#{name}:reg.3"]
      )

      new_rows = [
        row(name, 1, %{text: "Text 1."}),
        row(name, 2, %{text: "Text 2."}),
        row(name, 3, %{text: "Text 3.", section_id: "#{name}:reg.2(4)"})
      ]

      assert {:ok, %{carried: 3, renamed: 1}} = LatPersister.persist(new_rows, name, law.id)

      assert enrichment(name)["reg.2(4)"] == {["Duty"], "Records"}
      assert [["#{name}:reg.3", "#{name}:reg.2(4)", "renamed", "unique_text"]] == renames(name)

      %{rows: [[mapped]]} =
        Repo.query!("SELECT section_id FROM control_mappings WHERE control_id = $1", [control_id])

      assert mapped == "#{name}:reg.2(4)"
    end

    test "changed text blanks that row only; a vanished row is logged as dropped", %{
      name: name,
      law: law
    } do
      new_rows = [row(name, 1, %{text: "Text 1."}), row(name, 2, %{text: "Changed."})]

      assert {:ok, %{carried: 1, changed: 1, dropped: 1}} =
               LatPersister.persist(new_rows, name, law.id)

      assert enrichment(name) == %{"reg.1" => {["Duty"], "Records"}, "reg.2" => {nil, nil}}
      assert [["#{name}:reg.3", nil, "dropped", nil]] == renames(name)
    end

    test "the gate refuses to lose enrichment on unchanged text, keeping the old LAT", %{
      name: name,
      law: law
    } do
      Repo.query!("UPDATE legal_articles SET text = 'Dup.' WHERE law_name = $1", [name])

      new_rows =
        for n <- 1..2, do: row(name, n + 10, %{text: "Dup.", section_id: "#{name}:x.#{n}"})

      assert {:error, reason} = LatPersister.persist(new_rows, name, law.id)
      assert reason =~ "gate"
      assert map_size(enrichment(name)) == 3

      assert {:ok, %{carried: 0, ambiguous: 3}} =
               LatPersister.persist(new_rows, name, law.id, force: true)

      assert renames(name) |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq() == ["ambiguous"]
    end
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
