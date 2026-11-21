defmodule SertantaiLegal.Scraper.OrderCatalogue.LawReadTest do
  @moduledoc """
  One order's reading for the order catalogue (Catalogues Across the
  Workflow, 2026-11-21: the catalogue read one order at a time, uncached,
  parsing an order's document up to three times).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.OrderCatalogue.LawRead

  @gas %{act: %{law: "UK_ukpga_1995_45", title: "Gas Act", year: "1995"}, reach: 10, ids: nil}
  @other %{
    act: %{law: "UK_ukpga_1990_43", title: "Environmental Protection Act", year: "1990"},
    reach: 5,
    ids: nil
  }

  defp xml(text),
    do:
      ~s|<Legislation><Secondary><Body><P1 id="article-2"><P1para><Text>#{text}</Text></P1para></P1><P1 id="article-3"><P1para><Text>Section 5 of the Gas Act 1995 shall come into force on 1st April 1996.</Text></P1para></P1></Body></Secondary></Legislation>|

  test "its statements, each with its pattern, and the Act it commences with its reach" do
    read =
      LawRead.read(
        "UK_uksi_1996_218",
        [xml("Section 4 of the Gas Act 1995 shall come into force on 1st March 1996.")],
        [@gas]
      )

    assert read.act.law == "UK_ukpga_1995_45"
    assert read.reach == 10
    assert [_ | _] = read.units
    assert Enum.all?(read.units, &(is_binary(&1.key) and is_binary(&1.id)))
  end

  test "a pattern takes one example from an order: its first statement's" do
    read =
      LawRead.read(
        "UK_uksi_1996_218",
        [xml("Section 4 of the Gas Act 1995 shall come into force on 1st March 1996.")],
        [@gas]
      )

    by_key = Enum.group_by(read.units, & &1.key)

    for {_key, [first | rest]} <- by_key do
      assert Map.has_key?(read.examples, first.id)

      if match?({:held, _}, read.examples[first.id]),
        do: refute(Enum.any?(rest, &Map.has_key?(read.examples, &1.id)))
    end
  end

  test "an order listed for two Acts is read for the one it commences, else the first listed" do
    doc = [xml("Section 4 of the Gas Act 1995 shall come into force on 1st March 1996.")]
    assert LawRead.read("UK_uksi_1996_218", doc, [@other, @gas]).act.law == "UK_ukpga_1995_45"
  end

  @tag :tmp_dir
  test "an order that raises leaves nothing in the cache", %{tmp_dir: dir} do
    assert catch_error(LawRead.order("not an order", [], dir: dir))
    assert File.ls!(dir) == []
  end
end
