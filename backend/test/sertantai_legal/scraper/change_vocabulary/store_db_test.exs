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

  defp register(name) do
    [_, type, year, number] = String.split(name, "_")

    SertantaiLegal.Legal.LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test",
      type_code: type,
      year: String.to_integer(year),
      number: number
    })
    |> Ash.create!()
  end

  test "the law's start is stored with its build, and the latest build's is read" do
    register("UK_uksi_2099_3")
    assert Store.start("UK_uksi_2099_3") == :none

    start = %SertantaiLegal.Scraper.LawStart{treatment: :lrt_metadata, date: ~D[2099-05-01]}
    {:ok, _} = Store.write("UK_uksi_2099_3", [], %{}, start)
    assert Store.start("UK_uksi_2099_3") == {:ok, ~D[2099-05-01]}

    # a known limit: no date, but a start was resolved
    {:ok, _} = Store.write("UK_uksi_2099_3", [], %{}, %{start | date: nil})
    assert Store.start("UK_uksi_2099_3") == {:ok, nil}
  end

  test "each build records its output's digest: a rebuild giving the same changes and start gives the same (#194)" do
    register("UK_uksi_2099_4")
    assert Store.digest("UK_uksi_2099_4") == nil

    start = %SertantaiLegal.Scraper.LawStart{treatment: :lrt_metadata, date: ~D[2099-05-01]}

    changes =
      [change("key-b", "reg.2", [{:feed, :operation, :repealed}, {:feed, :date, ~D[2099-06-01]}])]
      |> Enum.map(&Evidence.resolve(&1, "E+W"))

    {:ok, _} = Store.write("UK_uksi_2099_4", changes, %{}, start)
    first = Store.digest("UK_uksi_2099_4")
    assert first =~ ~r/^[0-9a-f]{16}$/

    # a reader edit that changes no output (a comment): the same digest, so
    # no label is behind its changes
    {:ok, _} = Store.write("UK_uksi_2099_4", changes, %{}, start)
    assert Store.digest("UK_uksi_2099_4") == first

    {:ok, _} = Store.write("UK_uksi_2099_4", changes, %{}, %{start | date: ~D[2099-05-02]})
    refute Store.digest("UK_uksi_2099_4") == first

    {:ok, _} = Store.write("UK_uksi_2099_4", [], %{}, start)
    refute Store.digest("UK_uksi_2099_4") == first
  end
end
