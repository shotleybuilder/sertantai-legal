defmodule SertantaiLegal.Legal.Lat.SortKeyRewriteStoreTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Lat.SortKeyRewrite.Store
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatHash, LatPersister}

  @old_c "000.000.000.000.000.000.000.000.000.000.006.000.000.004.000.000.100.000.000.000.000.000.000003~"

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
          "000.000.000.000.000.000.000.000.000.000.006.000.000.004.000.000.000.020.000.000.000.000.000002~"
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
    assert [%{section_id: sid, law_name: ^name, old: @old_c, new: new}] = Store.plan([name])
    assert sid == "#{name}:reg.6(4)(c)"
    assert String.contains?(new, ".000.030.000.")
  end

  test "apply snapshots old keys, writes new ones, and the trigger refreshes lat_hash", %{
    name: name
  } do
    changes = Store.plan([name])
    table = "sort_key_rewrite_test_#{System.unique_integer([:positive])}"

    assert %{rows: 1, laws: 1} = Store.apply!(changes, table)

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

  test "plan re-pads positions and repairs document-order breaks per law", %{name: name} do
    Store.apply!(
      Store.plan([name]),
      "sort_key_rewrite_test_#{System.unique_integer([:positive])}"
    )

    # (b)'s numbering now sorts after (c): a break the hierarchy cannot resolve.
    Repo.query!("UPDATE legal_articles SET paragraph = 'z' WHERE section_id = $1", [
      "#{name}:reg.6(4)(b)"
    ])

    changes = Store.plan([name])
    # The outlier (b) is repaired; (c) keeps its own key.
    assert "#{name}:reg.6(4)(b)" in Enum.map(changes, & &1.section_id)
    Store.apply!(changes, "sort_key_rewrite_test_#{System.unique_integer([:positive])}")

    assert stored(name, "reg.6(4)(b)") < stored(name, "reg.6(4)(c)")
    assert String.ends_with?(stored(name, "reg.6(4)(c)"), ".000003~")
    assert Store.plan([name]) == []
  end
end
