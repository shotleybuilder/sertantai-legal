defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelContainersTest do
  @moduledoc """
  CV-S09 batch 6 (Jason 2026-10-30): a Part, Chapter or Title goes with its
  last child (NISR 1997/248 Pt IV).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Containers

  defp p(from, status, opts \\ []),
    do: %{
      valid_from: from,
      valid_to: nil,
      status: status,
      in_force_from: Keyword.get(opts, :iff),
      changed_by: Keyword.get(opts, :by, []),
      commenced_by: [],
      territory: Keyword.get(opts, :territory, "NI"),
      tiers: Keyword.get(opts, :tiers, %{})
    }

  @start ~D[1997-07-01]

  test "every child repealed: the Part is repealed (saved) on the last child's day, credited to their laws" do
    labels = %{
      "pt.IV" => [p(@start, :in_force, iff: @start)],
      "reg.13" => [
        p(@start, :in_force),
        p(~D[2006-08-01], :repealed_saved, by: ["UK_nisr_2006_173"], tiers: %{status: :derived})
      ],
      "reg.14" => [
        p(@start, :in_force),
        p(~D[2005-01-01], :repealed, by: ["UK_nisr_2004_1"], territory: "nowhere")
      ]
    }

    closed = Containers.close(labels, %{"reg.13" => ["pt.IV"], "reg.14" => ["pt.IV"]})

    assert [%{valid_to: ~D[2006-08-01]}, gone] = closed["pt.IV"]

    assert %{
             valid_from: ~D[2006-08-01],
             status: :repealed_saved,
             territory: "NI",
             in_force_from: nil,
             changed_by: ["UK_nisr_2004_1", "UK_nisr_2006_173"]
           } = gone

    assert gone.tiers.status == :derived
  end

  test "a child still in force keeps the Part in force; a row holding nothing is untouched" do
    labels = %{
      "pt.IV" => [p(@start, :in_force)],
      "reg.13" => [p(@start, :in_force), p(~D[2006-08-01], :repealed, territory: "nowhere")],
      "reg.14" => [p(@start, :in_force)]
    }

    closed = Containers.close(labels, %{"reg.13" => ["pt.IV"], "reg.14" => ["pt.IV"]})
    assert closed["pt.IV"] == labels["pt.IV"]
    assert closed["reg.14"] == labels["reg.14"]
  end
end
