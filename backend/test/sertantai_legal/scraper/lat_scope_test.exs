defmodule SertantaiLegal.Scraper.LatScopeTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatScope

  defp row(id, key, pos), do: %{section_id: id, sort_key: key, position: pos}

  defp key(part, provision, pos),
    do:
      "000.#{part}.000.000.001.000.000.000.000.000.#{provision}.000.000.000.000.000.000.000.000.000.000.000." <>
        String.pad_leading("#{pos}", 6, "0") <> "~"

  describe "paths/2" do
    test "no scope: the whole body" do
      assert LatScope.paths("ukpga/1991/57", nil) == ["/ukpga/1991/57/body/data.xml"]
    end

    test "a scope: one data.xml per fragment" do
      scope = %{"fragments" => ["section/82", "schedule/3"]}

      assert LatScope.paths("ukpga/1991/57", scope) == [
               "/ukpga/1991/57/section/82/data.xml",
               "/ukpga/1991/57/schedule/3/data.xml"
             ]
    end
  end

  describe "merge/1" do
    test "a single document is returned unchanged" do
      rows = [row("a", key("003", "082", 1), 1)]
      assert LatScope.merge([rows]) == rows
    end

    test "fragments: shared Part/Chapter rows once, document order, positions renumbered" do
      s82 = [
        row("X:pt.III", key("003", "000", 1), 1),
        row("X:s.82", key("003", "082", 2), 2)
      ]

      s219 = [
        row("X:pt.VIII", key("008", "000", 1), 1),
        row("X:s.219", key("008", "219", 2), 2)
      ]

      s83 = [
        row("X:pt.III", key("003", "000", 1), 1),
        row("X:s.83", key("003", "083", 2), 2)
      ]

      merged = LatScope.merge([s219, s82, s83])

      assert Enum.map(merged, & &1.section_id) ==
               ["X:pt.III", "X:s.82", "X:s.83", "X:pt.VIII", "X:s.219"]

      assert Enum.map(merged, & &1.position) == [1, 2, 3, 4, 5]

      assert Enum.map(merged, &String.slice(&1.sort_key, -7, 6)) ==
               ~w(000001 000002 000003 000004 000005)
    end
  end

  describe "widen/2" do
    test "adds fragments (union, order kept); never narrows; whole stays whole" do
      assert LatScope.widen(nil, ["section/82"]) == :whole

      assert LatScope.widen(%{"fragments" => ["section/82"]}, ["section/219", "section/82"]) ==
               {:ok, ["section/82", "section/219"]}

      assert LatScope.widen(%{"fragments" => ["section/82"]}, ["section/82"]) == :unchanged
    end
  end

  describe "fragments_for/2" do
    test "enabling provisions → section and schedule fragments" do
      assert LatScope.fragments_for(%{"sections" => ["82", "219"], "schedules" => ["3"]}) ==
               ["section/82", "section/219", "schedule/3"]

      assert LatScope.fragments_for(%{"law" => "UK_nisi_1978_1039", "sections" => ["17"]}) ==
               ["article/17"]
    end
  end
end
