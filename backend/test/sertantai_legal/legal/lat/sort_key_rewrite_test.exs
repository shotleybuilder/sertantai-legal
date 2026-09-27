defmodule SertantaiLegal.Legal.Lat.SortKeyRewriteTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Lat.SortKeyRewrite
  alias SertantaiLegal.Legal.Lat.Transforms, as: T

  defp row(type, provision, paragraph, part \\ nil, chapter \\ nil),
    do: %{
      section_type: type,
      part: part,
      chapter: chapter,
      provision: provision,
      paragraph: paragraph,
      schedule: nil
    }

  # A key as the old code built it for reg.6(4)(c): paragraph "c" read as Roman 100.
  @old_c "000.003.000.000.000.000.000.000.000.000.006.000.000.004.000.000.100.000.000.000.000.000.0038~"

  test "rewrites a Roman-read paragraph to its letter value, keeping every other segment and the extent" do
    assert SortKeyRewrite.rewrite(@old_c <> "E+W", row("paragraph", "6", "c")) ==
             {:ok,
              "000.003.000.000.000.000.000.000.000.000.006.000.000.004.000.000.000.030.000.000.000.000.0038~E+W"}
  end

  test "matches what the fixed build_sort_key produces for the same row" do
    fresh =
      T.build_sort_key("paragraph",
        part: "3",
        provision: "6",
        sub: "4",
        paragraph: "c",
        position: 38
      )

    assert SortKeyRewrite.rewrite(@old_c, Map.put(row("paragraph", "6", "c", "3"), :position, 38)) ==
             {:ok, fresh}
  end

  test "moves an unscheduled signed row after the body (part 999)" do
    old =
      "000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.0141~"

    assert SortKeyRewrite.rewrite(old, Map.put(row("signed", nil, nil), :position, 141)) ==
             {:ok, T.build_sort_key("signed", position: 141)}
  end

  test "a key that is already right is unchanged" do
    key = T.build_sort_key("paragraph", provision: "6", paragraph: "b", position: 37)
    assert SortKeyRewrite.rewrite(key, row("paragraph", "6", "b")) == {:ok, key}
  end

  test "keys in an older format (not 23 segments) are skipped" do
    assert SortKeyRewrite.rewrite("000.000.000~", row("paragraph", "6", "c")) == :skip

    assert SortKeyRewrite.rewrite(
             "000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.100.000.000.000.000.000~",
             row("paragraph", "6", "c")
           ) == :skip
  end

  test "recomputes an EU provision segment ('Article 12' read as letters AR)" do
    old =
      "000.002.000.000.002.000.000.000.000.000.000.010.180.000.000.000.000.000.000.000.000.000.0101~"

    assert SortKeyRewrite.rewrite(
             old,
             Map.put(row("article", "Article 12", nil, "2", "2"), :position, 101)
           ) ==
             {:ok,
              T.build_sort_key("article",
                part: "2",
                chapter: "2",
                provision: "Article 12",
                position: 101
              )}
  end

  test "recomputes labelled part and chapter segments ('CHAPTER III' read as letters)" do
    old = T.build_sort_key("article", part: "I", chapter: "3", provision: "9", position: 40)
    bad = String.replace(old, "000.003.000.000", "000.030.080.000", global: false)
    refute bad == old

    assert SortKeyRewrite.rewrite(bad, row("article", "9", nil, "I", "CHAPTER III")) == {:ok, old}
  end

  describe "monotonic/1 (document-order repair)" do
    defp k(prefix, pos), do: prefix <> "." <> String.pad_leading("#{pos}", 6, "0") <> "~"

    test "rows already in order are unchanged" do
      a = %{section_id: "a", position: 1, sort_key: k(String.duplicate("000.", 21) <> "001", 1)}
      b = %{section_id: "b", position: 2, sort_key: k(String.duplicate("000.", 21) <> "002", 2)}
      assert SortKeyRewrite.monotonic([a, b]) == [a, b]
    end

    test "a single out-of-place row is repaired with a neighbour's prefix, the rest kept" do
      pre = String.duplicate("000.", 21)
      a = %{section_id: "s.28(1)(b)(iii)", position: 10, sort_key: k(pre <> "900", 10) <> "E+W"}
      b = %{section_id: "s.28(c)", position: 11, sort_key: k(pre <> "100", 11) <> "S"}
      c = %{section_id: "s.29", position: 12, sort_key: k(pre <> "950", 12)}

      out = SortKeyRewrite.monotonic([a, b, c])
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

      out = SortKeyRewrite.monotonic(rows)
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

      keys = rows |> SortKeyRewrite.monotonic() |> Enum.map(& &1.sort_key)
      assert keys == Enum.sort(keys)
    end

    test "input order does not matter: rows are processed by position" do
      pre = String.duplicate("000.", 21)
      a = %{section_id: "a", position: 1, sort_key: k(pre <> "900", 1)}
      b = %{section_id: "b", position: 2, sort_key: k(pre <> "100", 2)}
      assert SortKeyRewrite.monotonic([b, a]) |> Enum.map(& &1.section_id) == ["a", "b"]
    end
  end

  test "rewrite/2 re-pads the position segment to 6 digits from the row's position" do
    key =
      "000.000.000.000.000.000.000.000.000.000.001.000.000.000.000.000.000.000.000.000.000.000.9999~"

    assert {:ok, new} =
             SortKeyRewrite.rewrite(key, Map.put(row("article", "1", nil), :position, 10_250))

    assert String.ends_with?(new, ".010250~")
  end
end
