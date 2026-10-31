defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelShadowTest do
  @moduledoc "The switch-over's shadow comparison (CV-06): new timeline rows against the stored ones, by cause."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, LabelShadow}

  @law "UK_ukpga_1937_67"
  @today ~D[2026-10-31]

  defp old(from, status, opts \\ []) do
    %{
      valid_from: from,
      valid_to: Keyword.get(opts, :to),
      status: status,
      in_force_from: Keyword.get(opts, :in_force_from),
      changed_by: Keyword.get(opts, :changed_by),
      territory: Keyword.get(opts, :territory)
    }
  end

  defp new(from, status, opts \\ []) do
    by = Keyword.get(opts, :changed_by, [])

    old(from, status, opts)
    |> Map.merge(%{changed_by: List.last(by), changed_by_all: by})
  end

  defp change(op, date, sources) do
    %Change{
      key: "k-#{op}-#{date}",
      target: "s.61",
      claims:
        for(s <- sources, do: %Claim{source: s, attribute: :operation, value: op, ref: "k"}),
      resolved: %Evidence.Resolved{
        operation: op,
        level: :provision,
        territory: nil,
        date: date,
        by: nil,
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }
  end

  test "agreeing throughout: no cause" do
    o = [old(~D[1938-07-01], "in_force", in_force_from: ~D[1938-07-01])]
    n = [new(~D[1938-07-01], "in_force", in_force_from: ~D[1938-07-01])]
    assert LabelShadow.cause(@law, o, n, [], @today) == nil
  end

  test "a provision commenced after its law: in force from later, by the commencement" do
    o = [old(~D[1937-07-30], "in_force", in_force_from: ~D[1937-07-30])]

    n = [
      new(~D[1937-07-30], "prospective", to: ~D[1938-07-01]),
      new(~D[1938-07-01], "in_force", in_force_from: ~D[1938-07-01])
    ]

    assert LabelShadow.cause(
             @law,
             o,
             n,
             [change(:commenced, ~D[1938-07-01], [:commencement])],
             @today
           ) ==
             "today: in_force_from new later (commenced [law])"
  end

  test "old repealed with no repeal reaching the row: no repeal held" do
    o = [old(~D[1961-06-22], "repealed")]
    n = [new(~D[1962-04-01], "in_force", in_force_from: ~D[1962-04-01])]

    assert LabelShadow.cause(
             @law,
             o,
             n,
             [change(:commenced, ~D[1962-04-01], [:commencement])],
             @today
           ) ==
             "today: status repealed→in_force (no repeal held)"
  end

  test "old unknown today" do
    assert LabelShadow.cause(@law, [], [new(~D[2020-12-31], "in_force")], [], @today) ==
             "today: old unknown, new in_force"
  end

  test "changed_by agrees when the old law is one of the new" do
    o = [old(~D[2010-01-01], "in_force", in_force_from: ~D[2010-01-01], changed_by: "A")]
    n = [new(~D[2010-01-01], "in_force", in_force_from: ~D[2010-01-01], changed_by: ["A", "B"])]
    assert LabelShadow.cause(@law, o, n, [], @today) == nil
  end

  test "today agrees, an earlier period differs: history" do
    o = [
      old(~D[2000-01-01], "prospective", to: ~D[2001-01-01]),
      old(~D[2001-01-01], "in_force", in_force_from: ~D[2001-01-01])
    ]

    n = [
      new(~D[2000-01-01], "in_force_partial", to: ~D[2001-01-01]),
      new(~D[2001-01-01], "in_force", in_force_from: ~D[2001-01-01])
    ]

    assert LabelShadow.cause(@law, o, n, [], @today) == "history: status"
  end

  test "territory on a Windsor Framework law is its own cause" do
    law = "UK_eur_2006_1907"
    o = [old(~D[2020-12-31], "in_force", territory: "E+W+S+NI")]
    n = [new(~D[2020-12-31], "in_force", territory: "E+W+S")]

    assert LabelShadow.cause(law, o, n, [], @today) == "today: territory Windsor E+W+S+NI→E+W+S"
  end
end
