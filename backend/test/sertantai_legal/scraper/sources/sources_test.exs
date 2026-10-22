defmodule SertantaiLegal.Scraper.SourcesTest do
  @moduledoc """
  What a scope's labels need, and the report against what is held (CV-S01,
  agreed 2026-10-22): seven categories; missing items carry a reason;
  stale fails; our feed against the register's change statistics.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Sources

  # one family law, as the loader gives it: its amending laws, and the
  # gaps the feed leaves (from the stored changes)
  @law %{
    law: "UK_uksi_2010_404",
    scope: ["/uksi/2010/404/body/data.xml"],
    amenders: ["UK_uksi_2023_914", "UK_ukpga_2022_30", "UK_uksi_2011_1043", "UK_ukpga_1974_37"],
    gaps: [
      # gap A: in the feed, undated; made by an Act's s.47
      %{by: "UK_ukpga_2022_30", gap: :a, provisions: ["s.47(2)"]},
      # gap B: not in the feed at all
      %{by: "UK_uksi_2011_1043", gap: :b, provisions: ["sch.1.para.10(4)"]},
      %{by: "UK_ukpga_1974_37", gap: :b, provisions: []}
    ]
  }

  @amending %{
    # an SI stating its extent: no introduction needed
    "UK_uksi_2023_914" => %{clause: true, enabling: ["UK_ukpga_1974_37"], commencing: []},
    # an SI stating none: its powers, and their parent
    "UK_uksi_2011_1043" => %{clause: false, enabling: ["UK_ukpga_1972_68"], commencing: []},
    "UK_ukpga_2022_30" => %{
      clause: true,
      commencing: [
        %{order: "UK_uksi_2023_362", provisions: ["s.47"]},
        %{order: "UK_uksi_2023_999", provisions: ["s.12"]}
      ]
    },
    "UK_ukpga_1974_37" => %{
      clause: true,
      commencing: [%{order: "UK_uksi_1974_1439", provisions: ["s.15"]}]
    }
  }

  defp by(needs), do: Enum.group_by(needs, & &1.category, &{&1.law, &1.part})

  test "own text and feed; every amending law's body, for territory" do
    b = by(Sources.needs(@law, @amending))
    assert b[:own] == [{"UK_uksi_2010_404", "/uksi/2010/404/body/data.xml"}]
    assert b[:feed] == [{"UK_uksi_2010_404", :feed}]
    assert Enum.sort(b[:territory]) == Enum.sort(Enum.map(@law.amenders, &{&1, :body}))
  end

  test "enabling powers only for an SI stating no extent" do
    b = by(Sources.needs(@law, @amending))
    assert b[:introduction] == [{"UK_uksi_2011_1043", :introduction}]
    assert b[:enabling_parent] == [{"UK_ukpga_1972_68", :body}]
  end

  test "gap A: an Act's feed and only the orders commencing the provisions that made the changes" do
    b = by(Sources.needs(@law, @amending))

    assert Enum.sort(b[:dates]) == [
             {"UK_ukpga_2022_30", :feed},
             {"UK_uksi_2023_362", :body},
             {"UK_uksi_2023_362", :schedules}
           ]
  end

  test "gap B: body and schedules; an Act with no provisions named: every order its feed names" do
    b = by(Sources.needs(@law, @amending))

    assert Enum.sort(b[:backlog]) == [
             {"UK_ukpga_1974_37", :feed},
             {"UK_ukpga_1974_37", :schedules},
             {"UK_uksi_1974_1439", :body},
             {"UK_uksi_1974_1439", :schedules},
             {"UK_uksi_2011_1043", :schedules}
           ]
  end

  test "no gap, no need beyond the body: a feed-dated change's law needs no schedules or orders" do
    l = %{@law | gaps: []}
    b = by(Sources.needs(l, @amending))
    assert b[:dates] == nil and b[:backlog] == nil
  end

  test "the law itself is never its own amending law" do
    l = %{@law | amenders: ["UK_uksi_2010_404" | @law.amenders]}

    refute Enum.any?(
             Sources.needs(l, @amending),
             &(&1.category == :territory and &1.law == "UK_uksi_2010_404")
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

  describe "stale: could the register know of a newer version than the copy we hold? (CV-S01, Jason: \"Apply the stale fix\")" do
    @now ~U[2026-10-22 12:00:00Z]

    defp copy(valid, fetched), do: %{dct_valid: valid, fetched_at: fetched}

    test "the register last updated before we fetched: whatever it knew was already published — fresh (NI SR 1997/193)" do
      refute Sources.stale?(
               copy(~D[1997-03-28], ~U[2026-10-22 09:00:00Z]),
               ~D[1997-05-12],
               ~N[2026-10-19 08:40:11],
               @now
             )
    end

    test "the register updated since, and knows a later version than our copy: stale (a version published after our fetch)" do
      assert Sources.stale?(
               copy(~D[2025-01-01], ~U[2026-01-10 09:00:00Z]),
               ~D[2025-06-01],
               ~N[2026-09-30 10:00:00],
               @now
             )
    end

    test "the register updated since, but our copy is as new: fresh" do
      refute Sources.stale?(
               copy(~D[2025-06-01], ~U[2026-01-10 09:00:00Z]),
               ~D[2025-06-01],
               ~N[2026-09-30 10:00:00],
               @now
             )
    end

    test "no dates to compare: fresh while fetched within 30 days" do
      refute Sources.stale?(copy(nil, ~U[2026-10-01 09:00:00Z]), nil, nil, @now)
      assert Sources.stale?(copy(nil, ~U[2026-08-01 09:00:00Z]), nil, nil, @now)
    end
  end
end
