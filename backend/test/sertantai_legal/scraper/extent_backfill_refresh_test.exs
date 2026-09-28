defmodule SertantaiLegal.Scraper.ExtentBackfillRefreshTest do
  use SertantaiLegal.DataCase

  require Ash.Query

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Scraper.ExtentBackfill

  test "refresh/1 re-resolves one law's extent and logs the change" do
    name = "UK_ssi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test (Scotland) Regulations",
      type_code: "ssi",
      year: 2099,
      number: "1",
      geo_extent: "UK",
      geo_region: ["England", "Wales", "Scotland", "Northern Ireland"]
    })
    |> Ash.create!()

    assert ExtentBackfill.refresh(name) == 1
    assert ExtentBackfill.refresh(name) == 0

    [law] = LegalRegister |> Ash.Query.filter(name == ^name) |> Ash.read!()
    assert law.geo_extent == "S"
    assert law.geo_region == ["Scotland"]
    assert law.geo_extent_source == "type_code"
    assert Enum.any?(law.record_change_log, &(&1["source"] == "extent"))
  end

  describe "application at LAT persist" do
    alias SertantaiLegal.Repo
    alias SertantaiLegal.Scraper.LatArchive
    alias SertantaiLegal.Scraper.LatPersister

    defp lat_row(name, n, text) do
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
        text: text,
        amendment_count: nil,
        modification_count: nil,
        commencement_count: nil,
        extent_count: nil
      }
    end

    test "LAT persist stores the application clause; it survives a lean-LAT discard; live is re-decided" do
      name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

      law =
        LegalRegister
        |> Ash.Changeset.for_create(:create, %{
          country: "uk",
          name: name,
          title_en: "Smoke-free (Signs) Regulations",
          type_code: "uksi",
          year: 2099,
          number: "1",
          geo_extent: "UK",
          live: "❌ Revoked / Repealed / Abolished",
          rescinded_by_stats_per_law: %{
            "UK_uksi_2012_1536" => %{
              "details" => [
                %{
                  "target" => "Regulations",
                  "affect" => "revoked",
                  "applied" => "Yes",
                  "feed" => "matched",
                  "effect_extent" => "E+W",
                  "territorial_application" => "E"
                }
              ]
            }
          }
        })
        |> Ash.create!()

      rows = [
        lat_row(
          name,
          1,
          "(1) These Regulations may be cited as the Smoke-free (Signs) Regulations 2007. (2) These Regulations apply in relation to England only."
        ),
        lat_row(name, 2, "The signs must be displayed.")
      ]

      {:ok, _} = LatPersister.persist(rows, name, law.id)

      %{rows: [[app, live, evidence]]} =
        Repo.query!(
          "SELECT application_clause, live, live_evidence FROM legal_register WHERE name = $1",
          [name]
        )

      assert app["regions"] == ["E"]
      assert [%{"section_id" => sid, "kind" => "apply"}] = app["clauses"]
      assert sid == "#{name}:reg.1"
      # England-only law revoked in England: revoked, a determination
      assert live == "❌ Revoked / Repealed / Abolished"
      assert evidence["law_regions_basis"] == "application"

      {:ok, _} = LatArchive.discard(name, "not_making", archive: false)
      ExtentBackfill.refresh(name)

      %{rows: [[app_after]]} =
        Repo.query!("SELECT application_clause FROM legal_register WHERE name = $1", [name])

      assert app_after["regions"] == ["E"]
    end
  end
end
