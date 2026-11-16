defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelStagesTest do
  @moduledoc """
  The chosen stages folded (`Label.Stages`; Fire and OH&S: Label fold,
  Decision 2 a): a change takes its first stage, each later stage commences
  its target.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Label}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Label.Stages

  @law "UK_ukpga_1974_37"
  @maker "UK_ukpga_2013_32"
  @order "UK_uksi_2014_251"

  defp stage(date, opts),
    do:
      Map.merge(
        %{date: date, partial: false, commenced_by: nil, in_force_for: nil, qualification: nil},
        Map.new(opts)
      )

  defp change(target, op, date, source, stages, opts \\ []) do
    %Change{
      key: "k-#{target}-#{op}",
      target: target,
      claims:
        for(
          {s, a, v} <- Keyword.get(opts, :claims, []),
          do: %Claim{source: s, attribute: a, value: v, ref: "k"}
        ),
      resolved: %Evidence.Resolved{
        operation: op,
        level: Keyword.get(opts, :level, :provision),
        territory: Keyword.get(opts, :territory),
        date: date,
        by: Keyword.get(opts, :by, @maker),
        commenced_by: Keyword.get(opts, :commenced_by),
        retained: false,
        partial: Keyword.get(opts, :partial, false),
        saved: false,
        stages: stages,
        sources: %{operation: :law_text, level: :law_text, date: source, commenced_by: source},
        tiers: %{
          operation: :primary,
          date: if(source == :feed, do: :derived, else: :primary),
          commenced_by: if(source == :feed, do: :derived, else: :primary)
        }
      }
    }
  end

  defp fold(id, changes, provision \\ %{}),
    do:
      Label.fold(
        id,
        Map.merge(%{law: @law, extent: "E+W+S", start: ~D[1975-01-01]}, provision),
        changes
      )

  defp brief(periods),
    do:
      Enum.map(
        periods,
        &{&1.valid_from, &1.status, &1.in_force_from, &1.changed_by, &1.commenced_by,
         &1.territory}
      )

  describe "a commencement-dated insertion with a partial then a full stage" do
    # 2013 c.32 Sch.12 para.86(3) inserts HSWA s.61(7A): in relation to some
    # purposes from 2014-03-10 by SI 2014/251, fully from 2014-04-01
    setup do
      stages = [
        stage(~D[2014-03-10],
          partial: true,
          commenced_by: @order,
          qualification: "in_relation_to"
        ),
        stage(~D[2014-04-01], commenced_by: @order)
      ]

      %{
        changes: [
          change("s.61(7A)", :inserted, ~D[2014-04-01], :commencement, stages,
            commenced_by: @order
          )
        ]
      }
    end

    test "partly in force from the first stage, in force from the full one", %{changes: changes} do
      assert "s.61(7A)" |> fold(changes) |> brief() == [
               {~D[2014-03-10], :in_force_partial, nil, [], [], "E+W+S"},
               {~D[2014-04-01], :in_force, ~D[2014-04-01], [@maker], [@order], "E+W+S"}
             ]
    end

    test "a stage's tier is its source's: the commencement's, primary", %{changes: changes} do
      [first, full] = fold("s.61(7A)", changes)
      assert first.tiers.status == :primary
      assert full.tiers.status == :primary
      assert full.tiers.in_force_from == :primary
      assert full.tiers.commenced_by == :primary
    end

    test "unfolds once: the change at its first stage, the later stage a commencement of its target",
         %{changes: changes} do
      assert [first, later] = Stages.unfold(changes)
      assert {first.resolved.date, first.resolved.partial} == {~D[2014-03-10], true}
      assert first.resolved.stages == nil

      assert %{operation: :commenced, date: ~D[2014-04-01], partial: false, commenced_by: @order} =
               later.resolved

      assert later.target == "s.61(7A)"
      assert Stages.unfold([first, later]) == [first, later]
    end
  end

  describe "a feed text change with one day and two orders for two territories" do
    # the Fire Safety Order 2005's words by the Building Safety Act 2022:
    # SI 2023/362 except in relation to W., WSI 2023/914 for W., 2023-10-01
    setup do
      stages = [
        stage(~D[2023-10-01],
          partial: true,
          commenced_by: "UK_uksi_2023_362",
          qualification: "territory + except"
        )
        |> Map.put(:in_force_except, "W"),
        stage(~D[2023-10-01],
          partial: true,
          commenced_by: "UK_wsi_2023_914",
          in_force_for: "W",
          qualification: "territory"
        )
      ]

      words =
        change("art.9(1)", :substituted, ~D[2023-10-01], :feed, stages,
          level: :words,
          partial: true,
          by: "UK_ukpga_2022_30",
          commenced_by: "UK_uksi_2023_362"
        )

      %{changes: [change_start("*"), words]}
    end

    defp change_start(target),
      do: %Change{
        key: "UK_uksi_2005_1541:commencement:1",
        target: target,
        resolved: %Evidence.Resolved{
          operation: :commenced,
          level: :provision,
          territory: nil,
          date: ~D[2006-10-01],
          by: "UK_uksi_2005_1541",
          retained: false,
          partial: false,
          saved: false,
          sources: %{operation: :law, level: :law}
        }
      }

    test "one version that day, both orders in commenced_by, the row still in force", %{
      changes: changes
    } do
      provision = %{law: "UK_uksi_2005_1541", extent: "E+W", start: ~D[2006-10-01]}

      assert "art.9(1)" |> fold(changes, provision) |> brief() == [
               {~D[2006-10-01], :in_force, ~D[2006-10-01], [], [], "E+W"},
               {~D[2023-10-01], :in_force, ~D[2023-10-01], ["UK_ukpga_2022_30"],
                ["UK_uksi_2023_362", "UK_wsi_2023_914"], "E+W"}
             ]
    end

    test "the feed's stages are derived", %{changes: changes} do
      provision = %{law: "UK_uksi_2005_1541", extent: "E+W", start: ~D[2006-10-01]}
      version = "art.9(1)" |> fold(changes, provision) |> List.last()
      assert version.tiers.commenced_by == :derived
    end

    test "a later stage of a words change is the change again, never a commencement of the provision",
         %{changes: [_start, words]} do
      assert [first, later] = Stages.unfold([words])
      assert Enum.map([first, later], & &1.resolved.operation) == [:substituted, :substituted]
      assert later.resolved.commenced_by == "UK_wsi_2023_914"
      assert later.resolved.territory == "W"
      assert first.key != later.key
    end

    # golden: TCPA 1990 s.284(3)(a), anaw 2015/4's words 2015-09-06, WSI 2016/52
    test "a later day's stage opens nothing: one version from the first stage" do
      stages = [
        stage(~D[2014-03-10], partial: true, commenced_by: @order, qualification: "purposes"),
        stage(~D[2014-04-01], commenced_by: "UK_uksi_2014_900", qualification: "complete")
      ]

      changes = [
        change_start("*"),
        change("art.9(2)", :inserted, ~D[2014-03-10], :feed, stages, level: :words, partial: true)
      ]

      provision = %{law: "UK_uksi_2005_1541", extent: "E+W", start: ~D[2006-10-01]}

      assert "art.9(2)" |> fold(changes, provision) |> brief() == [
               {~D[2006-10-01], :in_force, ~D[2006-10-01], [], [], "E+W"},
               {~D[2014-03-10], :in_force, ~D[2014-03-10], [@maker], [@order], "E+W"}
             ]
    end
  end

  describe "a partial-only stage list" do
    test "an insertion never fully commenced stays partly in force" do
      stages = [
        stage(~D[2014-03-10],
          partial: true,
          commenced_by: @order,
          qualification: "in_relation_to"
        ),
        stage(~D[2015-01-01],
          partial: true,
          commenced_by: "UK_uksi_2014_3000",
          qualification: "in_relation_to"
        )
      ]

      changes = [
        change("s.61(7B)", :inserted, ~D[2014-03-10], :commencement, stages, partial: true)
      ]

      assert "s.61(7B)" |> fold(changes) |> brief() == [
               {~D[2014-03-10], :in_force_partial, nil, [], [], "E+W+S"}
             ]
    end

    test "one territory then another (C13): in force there, widening" do
      stages = [
        stage(~D[2000-04-01], partial: true, in_force_for: "E", commenced_by: "UK_uksi_2000_340"),
        stage(~D[2001-07-01], partial: true, in_force_for: "W", commenced_by: "UK_wsi_2001_2197")
      ]

      changes = [
        change("s.78A", :inserted, ~D[2000-04-01], :commencement, stages,
          partial: true,
          by: "UK_ukpga_1995_25"
        )
      ]

      assert "s.78A" |> fold(changes, %{extent: "E+W"}) |> brief() == [
               {~D[2000-04-01], :in_force, ~D[2000-04-01], ["UK_ukpga_1995_25"],
                ["UK_uksi_2000_340"], "E"},
               {~D[2001-07-01], :in_force, ~D[2001-07-01], ["UK_ukpga_1995_25"],
                ["UK_wsi_2001_2197"], "E+W"}
             ]
    end

    test "a date later than every stage is the full stage" do
      stages = [stage(~D[2014-03-10], partial: true, qualification: "in_relation_to")]
      changes = [change("s.61(7C)", :inserted, ~D[2014-04-01], :commencement, stages)]

      assert [
               {~D[2014-03-10], :in_force_partial, nil, [], [], _},
               {~D[2014-04-01], :in_force, ~D[2014-04-01], [@maker], [], _}
             ] = "s.61(7C)" |> fold(changes) |> brief()
    end
  end

  describe "a staged removal (as `Readers.Feed.staged_removal/2`)" do
    @erra "UK_ukpga_2013_24"

    defp hswa_start,
      do: %Change{
        key: "#{@law}:commencement:1",
        target: "*",
        resolved: %Evidence.Resolved{
          operation: :commenced,
          level: :provision,
          territory: nil,
          date: ~D[1975-01-01],
          by: @law,
          retained: false,
          partial: false,
          saved: false,
          sources: %{operation: :law, level: :law}
        }
      }

    # HSWA s.47(5), omitted by ERRA 2013 for specified purposes 2013-04-25,
    # wholly 2013-10-01
    test "a removal in part at the partial stage, the repeal at the full one" do
      stages = [
        stage(~D[2013-04-25],
          partial: true,
          commenced_by: @erra,
          qualification: "in_relation_to"
        ),
        stage(~D[2013-10-01], commenced_by: "UK_uksi_2013_2227")
      ]

      removal =
        change("s.47(5)", :repealed, ~D[2013-10-01], :commencement, stages,
          by: @erra,
          commenced_by: "UK_uksi_2013_2227"
        )

      assert [in_part, full] = Stages.unfold([removal])

      assert %{operation: :repealed_in_part, partial: true, date: ~D[2013-04-25]} =
               in_part.resolved

      assert in_part.resolved.commenced_by == @erra
      assert %{operation: :repealed, partial: false, date: ~D[2013-10-01]} = full.resolved
      assert full.key == removal.key and in_part.key != removal.key
      assert Stages.unfold([in_part, full]) == [in_part, full]

      assert [
               {~D[1975-01-01], :in_force, _, _, _, _},
               {~D[2013-04-25], :in_force_partial, nil, [], [], _},
               {~D[2013-10-01], :repealed, nil, [@erra], [], "nowhere"}
             ] = "s.47(5)" |> fold([hswa_start(), removal], %{shows_text: true}) |> brief()
    end

    # Petroleum Act 1998 s.17A (E+W+S+NI), repealed for E+W+S by the
    # Energy Act 2004: for some purposes 2004-09-01, wholly 2004-10-05
    test "a removal for a territory: its in-part stages are dropped, so the rest stays in force" do
      stages = [
        stage(~D[2004-09-01],
          partial: true,
          commenced_by: "UK_uksi_2004_2184",
          qualification: "in_relation_to"
        ),
        stage(~D[2004-10-05], commenced_by: "UK_uksi_2004_2575")
      ]

      removal =
        change("s.47(5)", :repealed, ~D[2004-10-05], :commencement, stages,
          territory: "E+W+S",
          commenced_by: "UK_uksi_2004_2575"
        )

      assert [full] = Stages.unfold([removal])
      assert %{operation: :repealed, date: ~D[2004-10-05], territory: "E+W+S"} = full.resolved

      assert [
               {~D[1975-01-01], :in_force, _, _, _, _},
               {~D[2004-10-05], :in_force, _, _, _, "NI"}
             ] =
               "s.47(5)"
               |> fold([hswa_start(), removal], %{extent: "E+W+S+NI", shows_text: true})
               |> brief()
    end

    test "stages all partial: it stays removed in part" do
      stages = [
        stage(~D[2013-04-25],
          partial: true,
          commenced_by: @erra,
          qualification: "in_relation_to"
        ),
        stage(~D[2014-01-01], partial: true, in_force_for: "S", qualification: "in_relation_to")
      ]

      removal =
        change("s.47(6)", :repealed, ~D[2013-04-25], :commencement, stages,
          by: @erra,
          partial: true
        )

      assert [first, second] = Stages.unfold([removal])
      assert Enum.all?([first, second], &(&1.resolved.operation == :repealed_in_part))
      assert first.key == removal.key
      assert second.resolved.territory == "S"

      assert [{_, :in_force, _, _, _, _}, {~D[2013-04-25], :in_force_partial, _, _, _, _}] =
               "s.47(6)" |> fold([hswa_start(), removal], %{shows_text: true}) |> brief()
    end

    # EPA 1990 s.143, repealed by EA 1995 for S then for E+W
    test "a stage for one territory alone repeals it there (C13's twin): gone once every territory is" do
      stages = [
        stage(~D[2000-04-01], partial: true, in_force_for: "S"),
        stage(~D[2000-07-14], partial: true, in_force_for: "E+W")
      ]

      removal =
        change("s.143", :repealed, ~D[2000-04-01], :commencement, stages,
          by: "UK_ukpga_1995_25",
          partial: true
        )

      assert [
               {_, :in_force, _, _, _, "E+W+S"},
               {~D[2000-04-01], :in_force, _, _, _, "E+W"},
               {~D[2000-07-14], :repealed, nil, ["UK_ukpga_1995_25"], [], "nowhere"}
             ] = "s.143" |> fold([hswa_start(), removal]) |> brief()
    end

    # EPA 1990 s.75(2)(a): the old one removed by EA 1995 in stages from
    # 2005, a new one inserted for S in 2011 by SSI 2011/226, an "in
    # relation to" stage in 2015
    test "its stages never reach a provision made again after the removal began: not unfolded" do
      stages = [
        stage(~D[2005-01-01], partial: true, in_force_for: "S"),
        stage(~D[2006-05-15], partial: true, in_force_for: "E+W"),
        stage(~D[2015-04-01], partial: true, in_force_for: "S", qualification: "in_relation_to")
      ]

      removal =
        change("s.75(2)(a)", :repealed, ~D[1995-07-19], :commencement, stages,
          by: "UK_ukpga_1995_25",
          partial: true
        )

      again =
        change("s.75(2)(a)", :inserted, ~D[2011-03-27], :law_text, nil,
          by: "UK_ssi_2011_226",
          territory: "S"
        )

      assert Stages.unfold([removal, again]) == [removal, again]
      assert length(Stages.unfold([removal])) == 4

      before = %{removal | resolved: %{removal.resolved | stages: nil}}

      assert fold("s.75(2)(a)", [removal, again], %{extent: "S"}) ==
               fold("s.75(2)(a)", [before, again], %{extent: "S"})
    end

    test "resolved as whole with no full stage read: the repeal stands on its date" do
      stages = [stage(~D[1984-12-01], partial: true, commenced_by: "UK_ukpga_1984_55")]
      removal = change("s.61", :repealed, ~D[1984-12-01], :commencement, stages)

      assert [%{resolved: %{operation: :repealed, date: ~D[1984-12-01]}}] =
               Stages.unfold([removal])
    end

    test "words repealed by stages are a text change: one version from the first stage" do
      stages = [
        stage(~D[2013-04-25],
          partial: true,
          commenced_by: @erra,
          qualification: "in_relation_to"
        ),
        stage(~D[2013-10-01], commenced_by: "UK_uksi_2013_2227")
      ]

      words =
        change("s.47(2)", :repealed, ~D[2013-10-01], :commencement, stages, level: :words)

      assert [%{resolved: %{operation: :repealed, level: :words, date: ~D[2013-04-25]}}] =
               Stages.unfold([words])
    end
  end
end
