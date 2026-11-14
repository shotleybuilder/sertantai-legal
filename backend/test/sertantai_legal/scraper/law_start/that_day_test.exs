defmodule SertantaiLegal.Scraper.LawStart.ThatDayTest do
  @moduledoc """
  A list item counting from "that day" reads the day the item before it
  names (2014 c.12 s.185(2)(a), (b)); any other "that day" stays as
  written.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.ThatDay

  defp row(id, text), do: %{section_id: "UK_x:" <> id, text: text}

  test "the day of passing the item before it names" do
    rows = [
      row("s.185(2)", "Subsection (1) does not apply to—"),
      row(
        "s.185(2)(a)",
        "sections 150 and 175, which come into force on the day on which this Act is passed;"
      ),
      row(
        "s.185(2)(b)",
        "sections 151 and 177, which come into force at the end of the period of 2 months beginning with that day;"
      )
    ]

    assert ThatDay.resolve(List.last(rows), rows).text ==
             "sections 151 and 177, which come into force at the end of the period of 2 months beginning with the day on which this Act is passed;"
  end

  test "no item before it naming a day of passing or making: as written" do
    lone = row("s.9(2)", "Section 3 comes into force two months after that day.")
    assert ThatDay.resolve(lone, [lone]) == lone

    rows = [
      row("s.9(2)(a)", "section 1, which comes into force on 1st April 2020;"),
      row("s.9(2)(b)", "section 2, which comes into force at the end of 2 months after that day;")
    ]

    assert ThatDay.resolve(List.last(rows), rows) == List.last(rows)
  end

  test "an item of another provision is not the item before it" do
    rows = [
      row("s.8(1)", "Section 1 comes into force on the day on which this Act is passed."),
      row("s.9(2)(b)", "section 2, which comes into force two months after that day;")
    ]

    assert ThatDay.resolve(List.last(rows), rows) == List.last(rows)
  end
end
