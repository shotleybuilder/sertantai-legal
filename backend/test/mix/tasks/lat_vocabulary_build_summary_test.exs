defmodule Mix.Tasks.Lat.VocabularyBuildSummaryTest do
  use ExUnit.Case, async: true

  alias Mix.Tasks.Lat.Vocabulary

  test "a build with no failures reports its laws, time, workers and 0 failed" do
    assert Vocabulary.build_summary(117, 39_400_000, 4, 0) ==
             {:ok, "built 117 laws in 39.4 s (4 workers), 0 failed"}
  end

  test "a build with any failure is an error, so the task exits non-zero" do
    assert {:error, line} = Vocabulary.build_summary(117, 100_000, 4, 117)
    assert line =~ "built 117 laws in 0.1 s (4 workers), 117 failed"
  end
end
