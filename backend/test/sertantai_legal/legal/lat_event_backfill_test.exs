defmodule SertantaiLegal.Legal.LatEventBackfillTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LatEvent.Backfill
  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatPersister

  defp law(attrs \\ %{}) do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{country: "uk", name: name, title_en: "T", type_code: "ssi", year: 2099, number: "1"},
        attrs
      )
    )
    |> Ash.create!()
  end

  defp session_record(law_name, status, lat_inserted, inserted_at, updated_at) do
    sid = "lat-parse-test-#{System.unique_integer([:positive])}"

    Repo.query!(
      "INSERT INTO scrape_sessions (session_id, year, month, day_from, day_to, session_type) VALUES ($1, 2026, 9, 1, 1, 'lat_parse')",
      [sid]
    )

    Repo.query!(
      ~s|INSERT INTO scrape_session_records (session_id, law_name, "group", status, lat_inserted, inserted_at, updated_at) VALUES ($1, $2, '1', $3, $4, $5, $6)|,
      [sid, law_name, status, lat_inserted, inserted_at, updated_at]
    )

    sid
  end

  defp events(name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT event, reason, verdict, split_part(source, ':', 1), row_count FROM lat_events WHERE law_name = $1 ORDER BY at, id",
        [name]
      )

    rows
  end

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
      extent_code: nil,
      sort_key: "000." <> String.pad_leading("#{n}", 6, "0") <> "~",
      position: n,
      depth: 1,
      hierarchy_path: nil,
      text: "T#{n}.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  test "a cleaned session: parsed at record creation, discarded (not_making) when cleaned" do
    l = law()
    session_record(l.name, "cleaned", 12, ~N[2026-08-01 10:00:00], ~N[2026-08-02 10:00:00])

    Backfill.run()

    assert events(l.name) == [
             ["parsed", nil, nil, "backfill_lat_session", 12],
             ["discarded", "not_making", nil, "backfill_lat_session", nil]
           ]
  end

  test "parsed with rows but LAT now gone and never cleaned: an inferred unknown discard" do
    l = law()
    session_record(l.name, "confirmed", 5, ~N[2026-08-01 10:00:00], ~N[2026-08-01 11:00:00])

    Backfill.run()

    assert events(l.name) == [
             ["parsed", nil, nil, "backfill_lat_session", 5],
             ["discarded", "unknown", nil, "backfill_inferred", nil]
           ]
  end

  test "an existing enrichment verdict becomes an enriched event" do
    l = law()

    Repo.query!(
      "UPDATE legal_register SET making_enrichment_verdict = 'no_obligations', making_enriched_at = '2026-08-05' WHERE name = $1",
      [l.name]
    )

    Backfill.run()
    assert events(l.name) == [["enriched", nil, "no_obligations", "backfill_verdict", nil]]
  end

  test "a law holding LAT with no parse record gets a parsed event from its current state;
        live trigger events are kept and backfill is idempotent" do
    l = law()
    {:ok, _} = LatPersister.persist([row(l.name, 1), row(l.name, 2)], l.name, l.id)
    # simulate LAT that predates the triggers: remove the live event
    Repo.query!("DELETE FROM lat_events WHERE law_name = $1", [l.name])

    Backfill.run()
    assert events(l.name) == [["parsed", nil, nil, "backfill_current_lat", 2]]

    # A live event is never touched; a re-run replaces only backfill events.
    {:ok, _} = LatPersister.persist([row(l.name, 1)], l.name, l.id)
    Backfill.run()
    Backfill.run()

    assert Enum.map(events(l.name), &Enum.at(&1, 3)) |> Enum.sort() ==
             ["lat_persister"]
  end
end
