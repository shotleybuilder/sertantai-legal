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

  alias SertantaiLegal.Scraper.AmendingLaw.Pointer
  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.{EffectKind, LatRef, LatScope}

  @act_types ~w(ukpga asp anaw asc nia apni)
  @order ~w(own feed territory introduction enabling_parent dates backlog)a
  @failing [:not_fetched, :incomplete, :stale]

  @type need :: %{category: atom(), law: String.t(), part: atom() | String.t(), for: String.t()}
  @type status :: :held | :absent | :not_fetched | :incomplete | :stale
  @type gap :: %{by: String.t(), gap: :a | :b, provisions: [String.t()]}

  @doc """
  A law's own text: the documents the build (`Build.body/1`) and the readers
  read. A scoped law needs its body, never its fragments: its rows are cut
  to the scope from the body (`LatScope.cut/2`). An excluded or empty scope
  needs nothing (scoped-law-body-not-needed, Fire and OH&S: Sources).
  """
  @spec own_paths(String.t(), map() | nil) :: [String.t()]
  def own_paths(slash_path, scope), do: LatScope.fetch_paths(slash_path, scope, true)

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

  @doc "A needed document's store path: a law's body, its schedules, or a path as given."
  @spec doc_path(String.t(), atom() | String.t()) :: String.t()
  def doc_path(law, part) do
    [_, type, year, number] = String.split(law, "_", parts: 4)

    case part do
      :body -> "/#{type}/#{year}/#{number}/body/data.xml"
      :schedules -> "/#{type}/#{year}/#{number}/schedules/data.xml"
      path when is_binary(path) -> path
    end
  end

  @doc """
  A law's text changes (stored changes, `mix lat.vocabulary --build`) read
  for what its sources need: its amending laws, and the gaps the feed
  leaves — `:a` the feed records the change with no date, `:b` the feed
  doesn't record it — each with its amending law and the amending
  provisions named (the feed's, the note's, or the law's own rule key).
  """
  @spec change_facts([Change.t()]) :: %{amenders: [String.t()], gaps: [gap()]}
  def change_facts(changes) do
    amenders =
      changes
      |> Enum.flat_map(&[&1.resolved.by, Change.value(&1, :markup, :cited)])
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    gaps =
      for c <- changes,
          by = c.resolved.by || Change.value(c, :markup, :cited),
          by != nil,
          gap = gap(c),
          gap != nil,
          do: %{by: by, gap: gap, provisions: provisions(c)}

    %{amenders: amenders, gaps: gaps}
  end

  defp gap(c) do
    cond do
      Change.values(c, :feed, :operation) == [] -> :b
      Change.values(c, :feed, :date) == [] and Change.values(c, :feed, :date_first) == [] -> :a
      true -> nil
    end
  end

  defp provisions(c) do
    named = Change.value(c, :feed, :affecting) || Change.value(c, :markup, :affecting)

    cond do
      named != nil ->
        named

      true ->
        for a <- c.aliases,
            [_, id] <- [String.split(a, ":", parts: 2)],
            ref = Order.ref(id),
            ref != nil,
            do: ref
    end
  end

  @doc """
  A stored document's status from the store's answer (`ClmlStore.get/1`):
  held and fresh, stale against the register's `{valid date, updated}`,
  absent (a stored 404), or not fetched.
  """
  @spec document_status(term(), {Date.t() | nil, NaiveDateTime.t() | nil}, DateTime.t()) ::
          status()
  def document_status({:ok, _, meta}, {register_valid, register_updated}, now),
    do: if(stale?(meta, register_valid, register_updated, now), do: :stale, else: :held)

  def document_status({:missing, _}, _register, _now), do: :absent
  def document_status(:none, _register, _now), do: :not_fetched

  @doc """
  An SI's introduction's status from its enabling cache
  (`EnablingCache.cached/1`) and the introduction stored
  (`EnablingCache.from_store/1`, or `:absent` where every path is a stored
  404): held when the cache names powers, or when it is empty and the
  introduction is stored (it names none); absent where legislation.gov.uk
  has none; an empty cache with no introduction stored is a failed or
  pre-store fetch, not fetched (`enabling-cache-empty-counts-held`).
  """
  @spec introduction_status({:ok, [map()]} | :none, {:ok, [map()]} | :absent | :not_held) ::
          status()
  def introduction_status({:ok, [_ | _]}, _stored), do: :held
  def introduction_status({:ok, []}, {:ok, _}), do: :held
  def introduction_status(_cached, :absent), do: :absent
  def introduction_status(_cached, _stored), do: :not_fetched

  @doc """
  A feed's status from its fetch from the store (`ChangesFeed.fetch/4`,
  `store: :only`) and the store's answer for its first page: a feed carries
  no valid date, so it is fresh while recently fetched (`stale?/4`); one
  not read whole is absent (a stored 404), not fetched, or missing pages.
  """
  @spec feed_status({:ok, list()} | term(), term(), DateTime.t()) :: status()
  def feed_status({:ok, _}, {:ok, _, meta}, now),
    do: if(stale?(meta, nil, nil, now), do: :stale, else: :held)

  def feed_status({:ok, _}, _page, _now), do: :held
  def feed_status(_feed, :none, _now), do: :not_fetched
  def feed_status(_feed, {:missing, _}, _now), do: :absent
  def feed_status(_feed, _page, _now), do: :incomplete

  @doc """
  An Act's commencing orders from its own feed's effects, each with the
  provisions it commences: a commencement by another named law.
  """
  @spec commencing_orders([map()], String.t()) :: [%{order: String.t(), provisions: [String.t()]}]
  def commencing_orders(effects, law) do
    for e <- effects,
        EffectKind.kind(e.type, nil) == "commenced",
        is_binary(e.affecting),
        e.affecting != law,
        do: %{
          order: e.affecting,
          provisions:
            e.affected_provisions |> Pointer.refs_in() |> Enum.flat_map(&Pointer.to_refs/1)
        }
  end

  @doc "Whether an amending law states its extent: its stored rules hold a default or a list."
  @spec clause?(%{String.t() => map()}, String.t()) :: boolean()
  def clause?(clauses, law) do
    case Map.get(clauses, law) do
      %{default: d, lists: ls} -> d != nil or ls != []
      _ -> false
    end
  end

  @doc "The register's change statistics from its row (effects, laws), nil when it holds none."
  @spec register_stats([[integer() | nil]]) :: %{effects: integer(), laws: integer()} | nil
  def register_stats([[e, l]]) when is_integer(e), do: %{effects: e, laws: l}
  def register_stats(_rows), do: nil
end
