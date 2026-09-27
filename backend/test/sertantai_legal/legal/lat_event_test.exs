defmodule SertantaiLegal.Legal.LatEventTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatHash, LatPersister}

  defp row(name, n, text \\ nil) do
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
      text: text || "Text #{n}.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
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

    %{name: name, law: law}
  end

  defp events(name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT event, row_count, lat_hash, reason, source, archive_ref FROM lat_events WHERE law_name = $1 ORDER BY id",
        [name]
      )

    Enum.map(rows, fn [e, n, h, r, s, a] ->
      %{event: e, row_count: n, lat_hash: h, reason: r, source: s, archive_ref: a}
    end)
  end

  defp register_hash(name) do
    %{rows: [[h]]} = Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [name])
    h
  end

  test "a parse records one parsed event with the final row count and hash", %{
    name: name,
    law: law
  } do
    {:ok, _} = LatPersister.persist(Enum.map(1..3, &row(name, &1)), name, law.id)

    assert [%{event: "parsed", row_count: 3, lat_hash: h, source: "lat_persister"}] = events(name)
    assert h == register_hash(name)
  end

  test "a law persisted in several insert batches still gets one parsed event", %{
    name: name,
    law: law
  } do
    {:ok, %{inserted: 1500}} =
      LatPersister.persist(Enum.map(1..1500, &row(name, &1)), name, law.id)

    assert [%{event: "parsed", row_count: 1500}] = events(name)
  end

  test "a re-parse is a new parsed event, not a discard", %{name: name, law: law} do
    {:ok, _} = LatPersister.persist(Enum.map(1..2, &row(name, &1)), name, law.id)
    {:ok, _} = LatPersister.persist(Enum.map(1..3, &row(name, &1)), name, law.id)

    assert Enum.map(events(name), & &1.event) == ["parsed", "parsed"]
    assert List.last(events(name)).row_count == 3
  end

  test "deleting a law's LAT with a reason records discarded with the pre-delete hash", %{
    name: name,
    law: law
  } do
    {:ok, _} = LatPersister.persist(Enum.map(1..2, &row(name, &1)), name, law.id)
    hash = register_hash(name)

    Repo.transaction(fn ->
      Repo.query!("SELECT set_config('sertantai.lat.reason', 'not_making', true)")
      Repo.query!("SELECT set_config('sertantai.lat.source', 'admin', true)")
      Repo.query!("SELECT set_config('sertantai.lat.archive_ref', '/nas/x.jsonl.gz', true)")
      Repo.query!("DELETE FROM lat WHERE law_name = $1", [name])
    end)

    assert [_, %{event: "discarded"} = d] = events(name)
    assert d.lat_hash == hash
    assert d.row_count == 2
    assert d.reason == "not_making"
    assert d.source == "admin"
    assert d.archive_ref == "/nas/x.jsonl.gz"
    assert register_hash(name) == LatHash.empty_hash()
  end

  test "an ad-hoc delete with no reason is still recorded, as unknown", %{name: name, law: law} do
    {:ok, _} = LatPersister.persist([row(name, 1)], name, law.id)
    Repo.query!("DELETE FROM legal_articles WHERE law_name = $1", [name])

    assert %{event: "discarded", reason: "unknown"} = List.last(events(name))
  end

  test "deleting some rows (the law keeps LAT) or enrichment updates record nothing", %{
    name: name,
    law: law
  } do
    {:ok, _} = LatPersister.persist(Enum.map(1..3, &row(name, &1)), name, law.id)
    Repo.query!("DELETE FROM legal_articles WHERE section_id = $1", ["#{name}:reg.2"])
    Repo.query!("UPDATE legal_articles SET duty_family = 'x' WHERE law_name = $1", [name])

    assert Enum.map(events(name), & &1.event) == ["parsed"]
  end
end
