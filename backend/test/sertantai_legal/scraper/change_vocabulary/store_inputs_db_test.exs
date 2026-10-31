defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreInputsDbTest do
  @moduledoc """
  Change staleness end to end (CV-S11): a build written with its inputs
  (`Store.write/3`), read back by `Store.builds/0`, matches the inputs taken
  again (`Store.Inputs.of/3`) until one moves.
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeStaleness
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Store, Version}

  defp law do
    n = System.unique_integer([:positive])

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: "UK_ssi_2099_#{n}",
      title_en: "T",
      type_code: "ssi",
      year: 2099,
      number: "#{n}"
    })
    |> Ash.create!()
    |> Map.fetch!(:name)
  end

  defp reasons(law) do
    b = Store.builds()[law]
    now = Store.Inputs.of(law, b.affecting || [], b.commencement_sources || [])
    ChangeStaleness.reasons(b, %{code_version: Version.current(), inputs: now})
  end

  test "fresh after the build; stale on the input that moved" do
    law = law()
    {:ok, _} = Store.write(law, [], Store.Inputs.of(law, ["UK_ssi_2099_0"], []))
    assert reasons(law) == []

    Repo.query!(
      """
      INSERT INTO amendment_rules (amends, targets, operation, level, source_law, treatment, read_at)
      VALUES ($1, '{reg.1}', 'repealed', 'provision', 'UK_ssi_2099_0', 'stated',
              (now() AT TIME ZONE 'utc') + interval '1 second')
      """,
      [law]
    )

    assert reasons(law) == [:amendment_rules]
  end

  test "a build recorded before the fingerprints were is stale on those it lacks" do
    law = law()
    {:ok, _} = Store.write(law, [], %{clml_valid: "2026-07-16", amendment_rules: nil})
    assert reasons(law) == [:lat_rows, :law_text, :feed, :commencement_rules, :extent_rules]
  end
end
