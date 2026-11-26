defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.AmendingYardstickTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.AmendingYardstick, as: Y

  defp change(claims),
    do: %Change{
      key: "k",
      target: "reg.1",
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "k"})
    }

  test "a text change's operation, the law's text against legislation.gov.uk (the feed, else the markup)" do
    assert Y.classify(
             change([{:law_text, :operation, :repealed}, {:feed, :operation, :repealed}])
           ) ==
             {"agree", nil}

    assert Y.classify(
             change([
               {:law_text, :operation, :inserted},
               {:feed, :operation, :substituted},
               {:markup, :operation, :inserted}
             ])
           ) == {"differ", nil}

    assert Y.classify(
             change([{:law_text, :operation, :inserted}, {:markup, :operation, :inserted}])
           ) ==
             {"agree", nil}

    assert Y.classify(change([{:law_text, :operation, :repealed}])) == {"law_only", nil}
    assert Y.classify(change([{:markup, :operation, :substituted}])) == {"gov_only", nil}
  end

  test "the level where both state it" do
    assert Y.classify(
             change([
               {:law_text, :operation, :substituted},
               {:law_text, :level, :words},
               {:feed, :operation, :substituted},
               {:feed, :level, :provision}
             ])
           ) == {"agree", "differ"}
  end

  test "a commencement or a change no source gives an operation is no text change" do
    assert Y.classify(change([{:feed, :operation, :commenced}])) == nil
    assert Y.classify(change([{:feed, :by, "UK_uksi_2020_1"}])) == nil
  end

  test "the record counts every class over the text changes, and the gate's strata" do
    changes = [
      change([{:law_text, :operation, :repealed}, {:feed, :operation, :repealed}]),
      change([{:law_text, :operation, :repealed}]),
      change([{:feed, :operation, :inserted}]),
      change([{:feed, :operation, :commenced}])
    ]

    r = Y.record("F", ~U[2026-11-26 12:00:00Z], changes, %{A: 1, L: 1})
    assert r.text_changes == 3
    assert r.operation == %{"agree" => 1, "differ" => 0, "law_only" => 1, "gov_only" => 1}
    assert r.operation |> Map.values() |> Enum.sum() == r.text_changes
    assert r.level == %{"agree" => 0, "differ" => 0}
    assert r.strata == %{"A" => 1, "D" => 0, "L" => 1}
  end

  @tag :tmp_dir
  test "written and read back; the measures' lines", %{tmp_dir: dir} do
    r =
      Y.record("F", ~U[2026-11-26 12:00:00Z], [change([{:law_text, :operation, :repealed}])], %{
        L: 1
      })

    path = Path.join(dir, "f.json")
    :ok = Y.write(r, path)
    back = Y.read(path)
    assert back.operation["law_only"] == 1

    [head | _] = lines = Y.lines(back, ~U[2026-11-27 00:00:00Z])
    assert head =~ "BEFORE the last build"
    assert Enum.any?(lines, &(&1 =~ "law_only"))
    assert [_] = Y.lines(nil, nil)

    assert Y.path("Waste, Water and Climate") =~
             "amending-reader/yardstick/waste-water-and-climate.json"
  end
end
