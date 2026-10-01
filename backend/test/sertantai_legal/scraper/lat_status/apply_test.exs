defmodule SertantaiLegal.Scraper.LatStatus.ApplyTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalArticle
  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatPersister
  alias SertantaiLegal.Scraper.LatStatus.Apply

  defp lat_row(law_name, n, text) do
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
      text: text,
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  defp law_with_lat(texts) do
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

    rows = texts |> Enum.with_index(1) |> Enum.map(fn {t, n} -> lat_row(name, n, t) end)
    {:ok, _} = LatPersister.persist(rows, name, law.id)
    {name, law.id}
  end

  defp note!(law_name, law_id, target, text, code_type) do
    Repo.query!(
      """
      INSERT INTO amendment_annotations (id, country, law_name, law_id, code, code_type, source, text, affected_sections, created_at, updated_at)
      VALUES ($1, 'uk', $2, $3, $4, $5, 'test', $6, $7, now(), now())
      """,
      [
        "#{law_name}_#{System.unique_integer([:positive])}",
        law_name,
        Ecto.UUID.dump!(law_id),
        "C1",
        code_type,
        text,
        ["#{law_name}:#{target}"]
      ]
    )
  end

  defp status(law_name, n), do: Ash.get!(LegalArticle, "#{law_name}:reg.#{n}").status

  test "refresh/1 sets status from text and notes, and only writes rows that change" do
    {name, id} = law_with_lat(["A duty.", ". . . . . ", "Another duty.", ". . . "])

    note!(
      name,
      id,
      "reg.3",
      "Reg. 3 in force at 1.1.2020 for specified purposes by S.I. 2019/1",
      "commencement"
    )

    note!(
      name,
      id,
      "reg.4",
      "Reg. 4 revoked (1.4.2021) by , (with transitional provisions and savings in reg. 9) S.I. 2021/5",
      "amendment"
    )

    Repo.query!("UPDATE legal_articles SET status = NULL WHERE law_name = $1", [name])

    assert %{law_name: ^name, rows: 4, changed: 4, transitions: transitions} = Apply.refresh(name)

    assert transitions == %{
             {nil, "in_force"} => 1,
             {nil, "repealed"} => 1,
             {nil, "in_force_partial"} => 1,
             {nil, "repealed_saved"} => 1
           }

    assert status(name, 1) == "in_force"
    assert status(name, 2) == "repealed"
    assert status(name, 3) == "in_force_partial"
    assert status(name, 4) == "repealed_saved"

    assert %{changed: 0} = Apply.refresh(name)
  end

  test "refresh/2 with dry_run: true writes nothing" do
    {name, _id} = law_with_lat([". . . . "])
    Repo.query!("UPDATE legal_articles SET status = NULL WHERE law_name = $1", [name])

    assert %{changed: 1} = Apply.refresh(name, dry_run: true)
    assert status(name, 1) == nil
  end

  test "LatPersister stores the parser's status through the lat view" do
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

    row = lat_row(name, 1, ". . . . ") |> Map.put(:status, "repealed")
    {:ok, _} = LatPersister.persist([row], name, law.id)

    assert status(name, 1) == "repealed"
  end
end
