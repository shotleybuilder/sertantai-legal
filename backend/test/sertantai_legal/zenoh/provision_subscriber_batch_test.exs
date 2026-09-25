defmodule SertantaiLegal.Zenoh.ProvisionSubscriberBatchTest do
  use SertantaiLegal.DataCase

  require Ash.Query

  alias SertantaiLegal.Legal.LegalArticle
  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatPersister
  alias SertantaiLegal.Zenoh.ProvisionSubscriber

  defp lat_row(law_name, n) do
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
      text: "The employer must assess the risk.",
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  defp law_with_lat(n) do
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

    {:ok, _} = LatPersister.persist(Enum.map(1..n, &lat_row(name, &1)), name, law.id)
    name
  end

  defp article(section_id), do: Ash.get!(LegalArticle, section_id)

  describe "upsert_rows/2" do
    test "writes the payload fields, skips unknown provisions, and leaves absent fields unchanged" do
      name = law_with_lat(3)

      Repo.query!(
        "UPDATE legal_articles SET duty_family = 'Keep me' WHERE section_id = $1",
        ["#{name}:reg.2"]
      )

      rows = [
        %{
          "section_id" => "#{name}:reg.1",
          "drrp_types" => ["Obligation"],
          "actors" => Jason.encode!([%{"label" => "Org: Employer"}]),
          "duty_family" => "Risk assessment",
          "purposes" => ["Process"],
          "taxa_confidence" => 0.9,
          "ancestor_distance" => 0,
          "significance_overall" => "HIGH"
        },
        %{"section_id" => "#{name}:reg.2", "clause_refined" => "must assess the risk"},
        %{"section_id" => "#{name}:reg.99", "drrp_types" => ["Obligation"]}
      ]

      assert %{updated: 2, not_found: 1} = ProvisionSubscriber.upsert_rows(name, rows)

      a1 = article("#{name}:reg.1")
      assert a1.drrp_types == ["Duty"]
      assert a1.duty_family == "Risk assessment"
      assert a1.purposes == ["Process"]
      assert a1.taxa_confidence == 0.9
      assert a1.ancestor_distance == 0
      assert a1.significance_overall == "HIGH"
      assert [%{"label" => "Org: Employer", "role" => "governed"}] = a1.actors
      assert a1.taxa_enriched_at

      a2 = article("#{name}:reg.2")
      assert a2.clause_refined == "must assess the risk"
      assert a2.duty_family == "Keep me"

      assert is_nil(article("#{name}:reg.3").taxa_enriched_at)

      %{rows: [[count]]} =
        Repo.query!("SELECT lat_count FROM legal_register WHERE name = $1", [name])

      assert count == 3
    end

    test "a large law updates in one pass, not one statement per provision" do
      name = law_with_lat(3_000)

      rows =
        Enum.map(1..3_000, fn n ->
          %{"section_id" => "#{name}:reg.#{n}", "drrp_types" => ["Obligation"]}
        end)

      {micros, result} = :timer.tc(fn -> ProvisionSubscriber.upsert_rows(name, rows) end)

      assert %{updated: 3_000, not_found: 0} = result
      assert micros < 10_000_000, "3,000 provision updates took #{div(micros, 1000)}ms"
    end
  end
end
