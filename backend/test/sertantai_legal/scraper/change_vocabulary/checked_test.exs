defmodule SertantaiLegal.Scraper.ChangeVocabulary.CheckedTest do
  @moduledoc "The switch-over's checked rows compared with the current labels (CV-06)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Checked

  @row %{
    "law" => "UK_ukpga_1974_37",
    "section_id" => "UK_ukpga_1974_37:s.11(1)",
    "status" => "accepted",
    "periods" => [
      %{
        "valid_from" => "1974-10-01",
        "valid_to" => nil,
        "status" => "in_force",
        "in_force_from" => "1974-10-01",
        "changed_by" => nil,
        "territory" => "E+W+S+N.I."
      }
    ]
  }

  defp current(periods), do: %{"UK_ukpga_1974_37|UK_ukpga_1974_37:s.11(1)" => periods}

  test "an accepted row matches its current label as compliance reads it" do
    now = [
      %{
        valid_from: ~D[1974-10-01],
        valid_to: nil,
        status: "in_force",
        in_force_from: ~D[1974-10-01],
        changed_by: nil,
        territory: "E+W+S+NI"
      }
    ]

    assert [{:match, _}] = Checked.compare([@row], current(now))
  end

  test "a field moved, or the row gone, is a change; other statuses pass through" do
    moved = [
      %{
        valid_from: ~D[1974-10-01],
        valid_to: nil,
        status: "in_force",
        in_force_from: ~D[1975-01-01],
        changed_by: nil,
        territory: "E+W+S+NI"
      }
    ]

    assert [{:changed, _}] = Checked.compare([@row], current(moved))
    assert [{:missing, _}] = Checked.compare([@row], %{})
    assert [{:to_fix, _}] = Checked.compare([%{@row | "status" => "to_fix"}], %{})
  end
end
