defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedRangeSequenceTest do
  @moduledoc """
  A range a feed effect makes (inserted, or substituted whole) with
  lettered ends ("reg. 19A-19F", "s. 1(6A)-(6C)") covers the provisions of
  its ends' own sequence: 19B to 19E, (6B). A provision named by a deeper
  suffix (19AA, 19AZA, (6AA)) that the feed records another law inserting
  was put between them later and is not in the range (Fire and OH&S: Feed
  reader). The law's own deeper-lettered provisions, a range with plain
  numbers at both ends, and a later change to a lettered range, are as
  before.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, FeedRange}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(text, {a, b}, type \\ "inserted", by \\ "UK_uksi_2011_1885"),
    do: %Effect{
      effect_id: "key-" <> text,
      type: type,
      affected_provisions: text,
      affected_refs: [a, b],
      affected_ranges: [{a, b}],
      affecting: by
    }

  defp one(text, ref, by),
    do: %Effect{
      effect_id: "key-" <> text,
      type: "inserted",
      affected_provisions: text,
      affected_refs: [ref],
      affecting: by
    }

  # the targets of the first effect, read with the others of its feed
  defp targets([e | _] = effects, law, order),
    do:
      for(
        {key, target, _} <- Feed.read(effects, law, order),
        String.starts_with?(key, e.effect_id),
        uniq: true,
        do: target
      )

  describe "a range the effect makes" do
    # SI 2009/1348 "reg. 19A-19F", inserted by SI 2011/1885; regs 19AA,
    # 19AB, 19AZA, 19BA-19BC, 19CA and 19CB were put between them later,
    # by SI 2020/1111 and SI 2021/1370
    test "lettered regulations: those another law inserts later are not in the range" do
      order =
        ~w(19 19AZA 19A 19AA 19AB 19B 19BA 19BB 19BC 19C 19CA 19CB 19D 19E 19F 20)
        |> Enum.map(&("regulation-" <> &1))

      effects = [
        effect("reg. 19A-19F", {"regulation-19A", "regulation-19F"}),
        one("reg. 19AZA", "regulation-19AZA", "UK_uksi_2021_1370"),
        effect(
          "reg. 19AA-19AB",
          {"regulation-19AA", "regulation-19AB"},
          "inserted",
          "UK_uksi_2020_1111"
        ),
        # a range's middle (19BB) is inserted with its ends
        effect(
          "reg. 19BA-19BC",
          {"regulation-19BA", "regulation-19BC"},
          "inserted",
          "UK_uksi_2020_1111"
        ),
        effect(
          "reg. 19CA-19CB",
          {"regulation-19CA", "regulation-19CB"},
          "inserted",
          "UK_uksi_2020_1111"
        )
      ]

      assert targets(effects, "UK_uksi_2009_1348", order) ==
               ~w(reg.19A reg.19B reg.19C reg.19D reg.19E reg.19F)
    end

    # Occupiers' Liability Act 1984 s. 1(6A)-(6C), inserted by 2000 c. 37;
    # s. 1(6AA) was inserted by 2009 c. 23
    test "lettered subsections: (6AA) is not in (6A)-(6C)" do
      order = ~w(section-1 section-1-6 section-1-6A section-1-6AA section-1-6B section-1-6C)

      effects = [
        effect("s. 1(6A)-(6C)", {"section-1-6A", "section-1-6C"}, "inserted", "UK_ukpga_2000_37"),
        one("s. 1(6AA)", "section-1-6AA", "UK_ukpga_2009_23")
      ]

      assert targets(effects, "UK_ukpga_1984_3", order) == ["s.1(6A)", "s.1(6B)", "s.1(6C)"]
    end

    # Animals (Scientific Procedures) Act 1986 "s. 5-5G", substituted for
    # s. 5 by SI 2012/3039; s. 5BA was inserted by SI 2026/663
    test "substituted whole: the run it made" do
      order = ~w(section-5 section-5A section-5B section-5BA section-5C)

      effects = [
        effect(
          "s. 5-5C",
          {"section-5", "section-5C"},
          "substituted for s. 5",
          "UK_uksi_2012_3039"
        ),
        one("s. 5BA", "section-5BA", "UK_uksi_2026_663")
      ]

      assert targets(effects, "UK_ukpga_1986_14", order) == ~w(s.5 s.5A s.5B s.5C)
    end

    # TCPA 1990 "s. 174(2A)-(2B)", substituted by 2023 c. 55 for (2A) and
    # (2B): its text makes (2A), (2AA), (2AB), (2AC) and (2B)
    test "the law's own deeper-lettered provisions stay" do
      order = ~w(2 2A 2AA 2AB 2AC 2B 2C) |> Enum.map(&("section-174-" <> &1))
      ends = {"section-174-2A", "section-174-2B"}

      alone = [
        effect("s. 174(2A)-(2B)", ends, "substituted for s. 174(2A)(2B)", "UK_ukpga_2023_55")
      ]

      all = ["s.174(2A)", "s.174(2AA)", "s.174(2AB)", "s.174(2AC)", "s.174(2B)"]
      assert targets(alone, "UK_ukpga_1990_8", order) == all

      # and one the same law's own effect inserts (asp 2024/15 on asp
      # 2009/12 s. 33(1)-(2A), with s. 33(2ZA))
      own = alone ++ [one("s. 174(2AA)", "section-174-2AA", "UK_ukpga_2023_55")]
      assert targets(own, "UK_ukpga_1990_8", order) == all
    end

    test "a range of plain numbers is every provision between, lettered ones too" do
      order = ~w(regulation-3 regulation-3A regulation-4 regulation-4AA regulation-5)

      effects = [
        effect("reg. 3-5", {"regulation-3", "regulation-5"}),
        one("reg. 4AA", "regulation-4AA", "UK_uksi_2020_1111")
      ]

      assert targets(effects, "UK_uksi_2009_1348", order) == ~w(reg.3 reg.3A reg.4 reg.4AA reg.5)
    end
  end

  describe "a later change to a lettered range" do
    # Local Government Act 1972 "s. 100A-100K (Pt. 5A)" applied, modified:
    # s. 100BA and s. 100EA, then between the ends, are reached
    test "applied, repealed or its words changed: every provision between" do
      order = ~w(section-100A section-100B section-100BA section-100C)
      ends = {"section-100A", "section-100C"}

      for type <- ["applied", "repealed", "words substituted", "modified"] do
        effects = [
          effect("s. 100A-100C", ends, type),
          one("s. 100BA", "section-100BA", "UK_ukpga_1985_43")
        ]

        assert targets(effects, "UK_ukpga_1972_70", order) == ~w(s.100A s.100B s.100BA s.100C)
      end
    end
  end

  describe "member?/3" do
    test "no deeper than the deeper end" do
      assert FeedRange.member?("regulation-19B", "regulation-19A", "regulation-19F")
      refute FeedRange.member?("regulation-19AA", "regulation-19A", "regulation-19F")
      refute FeedRange.member?("regulation-19AZA", "regulation-19A", "regulation-19F")
      assert FeedRange.member?("section-27AA", "section-27A", "section-27AB")
      refute FeedRange.member?("section-27AAA", "section-27A", "section-27AB")
    end

    test "a plain number between lettered ends stays (s. 6A-8 holds s. 7 and s. 7A)" do
      assert FeedRange.member?("section-7", "section-6A", "section-8")
      assert FeedRange.member?("section-7A", "section-6A", "section-8")
      refute FeedRange.member?("section-7AA", "section-6A", "section-8")
    end

    test "plain-number ends, and names without a number, are left alone" do
      assert FeedRange.member?("regulation-4AA", "regulation-3", "regulation-7")
      assert FeedRange.member?("section-1-iii", "section-1-i", "section-1-iv")
      assert FeedRange.member?("section-1-aa", "section-1-a", "section-1-c")
      assert FeedRange.member?("crossheading-fees", "section-6A", "section-6C")
    end
  end
end
