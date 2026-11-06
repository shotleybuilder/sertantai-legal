defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.EvidenceTest do
  @moduledoc """
  The evidence step's family gate (Maritime Safety: Evidence, Decision 1):
  each value conflict and each markup–feed disagreement, grouped by its
  attribute, sides and amending law, with its reviewed status; and the
  values no source claims, by cause.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Evidence, as: Gate

  @by "UK_uksi_2006_1244"
  @law "UK_ukpga_1995_21"

  defp change(key, target, claims) do
    %Change{
      key: key,
      target: target,
      aliases: [key],
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }
    |> Evidence.resolve(nil)
  end

  defp causes(changes),
    do: @law |> Gate.entries(changes) |> Enum.map(&{&1.cause, &1.by}) |> Enum.sort()

  test "a date conflict: the law's commencement against the feed, dates not in the cause" do
    c =
      change("key-a", "s.20", [
        {:law_text, :operation, :substituted},
        {:law_text, :by, @by},
        {:commencement, :date, ~D[2006-07-15]},
        {:feed, :operation, :substituted},
        {:feed, :by, @by},
        {:feed, :date, ~D[2008-11-21]}
      ])

    assert causes([c]) == [{"date: commencement against feed", @by}]
  end

  test "an operation conflict names both operations" do
    c =
      change("key-a", "s.20", [
        {:law_text, :operation, :repealed},
        {:law_text, :by, @by},
        {:feed, :operation, :substituted},
        {:feed, :by, @by}
      ])

    assert causes([c]) == [{"operation: law_text repealed against feed substituted", @by}]
  end

  test "a markup–feed disagreement with no primary claim names both values" do
    c =
      change("key-a", "s.20", [
        {:markup, :operation, :inserted},
        {:feed, :operation, :renumbered},
        {:feed, :by, @by}
      ])

    assert [{"operation: markup inserted against feed renumbered", @by}] = causes([c])
  end

  test "agreeing sources and single-source changes are no entry" do
    agree =
      change("key-a", "s.20", [
        {:law_text, :operation, :substituted},
        {:law_text, :by, @by},
        {:feed, :operation, :substituted},
        {:feed, :by, @by}
      ])

    alone = change("key-b", "s.21", [{:feed, :operation, :repealed}, {:feed, :by, @by}])
    assert causes([agree, alone]) == []
  end

  test "items take the reviewed status by law, else by cause, else inherited" do
    c =
      change("key-a", "s.20", [
        {:law_text, :operation, :repealed},
        {:law_text, :by, @by},
        {:feed, :operation, :substituted},
        {:feed, :by, @by}
      ])

    entries = Gate.entries(@law, [c])

    assert [%{status: nil}] = Gate.items(entries, %{})
    assert [%{status: "known: x"}] = Gate.items(entries, %{}, fn _ -> "known: x" end)

    two = Gate.entries(@law, [c, %{c | target: "s.21"}])
    statuses = fn e -> if e.target == "s.20", do: "known: a", else: "known: b" end
    assert [%{status: "known: a | known: b"}] = Gate.items(two, %{}, statuses)

    assert [%{status: nil}] =
             Gate.items(two, %{}, fn e -> if e.target == "s.20", do: "known: a" end)

    reviewed = %{"operation: law_text repealed against feed substituted @ #{@by}" => "known: y"}
    assert [%{status: "known: y"}] = Gate.items(entries, reviewed, fn _ -> "fix: z" end)
    assert %{pass?: true} = entries |> Gate.items(reviewed) |> Gate.gate()
    assert %{pass?: false} = entries |> Gate.items(%{}) |> Gate.gate()
  end

  test "gaps: the attributes no source claims, by the sources the change holds" do
    c = change("key-a", "s.20", [{:feed, :operation, :repealed}, {:feed, :by, @by}])

    assert %{{:date, "feed"} => 1, {:commenced_by, "feed"} => 1} = Gate.gaps([c])
    refute Map.has_key?(Gate.gaps([c]), {:by, "feed"})

    assert %{{:commenced_by, "feed; amending law has no commencement rules"} => 1} =
             Gate.gaps([c], MapSet.new())

    assert %{{:commenced_by, "feed"} => 1} = Gate.gaps([c], MapSet.new([@by]))
  end

  test "gap totals: each attribute's gaps, and those whose amending law has no commencement rules (Maritime Safety: Measures)" do
    gaps = %{
      {:commenced_by, "feed+law_text; amending law has no commencement rules"} => 3,
      {:commenced_by, "feed+law_text"} => 2,
      {:commenced_by, "feed; amending law has no commencement rules"} => 1,
      {:date, "feed+law_text"} => 4
    }

    assert Gate.gap_totals(gaps) == %{
             commenced_by: %{total: 6, no_rules: 4},
             date: %{total: 4, no_rules: 0}
           }
  end
end
