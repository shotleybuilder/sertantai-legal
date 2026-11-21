defmodule SertantaiLegal.Scraper.Commencement.LeftoversWholeLawPurposeTest do
  @moduledoc """
  The leftovers check over a whole law staged by purpose (LAT Change
  Pipeline, step Commencement reader): a narrow purpose naming the law's
  own provisions is a list of them, fully in force on its day (Jason
  2026-11-21), so "for the purpose of" only leads the list and no word is
  left over.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{Leftovers, OwnClause}

  defp rows(specs) do
    for spec <- specs do
      {sid, text} =
        case spec do
          {sid, text} -> {sid, text}
          sid -> {sid, ""}
        end

      %{section_id: "UK_x:" <> sid, text: text, part: nil, chapter: nil}
    end
  end

  defp left(specs, made) do
    read = OwnClause.read("UK_x", %{type_code: "uksi", rows: rows(specs), made: made})

    for %{row: row, leftovers: [_ | _] = l} <- Leftovers.sentences(rows(specs), read),
        do: {row, l}
  end

  test "\"for the purpose of regulation 10(2), on …\" (SI 1991/346 reg.1(1))" do
    specs = [
      "reg.1",
      {"reg.1(1)",
       "These Regulations may he cited as the Control of Pollution (Silage, Slurry and Agricultural Fuel Oil) (Scotland) Regulations 1991 and shall come into force, for the purpose of regulation 10(2), on 20th March 1991 and for all other purposes on 1st September 1991."},
      "reg.2",
      "reg.10",
      "reg.10(2)"
    ]

    assert left(specs, ~D[1991-02-20]) == []
  end
end
