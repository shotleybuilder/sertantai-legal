defmodule SertantaiLegal.Scraper.LawStart.Provisions.RefsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.Refs

  @rows [
    %{section_id: "UK_x:reg.1", text: ""},
    %{section_id: "UK_x:reg.1(1)", text: ""},
    %{section_id: "UK_x:reg.1(1)(a)", text: ""},
    %{section_id: "UK_x:reg.1(2)", text: ""},
    %{section_id: "UK_x:reg.7", text: ""}
  ]

  test "a row's children" do
    [row | _] = @rows

    assert Refs.children(row, @rows) |> Enum.map(& &1.section_id) ==
             ~w[UK_x:reg.1(1) UK_x:reg.1(1)(a) UK_x:reg.1(2)]
  end

  test "the refs a text names, bare" do
    assert "reg.7" in Refs.refs_in("regulation 7", @rows, "UK_x:reg.1")
  end
end
