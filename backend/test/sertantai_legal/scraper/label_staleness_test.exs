defmodule SertantaiLegal.Scraper.LabelStalenessTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelStaleness

  @current %{parser: "p2", labels: "l2", fold: "f2"}
  @t0 ~N[2026-10-15 10:00:00]
  @t1 ~N[2026-10-15 10:00:05]

  defp fresh,
    do: %{
      parsed_at: @t0,
      parser_version: "p2",
      refreshed_at: @t1,
      labels_version: "l2",
      failed_at: nil,
      switched: false,
      fold_version: nil,
      folded_digest: nil,
      fold_inputs: nil,
      fold_inputs_now: nil,
      built_at: nil,
      built_digest: nil
    }

  # a switched family's law: folded by the current fold code from its latest
  # build's output, with today's fold inputs
  defp switched,
    do: %{
      fresh()
      | switched: true,
        fold_version: "f2",
        folded_digest: "d1",
        fold_inputs: "i1",
        fold_inputs_now: "i1",
        built_at: ~N[2026-10-15 10:00:02],
        built_digest: "d1"
    }

  test "a law parsed and relabelled by the current code is fresh" do
    assert LabelStaleness.reasons(fresh(), @current) == []
  end

  test "parsed by older parser code (or before parser versions existed)" do
    assert LabelStaleness.reasons(%{fresh() | parser_version: "p1"}, @current) == [
             :parser_version
           ]

    assert LabelStaleness.reasons(%{fresh() | parser_version: nil}, @current) == [:parser_version]
  end

  test "no refresh since the latest parse" do
    assert LabelStaleness.reasons(%{fresh() | refreshed_at: nil, labels_version: nil}, @current) ==
             [:labels_behind_parse]

    assert LabelStaleness.reasons(%{fresh() | refreshed_at: ~N[2026-10-14 09:00:00]}, @current) ==
             [:labels_behind_parse]
  end

  test "labels built by older label code" do
    assert LabelStaleness.reasons(%{fresh() | labels_version: "l1"}, @current) == [
             :labels_version
           ]
  end

  test "a failed refresh after the latest parse and refresh" do
    assert LabelStaleness.reasons(%{fresh() | failed_at: ~N[2026-10-15 10:00:09]}, @current) ==
             [:labels_failed]

    assert LabelStaleness.reasons(%{fresh() | failed_at: ~N[2026-10-15 09:00:00]}, @current) == []
  end

  test "no parse event at all" do
    assert :no_parse_event in LabelStaleness.reasons(%{fresh() | parsed_at: nil}, @current)
  end

  describe "a switched family's law (#193, #194)" do
    test "folded by the current fold code from its latest build's output is fresh" do
      assert LabelStaleness.reasons(switched(), @current) == []
    end

    test "its labels are the fold's, so the old label code is not its reason" do
      assert LabelStaleness.reasons(%{switched() | labels_version: "l1"}, @current) == []
    end

    test "folded by other fold code, or before the version was recorded" do
      assert LabelStaleness.reasons(%{switched() | fold_version: "f1"}, @current) ==
               [:fold_version]

      assert LabelStaleness.reasons(%{switched() | fold_version: nil}, @current) ==
               [:fold_version]
    end

    test "a rebuild after the refresh giving the same output stales no label" do
      later = %{switched() | built_at: ~N[2026-10-15 10:00:09]}
      assert LabelStaleness.reasons(later, @current) == []
    end

    test "its latest build's output is not the one folded" do
      assert LabelStaleness.reasons(%{switched() | built_digest: "d2"}, @current) ==
               [:labels_behind_changes]
    end

    test "folded before digests were recorded (#194)" do
      assert LabelStaleness.reasons(%{switched() | folded_digest: nil}, @current) ==
               [:labels_behind_changes]

      both_unrecorded = %{switched() | folded_digest: nil, built_digest: nil}
      assert LabelStaleness.reasons(both_unrecorded, @current) == [:labels_behind_changes]
    end

    test "its rows, register record, text or known limits moved since the fold" do
      assert LabelStaleness.reasons(%{switched() | fold_inputs_now: "i2"}, @current) ==
               [:fold_inputs]

      assert LabelStaleness.reasons(%{switched() | fold_inputs: nil}, @current) ==
               [:fold_inputs]
    end

    test "never built: no change build to be behind" do
      assert LabelStaleness.reasons(%{switched() | built_at: nil, built_digest: nil}, @current) ==
               []
    end
  end
end
