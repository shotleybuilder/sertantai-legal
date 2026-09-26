defmodule SertantaiLegal.Legal.Lat.SortKeyRewriteTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Legal.Lat.SortKeyRewrite
  alias SertantaiLegal.Legal.Lat.Transforms, as: T

  # A key as the old code built it for reg.6(4)(c): paragraph "c" read as Roman 100.
  @old_c "000.003.000.000.000.000.000.000.000.000.006.000.000.004.000.000.100.000.000.000.000.000.0038~"

  test "rewrites a Roman-read paragraph to its letter value, keeping every other segment and the extent" do
    assert SortKeyRewrite.rewrite(@old_c <> "E+W", "paragraph", "c", nil) ==
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

    assert SortKeyRewrite.rewrite(@old_c, "paragraph", "c", nil) == {:ok, fresh}
  end

  test "moves an unscheduled signed row after the body (part 999)" do
    old =
      "000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.0141~"

    assert SortKeyRewrite.rewrite(old, "signed", nil, nil) ==
             {:ok, T.build_sort_key("signed", position: 141)}
  end

  test "a key that is already right is unchanged" do
    key = T.build_sort_key("paragraph", provision: "6", paragraph: "b", position: 37)
    assert SortKeyRewrite.rewrite(key, "paragraph", "b", nil) == {:ok, key}
  end

  test "keys in an older format (not 23 segments) are skipped" do
    assert SortKeyRewrite.rewrite("000.000.000~", "paragraph", "c", nil) == :skip

    assert SortKeyRewrite.rewrite(
             "000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.000.100.000.000.000.000.000~",
             "paragraph",
             "c",
             nil
           ) == :skip
  end
end
