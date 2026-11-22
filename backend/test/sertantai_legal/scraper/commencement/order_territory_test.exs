defmodule SertantaiLegal.Scraper.Commencement.OrderTerritoryTest do
  @moduledoc """
  Waste, Water and Climate: Commencement reader — the place an order's line
  names in extent words: "so far as they extend to Northern Ireland" is
  Northern Ireland (SI 1989/1557 art.3(1)), "the repeals extend to England
  and Wales" England and Wales (SI 1996/3056 art.2); "Except to the extent
  that they extend to Scotland" names the place left out, never the place
  (SI 2005/1521 art.3(3)).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.Territory

  test "“so far as they extend to Northern Ireland” is Northern Ireland (SI 1989/1557 art.3(1))" do
    assert Territory.of(
             "Section 4, including Schedule 2, and section 13 shall, so far as they extend to Northern Ireland, come into force there on 1st September 1989."
           ) == "NI"
  end

  test "“… and the repeals extend to England and Wales” is England and Wales (SI 1996/3056 art.2)" do
    assert Territory.of(
             "Section 162(2) of the Environmental Protection Act 1990 shall come into force on 16th December 1996 in so far as it relates to the following repeals in Part I of Schedule 16 to that Act and the repeals extend to England and Wales:"
           ) == "E+W"
  end

  test "“Except to the extent that they extend to Scotland” names no place (SI 2005/1521 art.3(3))" do
    assert Territory.of(
             "Except to the extent that they extend to Scotland, the following provisions of the Act shall come into force on 1st July 2005—"
           ) == nil
  end
end
