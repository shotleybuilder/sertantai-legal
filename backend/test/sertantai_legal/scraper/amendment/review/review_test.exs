defmodule SertantaiLegal.Scraper.Amendment.ReviewTest do
  @moduledoc """
  The amending-law reader's review tooling (Amending-law reader: review
  tooling): the gate's dump, the standard statuses, the rule diff by
  field and one provision's probe, each on hand-built data.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Review.{GateDump, Probe, RuleDiff, StandardStatus}
  alias SertantaiLegal.Scraper.Amendment.Rule

  @act "UK_ukpga_1990_43"
  @amending "UK_uksi_2016_1154"
  @fixture "test/fixtures/amendment_patterns/disagreements.json"

  defp rule(ref, opts \\ []),
    do:
      Rule.new(
        amends: opts[:amends] || @act,
        targets: opts[:targets] || ["s.33(1)"],
        operation: opts[:operation] || :substituted,
        level: opts[:level] || :words,
        source: %{law: @amending, ref: ref, text: "for “x” substitute “y”"},
        treatment: opts[:treatment] || :instruction
      )

  describe "the gate's dump" do
    @groups %{
      {"law text only: repealed words", @amending} => [{@act, :a}, {@act, :b}, {@act, :c}],
      {"unjoined", "UK_uksi_2010_675"} => [{@act, :d}]
    }

    test "unnamed groups first, each with its key, status, reach and up to `per` changes" do
      reviewed = %{"unjoined @ UK_uksi_2010_675" => "known: the merge's"}
      item = fn {law, c}, i -> %{"n" => i, "law" => law, "change" => c} end

      assert [unnamed, named] = GateDump.dump(@groups, reviewed, item, 2)

      assert %{
               "key" => "law text only: repealed words @ " <> @amending,
               "named" => false,
               "status" => nil,
               "reach" => 3,
               "changes" => [%{"n" => 1, "change" => :a}, %{"n" => 2, "change" => :b}]
             } = unnamed

      assert %{"named" => true, "status" => "known: the merge's", "reach" => 1} = named

      assert [_, _] =
               GateDump.dump(@groups, %{}, item, :all)
               |> hd()
               |> Map.fetch!("changes")
               |> Enum.take(2)

      assert 3 ==
               GateDump.dump(@groups, %{}, item, :all)
               |> hd()
               |> Map.fetch!("changes")
               |> length()
    end
  end

  describe "the standard statuses" do
    test "each standard cause's wording, citing the review; the by-design causes cite their rule" do
      r = "backend/data/reports/amending-reader/x-gate-review-1.md"

      assert StandardStatus.propose("law text only: repealed words", r) ==
               "known: legislation.gov.uk holds no record of it; the reading is right (review: #{r})"

      assert StandardStatus.propose("no operation from legislation.gov.uk: inserted words", r) =~
               ~s(records the change with no operation (the feed's "amended", legacy markup\); the reading is right (review: #{r}\))

      assert StandardStatus.propose("unjoined", r) =~ "(Merge's)"
      assert StandardStatus.propose("operation repealed/repealed_in_part", r) =~ ~s("in part")

      assert StandardStatus.propose("quote-new-number", r) =~
               "RULES.md quote-new-numbers-are-inserted"
    end

    test "a value conflict and a one-law wording have none: left by hand" do
      failing = [
        %{shape: "operation inserted/substituted", law: @amending},
        %{shape: "law text only: inserted words", law: @amending}
      ]

      assert %{
               proposed: [{"law text only: inserted words @ " <> @amending, "known: " <> _}],
               by_hand: ["operation inserted/substituted @ " <> @amending]
             } = StandardStatus.proposals(failing, "r.md")
    end

    test "written with sorted keys, the reviewed fixture as it stands is written back byte for byte" do
      body = File.read!(@fixture)
      assert StandardStatus.write(Jason.decode!(body), []) == body
    end

    test "a proposal is added in its sorted place" do
      out = StandardStatus.write(%{"b" => "known: 2", "d" => "known: 4"}, [{"c", "known: 3"}])
      assert out == ~s({\n  "b": "known: 2",\n  "c": "known: 3",\n  "d": "known: 4"\n}\n)
    end
  end

  describe "the rule diff by field" do
    test "a removed and an added rule from one provision pair, naming the fields that differ" do
      old = [rule("regulation-2-3"), rule("regulation-2-4")]

      new = [
        rule("regulation-2-3", level: :provision, operation: :repealed),
        rule("regulation-2-4")
      ]

      assert [%{fields: [:operation, :level], source: "regulation-2-3"}] =
               RuleDiff.pairs(old, new)
    end

    test "targets compare in any order; a rule with no partner is removed or added" do
      assert RuleDiff.pairs([rule("a", targets: ["s.1", "s.2"])], [
               rule("a", targets: ["s.2", "s.1"])
             ]) == []

      assert [%{fields: :removed, source: "a"}, %{fields: :added, source: "b"}] =
               RuleDiff.pairs([rule("a")], [rule("b")])
    end

    test "a run's pairs group by field set, the largest first" do
      by_amending = %{
        @amending =>
          RuleDiff.pairs([rule("a"), rule("b")], [
            rule("a", level: :provision),
            rule("b", level: :provision)
          ]),
        "UK_uksi_2010_675" => RuleDiff.pairs([rule("c")], [])
      }

      assert [
               %{"fields" => "level", "count" => 2, "pairs" => [p | _]},
               %{"fields" => "removed", "count" => 1}
             ] =
               groups = RuleDiff.grouped(by_amending)

      assert %{
               "before" => %{"level" => "words"},
               "after" => %{"level" => "provision"},
               "words" => "for “x” substitute “y”"
             } = p

      assert RuleDiff.lines(groups) == ["    2  level", "    1  removed"]
    end
  end

  describe "one provision's probe" do
    @text %Text{
      id: "regulation-2-3",
      instruction: "In section 33(1), for “x” substitute “y”.",
      quoted: "y",
      inserted: [],
      context: ["Amendment of the Environmental Protection Act 1990"],
      parents: ["2. The Environmental Protection Act 1990 is amended as follows."]
    }

    test "its words, the stored rules and a fresh reading; the same when they agree" do
      lines =
        Probe.lines(@amending, "regulation-2-3", @text, [rule("regulation-2-3")], [
          rule("regulation-2-3")
        ])

      assert hd(lines) == "#{@amending} regulation-2-3"
      assert "  instruction: In section 33(1), for “x” substitute “y”." in lines
      assert "  quoted: y" in lines
      assert List.last(lines) == "  the same"
    end

    test "a fresh reading that differs is flagged; a provision not in the document says so" do
      lines = Probe.lines(@amending, "regulation-2-3", @text, [rule("regulation-2-3")], [])
      assert "  fresh reading: no rules" in lines
      assert List.last(lines) =~ "DIFFERENT"

      assert ["#{@amending} regulation-9: not in the document", "  stored: no rules"] ==
               Probe.lines(@amending, "regulation-9", nil, [], [])
    end
  end
end
