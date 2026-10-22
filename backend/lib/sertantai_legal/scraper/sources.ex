defmodule SertantaiLegal.Scraper.Sources do
  @moduledoc """
  What a scope's labels need from legislation.gov.uk, and the report against
  what is held (change vocabulary CV-S01, agreed with Jason 2026-10-22).
  Pure: the loader (`mix lat.sources`) reads the feeds, stored changes,
  caches and store and passes the facts in.

  Needed, sliced by the gap the feed leaves (Jason: "Are we slicing based
  on the defined gap after using the change feed" — "Yes"). A document is
  needed because a gap in the feed points to it, never only because it is
  one hop away:

  1. `:own` — each law's own text (its LAT scope's documents)
  2. `:feed` — its changes feed (every page)
  3. `:territory` — every amending law's body (its extent and application
     clauses: the feed is weak on territory for every change); for an SI
     stating no extent, its `:introduction` (enabling powers) and those
     powers' `:enabling_parent` Acts (body)
  4. `:dates` — gap A, a change the feed records with no date: an amending
     Act's own feed and the orders it names commencing the provisions that
     made those changes (an SI commences itself in its body, held under 3)
  5. `:backlog` — gap B, a change the feed doesn't record: the amending
     law's schedules too (the instruction itself), and for an Act, as in 4

  A document needed twice is counted once, under the first.

  The report passes when every need is held and fresh, or legislation.gov.uk
  has none (a stored 404: `:absent`); `:not_fetched`, `:incomplete` (a feed
  missing pages) and `:stale` (older than legislation.gov.uk's latest) fail
  ("Enforce stale now"). Each law's feed, counted as the register counts it
  (`register_counts/2`), is compared with the register's change statistics;
  a difference fails until explained.
  """

  alias SertantaiLegal.Scraper.LatRef

  @act_types ~w(ukpga asp anaw asc nia apni)
  @order ~w(own feed territory introduction enabling_parent dates backlog)a
  @failing [:not_fetched, :incomplete, :stale]

  @type need :: %{category: atom(), law: String.t(), part: atom() | String.t(), for: String.t()}
  @type status :: :held | :absent | :not_fetched | :incomplete | :stale
  @type gap :: %{by: String.t(), gap: :a | :b, provisions: [String.t()]}

  @doc """
  The documents one law needs. `law`: `%{law, scope, amenders, gaps}`
  (`scope` its document paths; `amenders` its amending laws; `gaps` the
  changes the feed leaves undated (`:a`) or doesn't record (`:b`), each with
  its amending law and the amending provisions named). `amending`: per
  amending law, `%{clause, enabling, commencing}` — whether it states its
  extent, an SI's enabling-power parents, and an Act's commencing orders
  from its own feed (`%{order, provisions}`).
  """
  @spec needs(map(), %{String.t() => map()}) :: [need()]
  def needs(%{law: law} = l, amending) do
    amenders = l.amenders |> Enum.reject(&(&1 == law)) |> Enum.uniq()
    sis = Enum.reject(amenders, &act?/1)
    unclaused = Enum.reject(sis, &get_in(amending, [&1, :clause]))
    gaps = Enum.reject(l.gaps, &(&1.by == law))

    [
      own: Enum.map(l.scope, &{law, &1}),
      feed: [{law, :feed}],
      territory: Enum.map(amenders, &{&1, :body}),
      introduction: Enum.map(unclaused, &{&1, :introduction}),
      enabling_parent:
        for(
          s <- unclaused,
          p <- get_in(amending, [s, :enabling]) || [],
          uniq: true,
          do: {p, :body}
        ),
      dates: commencing(Enum.filter(gaps, &(&1.gap == :a)), amending),
      backlog:
        for(%{gap: :b, by: b} <- gaps, uniq: true, do: {b, :schedules}) ++
          commencing(Enum.filter(gaps, &(&1.gap == :b)), amending)
    ]
    |> Enum.flat_map(fn {category, docs} ->
      Enum.map(docs, fn {x, part} -> %{category: category, law: x, part: part, for: law} end)
    end)
    |> Enum.uniq_by(&{&1.law, &1.part})
  end

  # an amending Act's own feed, and the orders it names commencing the
  # provisions that made the changes (every order, where none is named)
  defp commencing(gaps, amending) do
    gaps
    |> Enum.filter(&act?(&1.by))
    |> Enum.group_by(& &1.by, & &1.provisions)
    |> Enum.flat_map(fn {act, provisions} ->
      provisions = List.flatten(provisions)

      orders =
        for %{order: o, provisions: ps} <- get_in(amending, [act, :commencing]) || [],
            provisions == [] or ps == [] or related?(ps, provisions),
            uniq: true,
            do: o

      [{act, :feed} | for(o <- orders, p <- [:body, :schedules], do: {o, p})]
    end)
    |> Enum.uniq()
  end

  defp related?(as, bs),
    do:
      Enum.any?(as, fn a ->
        Enum.any?(bs, &(a in LatRef.ancestors(&1) or &1 in LatRef.ancestors(a)))
      end)

  defp act?(law), do: (String.split(law, "_") |> Enum.at(1)) in @act_types

  @doc """
  Whether a held copy is stale: could the register know of a newer version
  than the one we hold? (CV-S01; Jason: "Apply the stale fix".)

  - The register's record of the law last updated before we fetched the
    copy: whatever validity date it holds was already published when we
    fetched, so the copy is at least as new — fresh. (The register's
    validity date comes from the law's introduction, ours from the
    document's body; they can differ, as for NI SR 1997/193.)
  - Otherwise stale when the register's validity date is after the copy's
    (legislation.gov.uk publishes a revised version after the date it's
    valid from, so the fetch date alone can't decide).
  - With no dates to compare: fresh while fetched within 30 days.

  The register's update time moves for other reasons too: the rule can only
  err towards stale.
  """
  @spec stale?(map(), Date.t() | nil, NaiveDateTime.t() | nil, DateTime.t()) :: boolean()
  def stale?(%{dct_valid: copy, fetched_at: fetched}, register_valid, register_updated, now) do
    cond do
      register_updated != nil and fetched != nil and
          NaiveDateTime.compare(register_updated, DateTime.to_naive(fetched)) == :lt ->
        false

      is_struct(copy, Date) and is_struct(register_valid, Date) ->
        Date.compare(copy, register_valid) == :lt

      true ->
        DateTime.diff(now, fetched, :day) > 30
    end
  end

  @doc """
  A law's feed counted as the register counts it (`Amending`: the
  `🔻_stats_affected_by_count` and `…_laws_count` columns): effects by other
  laws that are not revocations (`LiveStatus.revocation?/1`), and their
  distinct laws.
  """
  @spec register_counts(String.t(), [%{affecting: String.t(), type: String.t() | nil}]) ::
          %{effects: non_neg_integer(), laws: non_neg_integer()}
  def register_counts(law, effects) do
    counted =
      Enum.reject(effects, fn e ->
        e.affecting == law or SertantaiLegal.Scraper.LiveStatus.revocation?(e.type || "")
      end)

    %{
      effects: length(counted),
      laws: counted |> Enum.map(& &1.affecting) |> Enum.uniq() |> length()
    }
  end

  @doc """
  The report: per category, the count of each status; the failures; the
  feeds that differ from the register's statistics (`comparisons`: `%{law,
  effects, laws, register: %{effects, laws}}`) unless `opts[:explained]`
  (law → reason) explains them; and whether it all passes.
  """
  @spec report([{need(), status()}], [map()], keyword()) :: map()
  def report(statuses, comparisons, opts \\ []) do
    explained = Keyword.get(opts, :explained, %{})

    counts =
      statuses
      |> Enum.group_by(fn {n, _} -> n.category end, fn {_, s} -> s end)
      |> Map.new(fn {c, ss} -> {c, Enum.frequencies(ss)} end)

    failures = for {n, s} <- statuses, s in @failing, do: Map.put(n, :status, s)

    differences =
      for c <- comparisons,
          c.register != nil,
          {c.effects, c.laws} != {c.register.effects, c.register.laws},
          not Map.has_key?(explained, c.law),
          do: c

    %{
      counts: counts,
      order: @order,
      failures: failures,
      register_differences: differences,
      pass: failures == [] and differences == []
    }
  end
end
