defmodule SertantaiLegal.Scraper.Commencement.CheckSignatureTest do
  @moduledoc """
  The commencement check's rows: a signature block is no provision, so a
  clause that names every Part and says nothing of the signature leaves no
  fault there (SI 2024/1130 art.1(2), (3)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Check, OwnClause}

  defp row(id, text, part),
    do: %{section_id: "UK_x:" <> id, text: text, part: part, chapter: nil, extent_code: nil}

  test "a signature row no rule reaches is not a provision, never our fault" do
    rows = [
      row("pt.1", "", "1"),
      row("reg.1", "", "1"),
      row("reg.1(2)", "Part 1 comes into force on 1st December 2024.", "1"),
      row("pt.2", "", "2"),
      row("reg.1(3)", "Part 2 comes into force on 1st January 2025.", "1"),
      row("reg.5", "", "2"),
      row("signed", "Signed by authority of the Secretary of State, 5th November 2024", nil)
    ]

    rules = OwnClause.rules("UK_x", %{type_code: "uksi", rows: rows, made: ~D[2024-11-05]})
    checked = Check.rows("UK_x", rows, rules, %{}, false)

    assert Enum.find(checked, &(&1.id == "signed")).outcome == :not_a_provision
    assert Enum.find(checked, &(&1.id == "reg.5")).outcome == :dated
    assert Check.faults(checked) == []
  end
end
