defmodule SertantaiLegal.Scraper.ChangeVocabulary.Gate.LabelTest do
  @moduledoc """
  The label fold's family gate (Maritime Safety: Label fold, Decision 1):
  each breach of the table's rules and of the label rules, grouped by its
  rule and the row's law, with its reviewed status; and the gaps by shape.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Label, as: Gate

  @law "UK_ukpga_1995_21"
  @amender "UK_ukpga_1997_28"

  defp p(from, opts \\ []),
    do: %{
      valid_from: from,
      valid_to: Keyword.get(opts, :to),
      status: Keyword.get(opts, :status, :in_force),
      in_force_from: from,
      changed_by: Keyword.get(opts, :by, []),
      commenced_by: [],
      territory: "E+W+S+NI"
    }

  defp row(sid, periods),
    do: %{id: sid, sid: "#{@law}:#{sid}", periods: periods, reaching: []}

  defp ctx(_row),
    do: %{
      made: nil,
      law_start: nil,
      eu: false,
      windsor: false,
      made_of: %{@amender => ~D[1997-03-19]},
      existed: fn _ -> false end
    }

  defp causes(rows, known \\ MapSet.new()),
    do: @law |> Gate.entries(rows, &ctx/1, known) |> Enum.map(&{&1.cause, &1.by, &1.target})

  test "a label rule's breach is an entry under its rule and the row's law" do
    early = row("s.20", [p(~D[1996-01-01], by: [@amender])])
    fine = row("s.21", [p(~D[1998-01-01], by: [@amender])])

    assert causes([early, fine]) == [{"before_amender", @law, "#{@law}:s.20"}]
  end

  test "a break of the table's rules is an entry under `table: <why>`" do
    overlap = row("s.20", [p(~D[1996-01-01], to: ~D[1999-01-01]), p(~D[1998-01-01])])

    assert causes([overlap]) == [{"table: overlap", @law, "#{@law}:s.20"}]
  end

  test "an empty field carrying a tier is an entry under `tier: empty field` (tier-per-field; the agent pass)" do
    leak = Map.put(p(~D[1995-07-19], status: :prospective), :in_force_from, nil)
    leak = Map.put(leak, :tiers, %{in_force_from: :primary, changed_by: nil})
    clean = Map.put(leak, :tiers, %{in_force_from: nil, changed_by: nil})

    assert causes([row("s.20", [leak])]) == [{"tier: empty field", @law, "#{@law}:s.20"}]
    assert causes([row("s.21", [clean])]) == []
  end

  test "a row started by a Part's insertion after its own: `start: a container's insertion after its own` (MSA 1995 s.130B(4))" do
    own = %Change{
      key: "k",
      target: "s.130B",
      resolved: %Evidence.Resolved{
        operation: :inserted,
        level: :provision,
        territory: nil,
        date: ~D[1997-03-19],
        by: @amender,
        retained: false,
        partial: false,
        saved: false,
        sources: %{}
      }
    }

    part = %{own | target: "pt.VI", resolved: %{own.resolved | date: ~D[1997-07-17]}}
    # the Part's insertion reaches the row as its container (the law's changes)
    late =
      Map.put(%{row("s.130B(4)", [p(~D[1997-07-17])]) | reaching: [own]}, :changes, [own, part])

    on_time =
      Map.put(%{row("s.130B(5)", [p(~D[1997-03-19])]) | reaching: [own]}, :changes, [own, part])

    new_part = Map.put(row("s.130F", [p(~D[1997-07-17])]), :changes, [part])

    assert causes([late, on_time, new_part]) == [
             {"start: a container's insertion after its own", @law, "#{@law}:s.130B(4)"}
           ]
  end

  test "a row listed as a known limit is left out" do
    early = row("s.20", [p(~D[1996-01-01], by: [@amender])])
    assert causes([early], MapSet.new(["#{@law}:s.20"])) == []
  end

  test "items take the reviewed status by law, else by rule; the gate passes when all are known" do
    entries = Gate.entries(@law, [row("s.20", [p(~D[1996-01-01], by: [@amender])])], &ctx/1)

    assert [%{status: nil, reach: 1}] = Gate.items(entries, %{})
    assert [%{status: "known: x"}] = Gate.items(entries, %{"before_amender" => "known: x"})

    by_law = %{"before_amender @ #{@law}" => "known: y", "before_amender" => "fix: z"}
    assert [%{status: "known: y"}] = Gate.items(entries, by_law)
    assert %{pass?: true} = entries |> Gate.items(by_law) |> Gate.gate()
    assert %{pass?: false} = entries |> Gate.items(%{}) |> Gate.gate()
  end

  test "gaps: the rows of each gap shape" do
    assert Gate.gaps([[:undated_start, :text_change], [:undated_change], [:partial]]) == %{
             undated_start: 1,
             undated_change: 1
           }
  end
end
