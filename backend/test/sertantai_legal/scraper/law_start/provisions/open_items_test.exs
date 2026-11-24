defmodule SertantaiLegal.Scraper.LawStart.Provisions.OpenItemsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions.OpenItems

  test "an open list's dated item names its provisions" do
    rows = [%{section_id: "UK_x:reg.12", text: ""}]
    item = %{section_id: "UK_x:reg.1(a)", text: "(a) regulation 12, on 31st May 2015;"}

    assert Enum.any?(
             OpenItems.open_item(item, rows, nil, "UK_x:reg.1"),
             &(&1.date == ~D[2015-05-31] and &1.refs == [{"UK_x:reg.12", 11}])
           )
  end
end
