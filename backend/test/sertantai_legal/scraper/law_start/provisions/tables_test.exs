defmodule SertantaiLegal.Scraper.LawStart.Provisions.TablesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Provisions.Tables

  test "no tables, no groups" do
    assert Tables.table_groups([], %LawStart{treatment: :clause_staged}, nil) == []
  end
end
