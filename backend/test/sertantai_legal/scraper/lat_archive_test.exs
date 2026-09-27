defmodule SertantaiLegal.Scraper.LatArchiveTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatArchive, LatPersister}

  defp row(name, n) do
    %{
      section_id: "#{name}:reg.#{n}",
      law_name: name,
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
      sort_key: "000." <> String.pad_leading("#{n}", 6, "0") <> "~",
      position: n,
      depth: 1,
      hierarchy_path: "reg.#{n}",
      text: "Text #{n}.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  setup do
    dir = Path.join(System.tmp_dir!(), "lat-archive-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)
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

    {:ok, _} = LatPersister.persist([row(name, 1), row(name, 2)], name, law.id)

    Repo.query!("UPDATE legal_articles SET drrp_types = '{Duty}' WHERE law_name = $1", [name])
    %{dir: dir, name: name}
  end

  defp lat_count(name) do
    %{rows: [[n]]} = Repo.query!("SELECT count(*) FROM lat WHERE law_name = $1", [name])
    n
  end

  test "archive/2 writes every row (all columns) as gzipped JSON lines, named by lat_hash", %{
    dir: dir,
    name: name
  } do
    %{rows: [[hash]]} = Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [name])

    assert {:ok, path} = LatArchive.archive(name, dir: dir)
    assert path == Path.join([dir, name, hash <> ".jsonl.gz"])

    rows =
      path
      |> File.read!()
      |> :zlib.gunzip()
      |> String.split("\n", trim: true)
      |> Enum.map(&Jason.decode!/1)

    assert Enum.map(rows, & &1["section_id"]) == ["#{name}:reg.1", "#{name}:reg.2"]
    assert hd(rows)["drrp_types"] == ["Duty"]
  end

  test "discard/3 archives, deletes, and records a discarded event with the archive ref", %{
    dir: dir,
    name: name
  } do
    assert {:ok, %{deleted: 2, archive_ref: ref}} =
             LatArchive.discard(name, "not_making", dir: dir, actor: "user:jason")

    assert File.exists?(ref)
    assert lat_count(name) == 0

    %{rows: [[event, reason, archive_ref, actor, n]]} =
      Repo.query!(
        "SELECT event, reason, archive_ref, actor, row_count FROM lat_events WHERE law_name = $1 AND event = 'discarded'",
        [name]
      )

    assert {event, reason, archive_ref, actor, n} ==
             {"discarded", "not_making", ref, "user:jason", 2}
  end

  test "discard/3 refuses when the archive cannot be written, unless archive: false", %{
    name: name
  } do
    assert {:error, reason} = LatArchive.discard(name, "not_making", dir: "/proc/nope")
    assert reason =~ "archive"
    assert lat_count(name) == 2

    assert {:ok, %{deleted: 2, archive_ref: nil}} =
             LatArchive.discard(name, "revoked", dir: "/proc/nope", archive: false)
  end
end
