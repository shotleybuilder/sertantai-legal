defmodule SertantaiLegal.Legal.Lat.SortKeyRewriteStoreTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Lat.SortKeyRewrite.Store
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatHash, LatPersister}

  @old_c "000.000.000.000.000.000.000.000.000.000.006.000.000.004.000.000.100.000.000.000.000.000.0003~"

  setup do
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

    base = %{
      law_name: name,
      part: nil,
      chapter: nil,
      heading_group: nil,
      schedule: nil,
      provision: "6",
      sub: "4",
      sub_paragraph: nil,
      extent_code: nil,
      depth: 3,
      hierarchy_path: nil,
      amendment_count: nil,
      modification_count: nil,
      commencement_count: nil,
      extent_count: nil
    }

    rows = [
      Map.merge(base, %{
        section_id: "#{name}:reg.6(4)(b)",
        section_type: "paragraph",
        paragraph: "b",
        position: 2,
        text: "b.",
        sort_key:
          "000.000.000.000.000.000.000.000.000.000.006.000.000.004.000.000.000.020.000.000.000.000.0002~"
      }),
      Map.merge(base, %{
        section_id: "#{name}:reg.6(4)(c)",
        section_type: "paragraph",
        paragraph: "c",
        position: 3,
        text: "c.",
        sort_key: @old_c
      })
    ]

    {:ok, _} = LatPersister.persist(rows, name, law.id)
    # LatPersister stores the parser-supplied keys as given; force the old (Roman) key.
    Repo.query!("UPDATE legal_articles SET sort_key = $1 WHERE section_id = $2", [
      @old_c,
      "#{name}:reg.6(4)(c)"
    ])

    %{name: name}
  end

  defp stored(name, id) do
    %{rows: [[k]]} =
      Repo.query!("SELECT sort_key FROM legal_articles WHERE section_id = $1", ["#{name}:#{id}"])

    k
  end

  test "plan finds only rows whose key changes", %{name: name} do
    # (c)'s Roman-read paragraph is fixed; both rows get 6-digit positions.
    changes = Store.plan([name])

    assert Enum.map(changes, & &1.section_id) |> Enum.sort() == [
             "#{name}:reg.6(4)(b)",
             "#{name}:reg.6(4)(c)"
           ]

    c = Enum.find(changes, &(&1.section_id == "#{name}:reg.6(4)(c)"))
    assert c.old == @old_c
    assert String.contains?(c.new, ".000.030.000.")
  end

  test "apply snapshots old keys, writes new ones, and the trigger refreshes lat_hash", %{
    name: name
  } do
    changes = Store.plan([name])
    table = "sort_key_rewrite_test_#{System.unique_integer([:positive])}"

    assert %{rows: 2, laws: 1} = Store.apply!(changes, table)

    assert stored(name, "reg.6(4)(b)") < stored(name, "reg.6(4)(c)")
    assert Store.plan([name]) == []

    %{rows: [[old]]} =
      Repo.query!("SELECT old_sort_key FROM #{table} WHERE section_id = $1", [
        "#{name}:reg.6(4)(c)"
      ])

    assert old == @old_c

    %{rows: [[hash]]} = Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [name])
    served = name |> SertantaiLegal.Scraper.LatHash.Query.served_query() |> Repo.all()
    assert hash == LatHash.hash(served)
  end

  test "plan re-pads positions and re-fixes a law whose stored keys are out of order", %{
    name: name
  } do
    Store.apply!(
      Store.plan([name]),
      "sort_key_rewrite_test_#{System.unique_integer([:positive])}"
    )

    assert String.ends_with?(stored(name, "reg.6(4)(c)"), ".000003~")

    # Corrupt (b)'s stored key so it sorts after (c): the law is out of order.
    Repo.query!(
      "UPDATE legal_articles SET sort_key = replace(sort_key, '.000.020.000.', '.999.020.000.') WHERE section_id = $1",
      ["#{name}:reg.6(4)(b)"]
    )

    changes = Store.plan([name])
    assert "#{name}:reg.6(4)(b)" in Enum.map(changes, & &1.section_id)
    Store.apply!(changes, "sort_key_rewrite_test_#{System.unique_integer([:positive])}")

    assert stored(name, "reg.6(4)(b)") < stored(name, "reg.6(4)(c)")
    assert Store.plan([name]) == []
  end

  test "a law whose keys already ascend (6-digit positions) is left alone, so re-runs are no-ops",
       %{name: name} do
    Store.apply!(
      Store.plan([name]),
      "sort_key_rewrite_test_#{System.unique_integer([:positive])}"
    )

    assert Store.plan([name]) == []

    # Stored segments that no longer match the columns are not "re-fixed"
    # once the law is in order: that is what made repaired rows oscillate.
    Repo.query!("UPDATE legal_articles SET paragraph = 'a' WHERE section_id = $1", [
      "#{name}:reg.6(4)(b)"
    ])

    assert Store.plan([name]) == []
  end
end
