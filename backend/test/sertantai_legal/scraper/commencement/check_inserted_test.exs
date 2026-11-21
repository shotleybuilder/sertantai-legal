defmodule SertantaiLegal.Scraper.Commencement.CheckInsertedTest do
  @moduledoc """
  A provision another law inserted is judged by its inserting law's
  commencement, never by the host law's own clause (Decision 7 C, Jason
  2026-11-21: "inserted laws are dated by the law that inserts them"): the
  inserting change dated as the amending law's commencement gives it, its
  own dates set aside, beside the feed's record of it.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.Commencement.{Check, FeedDifferences, Rule}

  @amender "UK_ukpga_2015_20"

  defp change(target, claims),
    do: %Change{
      key: "k-#{target}",
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "k"})
    }

  defp inserted(target, feed_date, extra \\ []),
    do:
      change(
        target,
        [
          {:feed, :operation, :inserted},
          {:feed, :by, @amender},
          {:feed, :affecting, ["s.10"]},
          {:feed, :date, feed_date}
        ] ++ extra
      )

  defp rules(date),
    do: %{
      @amender => [
        Rule.new(
          commences: @amender,
          scope: ["s.10"],
          when: {:date, date},
          source: %{law: @amender, ref: "s.30", text: nil},
          treatment: :clause_date
        )
      ]
    }

  test "dated by the inserting law as the feed dates it: agree; otherwise: differ" do
    changes = [inserted("s.2(2A)", ~D[2015-12-18]), inserted("s.2(2B)", ~D[2016-01-01])]
    [a, b] = Check.inserted("UK_ukpga_1991_56", changes, rules(~D[2015-12-18]))

    assert %{id: "s.2(2A)", ours: {:dated, ~D[2015-12-18], :feed}, yardstick: :agree} = a
    assert %{id: "s.2(2B)", yardstick: :differ} = b
  end

  test "the inserting law's rules not held: the feed alone dates it" do
    [i] = Check.inserted("UK_ukpga_1991_56", [inserted("s.2(2A)", ~D[2015-12-18])], %{})
    assert %{ours: {:undated, :rules_not_held}, yardstick: :feed_only} = i
  end

  test "only insertions are judged; a substitution is not one" do
    sub =
      change("s.3", [
        {:feed, :operation, :substituted},
        {:feed, :by, @amender},
        {:feed, :affecting, ["s.10"]},
        {:feed, :date, ~D[2015-12-18]}
      ])

    assert Check.inserted("UK_ukpga_1991_56", [sub], rules(~D[2015-12-18])) == []
  end

  test "the own-clause gate leaves inserted rows out; their groups are the inserting law's" do
    row = %{
      law: "L",
      id: "s.2(2A)",
      yardstick: :differ,
      outcome: :dated,
      result: nil,
      full_from: ~D[1991-12-01],
      partial_from: nil,
      feed: {~D[2015-12-18], ~D[2015-12-18]},
      inserted: true
    }

    assert FeedDifferences.shape(row) == nil

    [i] = Check.inserted("L", [inserted("s.2(2A)", ~D[2015-12-18])], %{})

    assert [{"inserted | feed_only | ours undated: rules_not_held", %{rows: 1}}] =
             FeedDifferences.inserted_groups([i])
  end
end
