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

    assert SortKeyRewrite.rewrite(@old_c, row("paragraph", "6", "c", "3")) == {:ok, fresh}
  end

  test "moves an unscheduled signed row after the body (part 999)" do
    old =
      "000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.0141~"

    assert SortKeyRewrite.rewrite(old, row("signed", nil, nil)) ==
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

    assert SortKeyRewrite.rewrite(old, row("article", "Article 12", nil, "2", "2")) ==
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
end
