defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitchTest do
  @moduledoc "CV-06: the switched families' timeline, the named known limits keeping their old label."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{KnownLimits, LabelSwitch, LabelSwitchReport}
  alias SertantaiLegal.Scraper.LabelProjection.Period

  defp row(sid, from, by),
    do: %{
      law_name: "UK_ukpga_1974_37",
      section_id: sid,
      valid_from: from,
      valid_to: nil,
      status: "in_force",
      in_force_from: from,
      changed_by: by,
      changed_by_all: List.wrap(by),
      commenced_by: [],
      territory: "E+W+S",
      change_ids: []
    }

  test "a known limit keeps its old periods; every other row its new ones" do
    new = [row("A:s.1", ~D[1974-07-31], nil), row("A:s.2", ~D[1990-01-01], "UK_x")]

    old = [
      %Period{law_name: "A", section_id: "A:s.1", valid_from: ~D[1975-01-01], status: "in_force"},
      %Period{law_name: "A", section_id: "A:s.2", valid_from: ~D[1975-01-01], status: "in_force"}
    ]

    assert [%{section_id: "A:s.2", valid_from: ~D[1990-01-01]}, kept] =
             LabelSwitch.merge_kept(new, old, MapSet.new(["A:s.1"]))

    assert %{
             section_id: "A:s.1",
             valid_from: ~D[1975-01-01],
             changed_by_all: [],
             commenced_by: []
           } =
             kept
  end

  test "the known-limit tables' rows: their first cell" do
    text = """
    | Row | Amending law | Why |
    |---|---|---|
    | UK_ukpga_1974_37:s.34(6) | UK_ukpga_1986_44 | commencement not held |
    """

    assert KnownLimits.parse(text) == ["UK_ukpga_1974_37:s.34(6)"]
  end

  test "no family switched: none is" do
    assert LabelSwitch.families() == []
  end

  test "a family is switched by its exact name, the display marker dropped" do
    fams = ["OH&S: Occupational / Personal Safety", "TRANSPORT: Maritime Safety"]

    assert LabelSwitch.family_in?("💙 OH&S: Occupational / Personal Safety", fams)
    assert LabelSwitch.family_in?("💙 TRANSPORT: Maritime Safety", fams)
    assert LabelSwitch.family_in?("TRANSPORT: Maritime Safety", fams)
    refute LabelSwitch.family_in?("💙 OH&S: Occupational", fams)
    refute LabelSwitch.family_in?("💙 OH&S: Offshore Safety", fams)

    refute LabelSwitch.family_in?("💙 OH&S: Occupational / Personal Safety", ["OH&S: Occupational"])

    refute LabelSwitch.family_in?(nil, fams)
  end

  test "the dry run's comparison: rows differing and today's status each way" do
    old = [
      %Period{law_name: "A", section_id: "A:s.1", valid_from: ~D[1975-01-01], status: "in_force"},
      %Period{law_name: "A", section_id: "A:s.2", valid_from: ~D[1975-01-01], status: "in_force"}
    ]

    new = [
      row("A:s.1", ~D[1975-01-01], nil) |> Map.merge(%{in_force_from: nil, territory: nil}),
      %{row("A:s.2", ~D[1990-01-01], "UK_x") | status: "repealed"}
    ]

    r = LabelSwitchReport.law("A", old, new, ~D[2026-11-02])
    assert %{rows: 2, periods_old: 2, periods_new: 2, differ: 1} = r
    assert r.today_old == %{"in_force" => 2}
    assert r.today_new == %{"in_force" => 1, "repealed" => 1}
    assert %{laws: 1, differ: 1} = LabelSwitchReport.total([r])
  end
end
