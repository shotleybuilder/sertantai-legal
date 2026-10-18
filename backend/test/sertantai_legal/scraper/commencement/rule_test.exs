defmodule SertantaiLegal.Scraper.Commencement.RuleTest do
  @moduledoc "CR-01: a commencement rule — what it brings into force, when, where, how far, from what."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Rule

  @src %{
    law: "UK_uksi_2017_469",
    ref: "art.1(2)",
    text: "This article … come into force on the day after the day on which the Order is made."
  }

  describe "new/1" do
    test "builds a rule; nil territory and purposes mean everywhere, fully" do
      rule =
        Rule.new(
          commences: "UK_uksi_2017_469",
          scope: ["art.1", "art.2", "art.11"],
          when: {:after, :made, {1, :day}},
          source: @src,
          treatment: :made_relative
        )

      assert %Rule{scope: ["art.1", "art.2", "art.11"], except: [], territory: nil, purposes: nil} =
               rule
    end

    test "scope is :all, :rest or a list of refs (a range is \"from..to\")" do
      for scope <- [:all, :rest, ["s.1..s.5", "pt.2.ch.1", "sch.13.para.70(a)"]] do
        assert %Rule{scope: ^scope} =
                 Rule.new(
                   commences: "UK_ukpga_1995_21",
                   scope: scope,
                   when: :unread,
                   source: @src,
                   treatment: :unread
                 )
      end

      assert_raise ArgumentError, fn ->
        Rule.new(
          commences: "UK_ukpga_1995_21",
          scope: [],
          when: :unread,
          source: @src,
          treatment: :unread
        )
      end
    end

    test "when is one of date / after / named_day / appointed / with / unread" do
      for w <- [
            {:date, ~D[1996-01-01]},
            {:after, :passed, {2, :month}},
            {:named_day, :exit_day},
            {:appointed, "by order"},
            {:with, "UK_ukpga_2014_21:s.10"},
            :unread
          ] do
        assert %Rule{when: ^w} =
                 Rule.new(
                   commences: "UK_ukpga_1995_21",
                   scope: :all,
                   when: w,
                   source: @src,
                   treatment: :t
                 )
      end

      assert_raise ArgumentError, fn ->
        Rule.new(
          commences: "UK_ukpga_1995_21",
          scope: :all,
          when: {:sunset, ~D[2030-01-01]},
          source: @src,
          treatment: :t
        )
      end
    end

    test "purposes is one of the four (Jason 2026-10-18)" do
      for p <- [nil, :for_making_secondary_legislation, :in_relation_to, :for_specified_purposes] do
        assert %Rule{purposes: ^p} =
                 Rule.new(
                   commences: "UK_ukpga_1995_25",
                   scope: ["s.57"],
                   when: {:date, ~D[2000-04-01]},
                   purposes: p,
                   source: @src,
                   treatment: :order_date
                 )
      end

      assert_raise ArgumentError, fn ->
        Rule.new(
          commences: "UK_ukpga_1995_25",
          scope: ["s.57"],
          when: :unread,
          purposes: :other,
          source: @src,
          treatment: :t
        )
      end
    end

    test "full?: no territory and no purposes" do
      full = Rule.new(commences: "L", scope: :all, when: :unread, source: @src, treatment: :t)
      assert Rule.full?(full)
      refute Rule.full?(%{full | territory: "E"})
      refute Rule.full?(%{full | purposes: :for_specified_purposes})
    end
  end

  describe "to_text/1 — one readable line" do
    test "the uksi 2017/469 pair" do
      first =
        Rule.new(
          commences: "UK_uksi_2017_469",
          scope: ["art.1", "art.2", "art.11"],
          when: {:after, :made, {1, :day}},
          source: @src,
          treatment: :made_relative
        )

      rest =
        Rule.new(
          commences: "UK_uksi_2017_469",
          scope: :rest,
          when: {:date, ~D[2017-05-08]},
          source: %{@src | text: "Otherwise this Order comes into force on 8th May 2017."},
          treatment: :clause_date
        )

      assert Rule.to_text(first) ==
               "art.1, art.2, art.11 — made + 1 day — everywhere, fully — made_relative — UK_uksi_2017_469 art.1(2): “This article … come into force on the day after the day on which the Order is made.”"

      assert Rule.to_text(rest) =~ "rest — 2017-05-08 — everywhere, fully — clause_date"
    end

    test "territory, purposes, except and the other whens" do
      r =
        Rule.new(
          commences: "UK_ukpga_1995_25",
          scope: ["s.57"],
          except: ["s.57(2)"],
          when: {:date, ~D[2000-04-01]},
          territory: "E",
          purposes: :for_specified_purposes,
          source: %{law: "UK_uksi_2000_340", ref: "art.2", text: "x"},
          treatment: :order_date
        )

      assert Rule.to_text(r) =~
               "s.57 except s.57(2) — 2000-04-01 — E, for specified purposes — order_date — UK_uksi_2000_340 art.2"

      line =
        &Rule.to_text(
          Rule.new(commences: "L", scope: :all, when: &1, source: @src, treatment: :t)
        )

      assert line.({:named_day, :exit_day}) =~ "all — exit day —"
      assert line.({:after, :passed, {2, :month}}) =~ "— passed + 2 months —"
      assert line.({:appointed, "by order"}) =~ "— appointed (by order) —"
      assert line.({:with, "UK_ukpga_2014_21:s.10"}) =~ "— with UK_ukpga_2014_21:s.10 —"
      assert line.(:unread) =~ "— unread —"
    end
  end

  describe "to_row/1 and from_row/1" do
    test "round trip every when, scope and purposes" do
      for w <- [
            {:date, ~D[1996-01-01]},
            {:after, :made, {1, :day}},
            {:after, :passed, {2, :month}},
            {:named_day, :ip_completion_day},
            {:appointed, "by notice"},
            {:with, "UK_ukpga_2014_21:s.10"},
            :unread
          ],
          scope <- [:all, :rest, ["s.1..s.5", "s.7"]],
          p <- [nil, :in_relation_to] do
        rule =
          Rule.new(
            commences: "UK_ukpga_1995_21",
            scope: scope,
            except: ["s.3"],
            when: w,
            territory: "E+W",
            purposes: p,
            source: @src,
            treatment: :clause_date
          )

        assert rule |> Rule.to_row() |> Rule.from_row() == rule
      end
    end

    test "a row's columns are plain values (for the table)" do
      row =
        Rule.to_row(
          Rule.new(
            commences: "L",
            scope: ["s.1"],
            when: {:after, :made, {1, :day}},
            source: @src,
            treatment: :made_relative
          )
        )

      assert %{
               commences: "L",
               scope_kind: "refs",
               scope: ["s.1"],
               when_kind: "after",
               when_basis: "made",
               when_offset: "1 day",
               when_date: nil,
               treatment: "made_relative",
               source_law: "UK_uksi_2017_469",
               source_ref: "art.1(2)"
             } = row
    end
  end
end
