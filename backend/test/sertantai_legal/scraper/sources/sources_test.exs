defmodule SertantaiLegal.Scraper.SourcesTest do
  @moduledoc """
  What a scope's labels need, and the report against what is held (CV-S01,
  agreed 2026-10-22): seven categories; missing items carry a reason;
  stale fails; our feed against the register's change statistics.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Sources

  # one family law, as the loader gives it
  @law %{
    law: "UK_uksi_2010_404",
    scope: ["/uksi/2010/404/body/data.xml"],
    effects: [
      %{affecting: "UK_uksi_2023_914", kind: "substituted"},
      %{affecting: "UK_uksi_2023_914", kind: "inserted"},
      %{affecting: "UK_ukpga_2022_30", kind: "repealed"},
      %{affecting: "UK_uksi_2023_993", kind: "commenced"},
      %{affecting: "UK_uksi_2010_404", kind: "other"}
    ],
    cited: ["UK_uksi_2011_1043"],
    register: %{effects: 5, laws: 4}
  }

  @amending %{
    "UK_uksi_2023_914" => %{enabling: ["UK_ukpga_1974_37"]},
    "UK_uksi_2011_1043" => %{enabling: []},
    "UK_ukpga_2022_30" => %{commenced_by: ["UK_uksi_2023_362"]}
  }

  test "the seven categories, one hop and a narrow second" do
    needs = Sources.needs(@law, @amending)
    by = Enum.group_by(needs, & &1.category, &{&1.law, &1.part})

    assert by[:own] == [{"UK_uksi_2010_404", "/uksi/2010/404/body/data.xml"}]
    assert by[:feed] == [{"UK_uksi_2010_404", :feed}]

    # the feed's text-change laws and the notes' cited laws, body and schedules
    assert Enum.sort(by[:amending]) ==
             Enum.sort(
               for l <- ["UK_uksi_2023_914", "UK_ukpga_2022_30", "UK_uksi_2011_1043"],
                   p <- [:body, :schedules],
                   do: {l, p}
             )

    assert by[:commencing] == [{"UK_uksi_2023_993", :body}, {"UK_uksi_2023_993", :schedules}]
    # an amending SI's introduction; an Act has none to read for powers
    assert Enum.sort(by[:introduction]) == [
             {"UK_uksi_2011_1043", :introduction},
             {"UK_uksi_2023_914", :introduction}
           ]

    assert by[:enabling_parent] == [{"UK_ukpga_1974_37", :body}]
    # row 7, narrow: an amending Act's own feed, and the orders it names as commencing it
    assert Enum.sort(by[:amending_commencing]) ==
             [
               {"UK_ukpga_2022_30", :feed},
               {"UK_uksi_2023_362", :body},
               {"UK_uksi_2023_362", :schedules}
             ]
  end

  test "the law itself is never its own amending law" do
    refute Enum.any?(
             Sources.needs(@law, @amending),
             &(&1.category == :amending and &1.law == "UK_uksi_2010_404")
           )
  end

  describe "the report" do
    defp need(category, law, part), do: %{category: category, law: law, part: part, for: "UK_x"}

    test "passes when every need is held, fresh, or absent upstream; fails on not fetched, incomplete or stale" do
      statuses = [
        {need(:own, "A", :body), :held},
        {need(:amending, "B", :schedules), :absent},
        {need(:amending, "C", :body), :not_fetched},
        {need(:feed, "D", :feed), :incomplete},
        {need(:amending, "E", :body), :stale}
      ]

      r = Sources.report(statuses, [])
      refute r.pass
      assert Enum.map(r.failures, & &1.law) |> Enum.sort() == ["C", "D", "E"]
      assert r.counts[:own] == %{held: 1}
      assert r.counts[:amending] == %{absent: 1, not_fetched: 1, stale: 1}

      assert Sources.report(
               [{need(:own, "A", :body), :held}, {need(:amending, "B", :schedules), :absent}],
               []
             ).pass
    end

    test "the feed against the register: equal passes; a difference fails until explained" do
      cmp = [
        %{law: "A", effects: 59, laws: 11, register: %{effects: 59, laws: 11}},
        %{law: "B", effects: 96, laws: 14, register: %{effects: 59, laws: 11}}
      ]

      r = Sources.report([], cmp)
      refute r.pass
      assert [%{law: "B"}] = r.register_differences

      assert Sources.report([], cmp, explained: %{"B" => "register scraped before 2025"}).pass
    end
  end

  test "our feed counted as the register counts it: no self-changes, no revocations (Amending.build_stats_with_self)" do
    effects = [
      %{affecting: "A", type: "words substituted"},
      %{affecting: "A", type: "inserted"},
      %{affecting: "B", type: "revoked"},
      %{affecting: "UK_x", type: "amended"},
      %{affecting: "C", type: "repealed in part"}
    ]

    assert Sources.register_counts("UK_x", effects) == %{effects: 2, laws: 1}
  end
end
