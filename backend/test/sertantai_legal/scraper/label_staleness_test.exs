defmodule SertantaiLegal.Scraper.LabelStalenessTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LabelStaleness

  @current %{parser: "p2", labels: "l2"}
  @t0 ~N[2026-10-15 10:00:00]
  @t1 ~N[2026-10-15 10:00:05]

  defp fresh,
    do: %{
      parsed_at: @t0,
      parser_version: "p2",
      refreshed_at: @t1,
      labels_version: "l2",
      failed_at: nil
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
end
