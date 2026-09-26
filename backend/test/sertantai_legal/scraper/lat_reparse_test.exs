defmodule SertantaiLegal.Scraper.LatReparseTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatPersister, LatReparse}

  defp row(name, n, text) do
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
      sort_key: "000.000.000~",
      position: n,
      depth: 1,
      hierarchy_path: "provision.#{n}",
      text: text,
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }
  end

  defp law do
    name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

    law =
      LegalRegister
      |> Ash.Changeset.for_create(:create, %{
        country: "uk",
        name: name,
        title_en: "Test Regulations",
        type_code: "uksi",
        year: 2099,
        number: "1"
      })
      |> Ash.create!()

    # Older-format keys (3 segments), enriched.
    {:ok, _} = LatPersister.persist([row(name, 1, "One."), row(name, 2, "Two.")], name, law.id)

    Repo.query!(
      "UPDATE legal_articles SET drrp_types = '{Duty}', taxa_enriched_at = now() WHERE law_name = $1",
      [name]
    )

    {name, law.id}
  end

  # Stands in for LatStagedParser.parse/2: re-persists with fixed rows.
  defp parse_fn(rows_for) do
    fn name ->
      {:ok, id} = Ecto.UUID.cast(law_id(name))

      case LatPersister.persist(rows_for.(name), name, id) do
        {:ok, stats} -> {:ok, %{has_errors: false, lat: stats}}
        {:error, reason} -> {:ok, %{has_errors: true, lat: %{error: reason}, error: reason}}
      end
    end
  end

  defp law_id(name) do
    %{rows: [[id]]} = Repo.query!("SELECT id::text FROM legal_register WHERE name = $1", [name])
    id
  end

  test "older_format_laws/0 finds laws whose stored sort_keys are not current-format" do
    {name, _} = law()
    assert name in LatReparse.older_format_laws()
  end

  test "snapshots the batch, re-parses, and reports enrichment kept", %{} do
    {a, _} = law()
    {b, _} = law()
    table = "lat_reparse_test_#{System.unique_integer([:positive])}"

    report =
      LatReparse.run([a, b],
        snapshot: table,
        parse_fn: parse_fn(fn n -> [row(n, 1, "One."), row(n, 2, "Two.")] end)
      )

    assert %{status: :ok, laws: [ra, rb]} = report
    assert ra.law_name == a and rb.law_name == b
    assert ra.enriched_before == 2 and ra.enriched_after == 2
    assert ra.carried == 2

    %{rows: [[n]]} = Repo.query!("SELECT count(*) FROM #{table}", [])
    assert n == 4
  end

  test "stops at the first failing law and leaves the rest untouched" do
    {a, _} = law()
    {b, _} = law()

    # Duplicated text under new ids: ambiguous, enriched → persister gate refuses.
    bad = fn n -> [row(n, 7, "Dup."), row(n, 8, "Dup."), row(n, 9, "Dup.")] end
    Repo.query!("UPDATE legal_articles SET text = 'Dup.' WHERE law_name = $1", [a])

    report =
      LatReparse.run([a, b],
        snapshot: "lat_reparse_test_#{System.unique_integer([:positive])}",
        parse_fn: parse_fn(bad)
      )

    assert %{status: {:stopped, ^a}, laws: [ra]} = report
    assert ra.error =~ "gate"
    assert ra.enriched_after == 2
  end
end
