defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelStrataTest do
  @moduledoc """
  The label check's strata (CV-S09): the fold rules acting on a row
  (shapes, S), and where its periods differ from today's stored label
  (classes, T).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, LabelStrata}

  defp change(target, op, opts \\ []) do
    %Change{
      key: Keyword.get(opts, :key, "k-#{op}"),
      target: target,
      claims:
        for(
          {s, a, v} <- Keyword.get(opts, :claims, []),
          do: %Claim{source: s, attribute: a, value: v, ref: "k"}
        ),
      resolved: %Evidence.Resolved{
        operation: op,
        level: Keyword.get(opts, :level, :provision),
        territory: nil,
        date: Keyword.get(opts, :date, ~D[2010-01-01]),
        by: "UK_uksi_2010_1",
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }
  end

  defp period(from, status, opts \\ []) do
    %{
      valid_from: from,
      valid_to: Keyword.get(opts, :to),
      status: status,
      in_force_from: Keyword.get(opts, :in_force_from, if(status == :in_force, do: from)),
      changed_by: Keyword.get(opts, :changed_by, []),
      territory: Keyword.get(opts, :territory, "E+W+S"),
      tiers: %{}
    }
  end

  describe "shapes/3: the fold rules acting on a row" do
    test "status shapes: prospective, partly in force, repealed" do
      periods = [
        period(~D[2000-01-01], :prospective, to: ~D[2001-01-01]),
        period(~D[2001-01-01], :in_force_partial, to: ~D[2002-01-01]),
        period(~D[2002-01-01], :repealed, territory: "nowhere")
      ]

      shapes = LabelStrata.shapes("reg.3", periods, [])
      assert :prospective in shapes
      assert :partial in shapes
      assert :repealed in shapes
    end

    test "a territory taken out while the row stays in force (C1, C12)" do
      periods = [
        period(~D[2000-01-01], :in_force, to: ~D[2005-01-01]),
        period(~D[2005-01-01], :in_force, territory: "S")
      ]

      assert :territory_narrowed in LabelStrata.shapes("s.4", periods, [])
    end

    test "a territorial version (C3)" do
      assert :version in LabelStrata.shapes("s.23[E+W]", [period(~D[2000-01-01], :in_force)], [])
    end

    test "changes reaching it: application, renumbering, parts, an ancestor's, a text change" do
      reaching = [
        change("s.4", :applied),
        change("s.4", :renumbered),
        change("s.4", :commenced, key: "parts:s.4@2010-01-01"),
        change("pt.1", :repealed),
        change("s.4", :substituted)
      ]

      shapes = LabelStrata.shapes("s.4", [period(~D[2000-01-01], :in_force)], reaching)

      for s <- [:applied, :renumbered, :parts, :ancestor, :text_change], do: assert(s in shapes)
    end

    test "an ancestor's commencement is routine: no ancestor shape" do
      shapes =
        LabelStrata.shapes("s.4(1)", [period(~D[2000-01-01], :in_force)], [
          change("s.4", :commenced)
        ])

      refute :ancestor in shapes
    end

    test "several laws changing it one day (C5)" do
      periods = [period(~D[2000-01-01], :in_force, changed_by: ["UK_a", "UK_b"])]
      assert :several_laws in LabelStrata.shapes("s.4", periods, [])
    end

    test "a commencement for one territory, carried as in_force_for" do
      c = change("s.4", :commenced, claims: [{:feed, :in_force_for, "E+W+S"}])
      assert :in_force_for in LabelStrata.shapes("s.4", [period(~D[2000-01-01], :in_force)], [c])
    end

    test "gaps: a change no source dates, and a start no source dates (C10)" do
      undated = change("s.4", :substituted, date: nil)

      assert :undated_change in LabelStrata.shapes("s.4", [period(~D[2000-01-01], :in_force)], [
               undated
             ])

      start = [period(~D[2000-01-01], :in_force, in_force_from: nil)]
      assert :undated_start in LabelStrata.shapes("s.4", start, [])
    end

    test "a plain row in force, nothing reaching it: no shape" do
      assert LabelStrata.shapes("s.4", [period(~D[2000-01-01], :in_force)], []) == []
    end
  end

  describe "difference/2: where the fold differs from today's label" do
    defp today(from, status, opts \\ []) do
      %{
        valid_from: from,
        valid_to: Keyword.get(opts, :to),
        status: to_string(status),
        in_force_from: Keyword.get(opts, :in_force_from, if(status == :in_force, do: from)),
        changed_by: Keyword.get(opts, :changed_by),
        territory: Keyword.get(opts, :territory, "E+W+S")
      }
    end

    test "the same periods: no difference" do
      assert LabelStrata.difference([period(~D[2000-01-01], :in_force)], [
               today(~D[2000-01-01], :in_force)
             ]) == nil
    end

    test "no label today" do
      assert LabelStrata.difference([period(~D[2000-01-01], :in_force)], []) == "no_today"
    end

    test "the current period's fields that differ, in a fixed order" do
      assert LabelStrata.difference(
               [period(~D[2000-01-01], :repealed, territory: "nowhere")],
               [today(~D[2000-01-01], :in_force)]
             ) == "status+in_force_from+territory"
    end

    test "only earlier periods differ: history" do
      ours = [
        period(~D[2000-01-01], :prospective, to: ~D[2001-01-01]),
        period(~D[2001-01-01], :in_force)
      ]

      theirs = [today(~D[2001-01-01], :in_force)]
      assert LabelStrata.difference(ours, theirs) == "history"
    end

    test "today's single changed_by is one of the fold's several laws (C5): no difference" do
      ours = [period(~D[2000-01-01], :in_force, changed_by: ["UK_a", "UK_b"])]
      theirs = [today(~D[2000-01-01], :in_force, changed_by: "UK_b")]
      assert LabelStrata.difference(ours, theirs) == nil
    end
  end

  test "draw/3 is reproducible for a seed" do
    rows = for i <- 1..40, do: {"UK_x", "s.#{i}"}
    assert LabelStrata.draw(rows, 10, 7) == LabelStrata.draw(Enum.reverse(rows), 10, 7)
    refute LabelStrata.draw(rows, 10, 7) == LabelStrata.draw(rows, 10, 8)
  end
end
