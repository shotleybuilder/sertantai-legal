defmodule SertantaiLegal.Scraper.LabelStalenessTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelStaleness

  @current %{parser: "p2", labels: "l2", changes: "c2"}
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
      changes_version: nil,
      built_at: nil
    }

  # a switched family's law: refreshed by the current change-vocabulary
  # code after its latest build
  defp switched,
    do: %{fresh() | switched: true, changes_version: "c2", built_at: ~N[2026-10-15 10:00:02]}

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

  describe "a switched family's law (#193)" do
    test "refreshed by the current change-vocabulary code after its latest build is fresh" do
      assert LabelStaleness.reasons(switched(), @current) == []
    end

    test "its labels are the change vocabulary's, so the old label code is not its reason" do
      assert LabelStaleness.reasons(%{switched() | labels_version: "l1"}, @current) == []
    end

    test "refreshed by other change-vocabulary code, or before the version was recorded" do
      assert LabelStaleness.reasons(%{switched() | changes_version: "c1"}, @current) ==
               [:timeline_version]

      assert LabelStaleness.reasons(%{switched() | changes_version: nil}, @current) ==
               [:timeline_version]
    end

    test "its changes built again after the latest refresh (OH&S, 2026-11-02 to 11-07)" do
      assert LabelStaleness.reasons(%{switched() | built_at: ~N[2026-10-15 10:00:09]}, @current) ==
               [:labels_behind_changes]
    end

    test "never built: no change build to be behind" do
      assert LabelStaleness.reasons(%{switched() | built_at: nil}, @current) == []
    end
  end
end
