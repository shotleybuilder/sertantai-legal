defmodule SertantaiLegal.Legal.MakingFunnelTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo

  defp law(live, attrs \\ %{}) do
    name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          country: "uk",
          name: name,
          title_en: "Test Regulations",
          type_code: "uksi",
          year: 2099,
          number: "1",
          live: live
        },
        attrs
      )
    )
    |> Ash.create!()

    Repo.query!("UPDATE legal_register SET is_making = true WHERE name = $1", [name])
    name
  end

  defp funnel(name) do
    %{rows: [[revoked, action]]} =
      Repo.query!("SELECT revoked, next_action FROM making_funnel WHERE name = $1", [name])

    {revoked, action}
  end

  test "an in-force Making law without LAT is asked to lat_parse" do
    assert funnel(law("✔ In force")) == {false, "lat_parse"}
  end

  test "a revoked law gets no next action: revoked laws are ceiling items, not work" do
    assert funnel(law("❌ Revoked / Repealed / Abolished")) == {true, nil}
  end

  test "a partly revoked law is still in force and keeps its action" do
    assert funnel(law("⭕ Part Revocation / Repeal")) == {false, "lat_parse"}
  end

  describe "lat_evidence" do
    defp evidence(name) do
      %{rows: [[e]]} =
        Repo.query!("SELECT lat_evidence FROM making_funnel WHERE name = $1", [name])

      e
    end

    defp event(name, event, at, attrs \\ %{}) do
      %{rows: [[id, country]]} =
        Repo.query!("SELECT id, country FROM legal_register WHERE name = $1", [name])

      Repo.query!(
        "INSERT INTO lat_events (law_id, country, law_name, event, at, source, lat_hash) VALUES ($1, $2, $3, $4, $5, 'test', $6)",
        [id, country, name, event, at, attrs[:lat_hash]]
      )
    end

    test "none without events; parsed_then_discarded; enriched_then_discarded" do
      a = law("✔ In force")
      assert evidence(a) == "none"

      event(a, "parsed", ~U[2026-08-01 10:00:00Z])
      event(a, "discarded", ~U[2026-08-02 10:00:00Z])
      assert evidence(a) == "parsed_then_discarded"

      b = law("✔ In force")
      event(b, "parsed", ~U[2026-08-01 10:00:00Z])
      event(b, "enriched", ~U[2026-08-01 12:00:00Z])
      event(b, "discarded", ~U[2026-08-02 10:00:00Z])
      assert evidence(b) == "enriched_then_discarded"
    end

    test "enrichment after the discard does not count as evidence from that LAT" do
      c = law("✔ In force")
      event(c, "parsed", ~U[2026-08-01 10:00:00Z])
      event(c, "discarded", ~U[2026-08-02 10:00:00Z])
      event(c, "enriched", ~U[2026-08-03 10:00:00Z])
      assert evidence(c) == "parsed_then_discarded"
    end

    test "lat_held, and lat_held_stale_enrichment when the enrichment hash differs" do
      d = law("✔ In force")
      %{rows: [[id]]} = Repo.query!("SELECT id::text FROM legal_register WHERE name = $1", [d])

      row = %{
        section_id: "#{d}:reg.1",
        law_name: d,
        section_type: "article",
        part: nil,
        chapter: nil,
        heading_group: nil,
        schedule: nil,
        provision: "1",
        sub: nil,
        paragraph: nil,
        sub_paragraph: nil,
        extent_code: nil,
        sort_key: "000.000001~",
        position: 1,
        depth: 1,
        hierarchy_path: nil,
        text: "The employer must.",
        amendment_count: nil,
        modification_count: nil,
        commencement_count: nil,
        extent_count: nil
      }

      {:ok, _} = SertantaiLegal.Scraper.LatPersister.persist([row], d, id)
      assert evidence(d) == "lat_held"

      %{rows: [[current]]} =
        Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [d])

      event(d, "enriched", ~U[2026-08-01 10:00:00Z], %{lat_hash: "older"})
      assert evidence(d) == "lat_held_stale_enrichment"

      event(d, "enriched", ~U[2026-08-02 10:00:00Z], %{lat_hash: current})
      assert evidence(d) == "lat_held"
    end
  end
end
