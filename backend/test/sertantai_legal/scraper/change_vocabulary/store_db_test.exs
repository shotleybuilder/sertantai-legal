defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreDbTest do
  @moduledoc """
  The change register (CV-04): a law's changes written and read back are
  the changes built — claims in order, resolved attributes, sources, and
  the tiers and conflicts derived again on read.
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Store}

  defp change(key, target, claims) do
    %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }
  end

  test "written and read back unchanged; a rewrite replaces the law's changes" do
    changes =
      [
        change("key-a", "s.78", [
          {:law_text, :operation, :repealed},
          {:feed, :operation, :repealed_in_part},
          {:commencement, :date, ~D[2024-03-25]},
          {:feed, :savings, ["s.78(2)"]},
          {:law_text, :by, "UK_ukpga_2020_7"}
        ]),
        change("UK_uksi_2010_404:reg.14", "reg.14(1)", [
          {:feed, :operation, :inserted},
          {:feed, :date, ~D[2010-04-06]}
        ])
      ]
      |> Enum.map(&Evidence.resolve(&1, "E+W"))

    assert {:ok, %{changes: 2, claims: 7}} = Store.write("UK_test_2099_1", changes)

    assert Enum.sort_by(Store.for_law("UK_test_2099_1"), & &1.key) ==
             Enum.sort_by(changes, & &1.key)

    [one | _] = changes
    assert {:ok, %{changes: 1}} = Store.write("UK_test_2099_1", [one])
    assert [^one] = Store.for_law("UK_test_2099_1")
    assert one.resolved.conflicts != []
  end
end
