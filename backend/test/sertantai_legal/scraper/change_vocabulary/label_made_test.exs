defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelMadeTest do
  @moduledoc "A law made, not yet in force (LR-39; CV-06): prospective from its making until its start."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Made

  @law "UK_nisr_1993_37"
  @made ~D[1993-02-03]
  @start ~D[1993-03-08]

  defp provision(opts \\ []),
    do:
      Map.merge(
        %{law: @law, start: @start, start_dated: true, made: @made, extent: "NI"},
        Map.new(opts)
      )

  defp in_force(from),
    do: %{
      valid_from: from,
      valid_to: nil,
      status: :in_force,
      in_force_from: from,
      changed_by: [],
      commenced_by: [],
      territory: "NI",
      tiers: %{}
    }

  defp commenced(key, opts \\ []) do
    %Change{
      key: key,
      target: "reg.18",
      resolved: %Evidence.Resolved{
        operation: Keyword.get(opts, :op, :commenced),
        level: :provision,
        territory: nil,
        date: Keyword.get(opts, :date, @start),
        by: Keyword.get(opts, :by),
        commenced_by: Keyword.get(opts, :commenced_by),
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }
  end

  @own "UK_nisr_1993_37:commencement:reg.18@1993-03-08"

  test "commenced by its own law's clause: prospective from the making" do
    [made, first] = Made.from([in_force(@start)], provision(), @start, [commenced(@own)])
    assert {made.valid_from, made.valid_to, made.status} == {@made, @start, :prospective}
    assert made.in_force_from == nil and made.territory == "NI"
    assert first.valid_from == @start
  end

  test "a first period already prospective reaches back to the making" do
    first = %{
      in_force(@start)
      | status: :prospective,
        in_force_from: nil,
        valid_to: ~D[1994-01-01]
    }

    assert [%{valid_from: @made, valid_to: ~D[1994-01-01]}] =
             Made.from([first], provision(), @start, [])
  end

  test "dated otherwise: an order's commencement, an insertion, a later start, no made date" do
    periods = [in_force(@start)]
    order = commenced("x", commenced_by: "UK_nisr_1993_99")
    insertion = commenced("y", op: :inserted)

    assert Made.from(periods, provision(), @start, [order]) == periods
    assert Made.from(periods, provision(), @start, [insertion]) == periods
    assert Made.from(periods, provision(), ~D[1995-01-01], []) == periods
    assert Made.from(periods, provision(made: nil), @start, []) == periods
    assert Made.from(periods, provision(start_dated: false), @start, []) == periods
  end
end
