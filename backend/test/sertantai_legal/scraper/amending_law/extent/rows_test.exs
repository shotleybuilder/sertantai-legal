defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.RowsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Rows

  test "lists are stored and read back with no default (round 1 N9)" do
    e = %Extent{lists: [{:only, "S", ["s.107"]}]}
    rows = Rows.to_rows(e, "UK_ukpga_2015_20")
    refute Enum.any?(rows, &(&1.kind == "none"))
    assert Rows.from_rows(rows).lists == e.lists
    assert Rows.to_rows(%Extent{}, "UK_ukpga_2015_20") |> Enum.map(& &1.kind) == ["none"]
  end

  test "every statement round-trips" do
    e = %Extent{
      default: "E+W",
      ref: "s.179",
      text: "This Act extends to England and Wales only.",
      lists: [{:also, "S", ["s.1"]}, {:not, "NI", ["s.2"]}, {:same, nil, ["*"]}],
      corresponds: true,
      introduced_by: %{"sch.7" => "s.111"},
      application: "E",
      powers: "E+W+S",
      competence: "E+W",
      targets: [
        %{kind: :also, place: "S", scope: "sch.7.para.27", law: nil, refs: ["s.4(8)"]},
        %{kind: :only, place: "E+W+NI", scope: "*", law: "Arbitration Act 1975", refs: ["*"]}
      ]
    }

    assert Rows.from_rows(Rows.to_rows(e, "UK_ukpga_2005_15")) == e
    assert Rows.from_rows([]) == nil
  end
end
