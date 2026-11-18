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

  # Fire and OH&S: Store and build (2026-11-16): the Planning (Wales) Act
  # 2015's s.58(2) counts from Royal Assent, which neither the register nor
  # its body's metadata gives; its introduction states it ("{6 July 2015}")
  test "royal assent: an amending Act with no date held needs its introduction; never an SI or a dated Act" do
    law = %{@law | amenders: ["UK_anaw_2015_4", "UK_ukpga_1974_37", "UK_uksi_2011_1043"]}

    amending =
      @amending
      |> Map.put("UK_anaw_2015_4", %{clause: true, commencing: [], dated: false})
      |> put_in(["UK_ukpga_1974_37", :dated], true)
      |> put_in(["UK_uksi_2011_1043", :dated], false)

    assert by(Sources.needs(law, amending))[:royal_assent] ==
             [{"UK_anaw_2015_4", "/anaw/2015/4/introduction/data.xml"}]
  end

  test "royal assent: the law itself, an Act with no date held, needs its introduction" do
    law = Map.merge(@law, %{law: "UK_anaw_2015_4", amenders: [], gaps: [], dated: false})

    assert by(Sources.needs(law, %{}))[:royal_assent] ==
             [{"UK_anaw_2015_4", "/anaw/2015/4/introduction/data.xml"}]

    refute by(Sources.needs(%{law | dated: true}, %{}))[:royal_assent]
    refute by(Sources.needs(@law, @amending))[:royal_assent]
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

  # Fire and OH&S: Labels side by side (2026-11-17): the Water Industry
  # (Scotland) Act 2002's own feed names no order commencing it, so its
  # changes to EPA 1990 s.53 stayed undated (amending-act-orders-not-held).
  # Its own clause leaves "the rest" to orders; an Act dating its provisions
  # itself needs none (Decision 1 b, Waste, Water and Climate: Sources)
  describe "gap A or B: an Act whose feed names no order for the provisions (amending-act-orders-not-held)" do
    @asp %{law: "UK_ukpga_1990_43", scope: [], amenders: ["UK_asp_2002_3"], gaps: []}
    @listed ["UK_ssi_2002_118", "UK_ssi_2004_530"]

    # `by_order`: its own clause leaves provisions to orders (true), dates
    # them all itself (false), or is not read yet (nil)
    defp asp(gap, orders, by_order),
      do:
        {%{@asp | gaps: [%{by: "UK_asp_2002_3", gap: gap, provisions: ["sch.7.para.21"]}]},
         %{
           "UK_asp_2002_3" => %{clause: true, commencing: [], orders: orders, by_order: by_order}
         }}

    test "its clause leaves provisions to orders: every order on its list, with its schedules" do
      {law, amending} = asp(:a, @listed, true)

      assert Enum.sort(by(Sources.needs(law, amending))[:dates]) == [
               {"UK_asp_2002_3", :feed},
               {"UK_ssi_2002_118", :body},
               {"UK_ssi_2002_118", :schedules},
               {"UK_ssi_2004_530", :body},
               {"UK_ssi_2004_530", :schedules}
             ]
    end

    test "its clause leaves provisions to orders and no list is held: the list, searched at --fetch" do
      {law, amending} = asp(:b, nil, true)
      assert {"UK_asp_2002_3", :orders} in by(Sources.needs(law, amending))[:backlog]
    end

    test "its clause dates every provision itself: no order" do
      {law, amending} = asp(:a, @listed, false)
      assert by(Sources.needs(law, amending))[:dates] == [{"UK_asp_2002_3", :feed}]
    end

    test "its clause not read yet: the list only, never its orders" do
      {law, amending} = asp(:a, nil, nil)

      assert Enum.sort(by(Sources.needs(law, amending))[:dates]) ==
               [{"UK_asp_2002_3", :feed}, {"UK_asp_2002_3", :orders}]

      {law, amending} = asp(:a, @listed, nil)
      assert by(Sources.needs(law, amending))[:dates] == [{"UK_asp_2002_3", :feed}]
    end

    test "a feed naming an order for the provisions: that order only, never the list" do
      {law, amending} = asp(:a, @listed, true)

      amending =
        put_in(amending, ["UK_asp_2002_3", :commencing], [
          %{order: "UK_ssi_2004_530", provisions: ["sch.7.para.21"]}
        ])

      assert Enum.sort(by(Sources.needs(law, amending))[:dates]) == [
               {"UK_asp_2002_3", :feed},
               {"UK_ssi_2004_530", :body},
               {"UK_ssi_2004_530", :schedules}
             ]
    end

    test "order_list_status/1: held once searched (an empty list too), else not fetched" do
      assert Sources.order_list_status(["UK_ssi_2002_118"]) == :held
      assert Sources.order_list_status([]) == :held
      assert Sources.order_list_status(nil) == :not_fetched
    end
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

  describe "own text: the documents the build and the readers read (scoped-law-body-not-needed)" do
    test "a scoped law needs its body, never its fragments: the rows are cut to the scope" do
      scope = %{"fragments" => ["section/1", "section/12"]}
      assert Sources.own_paths("ukpga/1971/40", scope) == ["/ukpga/1971/40/body/data.xml"]
    end

    test "a whole law needs its body; an excluded or empty scope needs nothing" do
      assert Sources.own_paths("uksi/2010/404", nil) == ["/uksi/2010/404/body/data.xml"]
      assert Sources.own_paths("uksi/2010/404", %{"excluded" => true}) == []
      assert Sources.own_paths("uksi/2010/404", %{"fragments" => []}) == []
    end
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

  describe "the loader's facts, read pure" do
    alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}

    defp change(by, claims, aliases \\ []) do
      %Change{
        key: "k",
        target: "s.1",
        resolved: %{by: by, operation: :substituted},
        aliases: aliases,
        claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: "k"})
      }
    end

    test "doc_path/2: a law's body, its schedules, or a path as given" do
      assert Sources.doc_path("UK_ukpga_1974_37", :body) == "/ukpga/1974/37/body/data.xml"

      assert Sources.doc_path("UK_uksi_2008_1597", :schedules) ==
               "/uksi/2008/1597/schedules/data.xml"

      assert Sources.doc_path("UK_uksi_2008_1597", "/x/y") == "/x/y"
    end

    test "document_status/3: held, stale, absent, not fetched" do
      now = ~U[2026-11-03 12:00:00Z]
      fresh = %{dct_valid: ~D[2026-10-01], fetched_at: ~U[2026-10-30 00:00:00Z]}
      assert Sources.document_status({:ok, "xml", fresh}, {~D[2026-09-01], nil}, now) == :held
      assert Sources.document_status({:ok, "xml", fresh}, {~D[2026-10-20], nil}, now) == :stale
      assert Sources.document_status({:missing, %{}}, {nil, nil}, now) == :absent
      assert Sources.document_status(:none, {nil, nil}, now) == :not_fetched
    end

    # enabling-cache-empty-counts-held (Maritime Safety: Extent reader): an
    # empty cache is a failed or pre-store fetch unless the introduction is
    # held and names no powers
    test "introduction_status/2: an empty cache is held only when the introduction is stored" do
      powers = [%{"law" => "UK_ukpga_1990_43", "provisions" => ["s.140"]}]
      assert Sources.introduction_status({:ok, powers}, :not_held) == :held
      assert Sources.introduction_status({:ok, []}, {:ok, []}) == :held
      assert Sources.introduction_status({:ok, []}, :not_held) == :not_fetched
      assert Sources.introduction_status(:none, :not_held) == :not_fetched
      # legislation.gov.uk has no introduction (SI 1992/682: both paths 404)
      assert Sources.introduction_status({:ok, []}, :absent) == :absent
    end

    test "change_facts/1: amending laws, and gap A (undated in the feed) or B (not in the feed)" do
      undated =
        change("UK_uksi_2000_1", [
          {:feed, :operation, :substituted},
          {:feed, :affecting, ["reg. 2"]}
        ])

      unrecorded =
        change(nil, [{:markup, :cited, "UK_uksi_2001_2"}, {:markup, :affecting, ["reg. 3"]}])

      dated =
        change("UK_uksi_2002_3", [
          {:feed, :operation, :substituted},
          {:feed, :date, ~D[2002-01-01]}
        ])

      facts = Sources.change_facts([undated, unrecorded, dated])
      assert facts.amenders == ["UK_uksi_2000_1", "UK_uksi_2001_2", "UK_uksi_2002_3"]

      assert facts.gaps == [
               %{by: "UK_uksi_2000_1", gap: :a, provisions: ["reg. 2"]},
               %{by: "UK_uksi_2001_2", gap: :b, provisions: ["reg. 3"]}
             ]
    end
  end

  describe "the loader's facts, read pure (Environmental Protection: Measures)" do
    test "commencing_orders: an Act's orders and the provisions each commences, from its own feed" do
      law = "UK_ukpga_2021_30"

      effects = [
        %{type: "coming into force", affecting: "UK_uksi_2022_1", affected_provisions: "s. 2"},
        # its own commencement, an amendment, a record with no law: none an order
        %{type: "coming into force", affecting: law, affected_provisions: "s. 3"},
        %{type: "substituted", affecting: "UK_uksi_2022_2", affected_provisions: "s. 4"},
        %{type: "coming into force", affecting: nil, affected_provisions: "s. 5"}
      ]

      assert [%{order: "UK_uksi_2022_1", provisions: [_ | _]}] =
               Sources.commencing_orders(effects, law)
    end

    test "clause?: an amending law states its extent when its rules hold a default or a list" do
      clauses = %{
        "UK_uksi_2023_1" => %{default: "E+W", lists: []},
        "UK_uksi_2023_2" => %{default: nil, lists: [%{}]},
        "UK_uksi_2023_3" => %{default: nil, lists: []}
      }

      assert Sources.clause?(clauses, "UK_uksi_2023_1")
      assert Sources.clause?(clauses, "UK_uksi_2023_2")
      refute Sources.clause?(clauses, "UK_uksi_2023_3")
      refute Sources.clause?(clauses, "UK_uksi_2023_4")
    end

    test "feed_status: fresh while recently fetched; else absent, not fetched or missing pages" do
      now = ~U[2026-11-11 12:00:00Z]
      page = fn fetched -> {:ok, "<feed/>", %{dct_valid: nil, fetched_at: fetched}} end

      assert Sources.feed_status({:ok, []}, page.(~U[2026-11-01 00:00:00Z]), now) == :held
      assert Sources.feed_status({:ok, []}, page.(~U[2026-09-01 00:00:00Z]), now) == :stale
      assert Sources.feed_status({:ok, []}, :none, now) == :held
      assert Sources.feed_status({:error, "x"}, :none, now) == :not_fetched
      assert Sources.feed_status({:error, "x"}, {:missing, %{}}, now) == :absent
      assert Sources.feed_status({:error, "x"}, page.(now), now) == :incomplete
    end

    test "register_stats: the register's change statistics, or nil when it holds none" do
      assert Sources.register_stats([[12, 3]]) == %{effects: 12, laws: 3}
      assert Sources.register_stats([[nil, nil]]) == nil
      assert Sources.register_stats([]) == nil
    end
  end
end
