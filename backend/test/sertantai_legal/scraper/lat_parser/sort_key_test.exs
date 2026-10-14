defmodule SertantaiLegal.Scraper.LatParser.SortKeyTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser.SortKey

  describe "monotonic/1 (document-order repair)" do
    defp k(prefix, pos), do: prefix <> "." <> String.pad_leading("#{pos}", 6, "0") <> "~"

    test "rows already in order are unchanged" do
      a = %{section_id: "a", position: 1, sort_key: k(String.duplicate("000.", 21) <> "001", 1)}
      b = %{section_id: "b", position: 2, sort_key: k(String.duplicate("000.", 21) <> "002", 2)}
      assert SortKey.monotonic([a, b]) == [a, b]
    end

    test "a single out-of-place row is repaired with a neighbour's prefix, the rest kept" do
      pre = String.duplicate("000.", 21)
      a = %{section_id: "s.28(1)(b)(iii)", position: 10, sort_key: k(pre <> "900", 10) <> "E+W"}
      b = %{section_id: "s.28(c)", position: 11, sort_key: k(pre <> "100", 11) <> "S"}
      c = %{section_id: "s.29", position: 12, sort_key: k(pre <> "950", 12)}

      out = SortKey.monotonic([a, b, c])
      keys = Enum.map(out, & &1.sort_key)
      assert keys == Enum.sort(keys)
      assert Enum.count(Enum.zip([a, b, c], out), fn {x, y} -> x != y end) == 1
      assert Enum.at(out, 1).sort_key |> String.ends_with?("000011~S")
    end

    test "one too-high key is the one repaired, not every row after it" do
      pre = String.duplicate("000.", 21)

      rows =
        Enum.map([{1, "100"}, {2, "999"}, {3, "200"}, {4, "300"}, {5, "400"}], fn {pos, seg} ->
          %{section_id: "r#{pos}", position: pos, sort_key: k(pre <> seg, pos)}
        end)

      out = SortKey.monotonic(rows)
      assert out |> Enum.map(& &1.sort_key) |> then(&(&1 == Enum.sort(&1)))
      changed = for {r, o} <- Enum.zip(rows, out), r != o, do: o.section_id
      assert changed == ["r2"]
    end

    test "a run of breaking rows stays in document order" do
      pre = String.duplicate("000.", 21)

      rows =
        Enum.map([{1, "500"}, {2, "100"}, {3, "200"}, {4, "600"}], fn {pos, seg} ->
          %{section_id: "r#{pos}", position: pos, sort_key: k(pre <> seg, pos)}
        end)

      keys = rows |> SortKey.monotonic() |> Enum.map(& &1.sort_key)
      assert keys == Enum.sort(keys)
    end

    test "input order does not matter: rows are processed by position" do
      pre = String.duplicate("000.", 21)
      a = %{section_id: "a", position: 1, sort_key: k(pre <> "900", 1)}
      b = %{section_id: "b", position: 2, sort_key: k(pre <> "100", 2)}
      assert SortKey.monotonic([b, a]) |> Enum.map(& &1.section_id) == ["a", "b"]
    end
  end
end
