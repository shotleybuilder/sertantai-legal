defmodule SertantaiLegal.Scraper.Sources do
  @moduledoc """
  What a scope's labels need from legislation.gov.uk, and the report against
  what is held (change vocabulary CV-S01, agreed with Jason 2026-10-22).
  Pure: the loader (`mix lat.sources`) reads the feeds, notes, caches and
  store and passes the facts in.

  Needed, by category (one hop; two narrow second hops):

  1. `:own` — each law's own text (its LAT scope's documents)
  2. `:feed` — its changes feed (every page)
  3. `:amending` — every law its feed names as making a text change, or its
     notes cite (body and schedules)
  4. `:commencing` — every order its feed names as commencing it
  5. `:introduction` — each amending SI's introduction (its enabling powers)
  6. `:enabling_parent` — the parent Acts of those powers (body)
  7. `:amending_commencing` — an amending Act's own feed, and the orders it
     names as commencing that Act ("a narrow row 7"); an SI commences
     itself in its own text

  A document needed under two categories is counted once, under the first.

  The report passes when every need is held and fresh, or legislation.gov.uk
  has none (a stored 404: `:absent`); `:not_fetched`, `:incomplete` (a feed
  missing pages) and `:stale` (older than legislation.gov.uk's latest) fail
  ("Enforce stale now"). Each law's feed, counted as the register counts it
  (`register_counts/2`), is compared with the register's change statistics;
  a difference fails until explained.
  """

  @text_kinds ~w(substituted inserted repealed renumbered amended)
  @act_types ~w(ukpga asp anaw asc nia apni)
  @order ~w(own feed amending commencing introduction enabling_parent amending_commencing)a
  @failing [:not_fetched, :incomplete, :stale]

  @type need :: %{category: atom(), law: String.t(), part: atom() | String.t(), for: String.t()}
  @type status :: :held | :absent | :not_fetched | :incomplete | :stale

  @doc """
  The documents one law needs. `law`: `%{law, scope, effects, cited}`
  (`scope` its document paths; `effects` `%{affecting, kind}`; `cited` the
  laws its notes cite). `amending`: per amending law, `%{enabling: [parent
  law]}` (an SI's enabling powers, read from its introduction) and
  `%{commenced_by: [order]}` (an Act's commencing orders, from its own
  feed).
  """
  @spec needs(map(), %{String.t() => map()}) :: [need()]
  def needs(%{law: law} = l, amending) do
    by_kind = fn kinds ->
      for e <- l.effects, e.kind in kinds, e.affecting != law, uniq: true, do: e.affecting
    end

    amenders = Enum.uniq(by_kind.(@text_kinds) ++ Enum.reject(l.cited || [], &(&1 == law)))
    {acts, sis} = Enum.split_with(amenders, &act?/1)
    whole = fn laws -> for x <- laws, p <- [:body, :schedules], do: {x, p} end

    [
      own: Enum.map(l.scope, &{law, &1}),
      feed: [{law, :feed}],
      amending: whole.(amenders),
      commencing: whole.(by_kind.(["commenced"])),
      introduction: Enum.map(sis, &{&1, :introduction}),
      enabling_parent:
        for(s <- sis, p <- get_in(amending, [s, :enabling]) || [], uniq: true, do: {p, :body}),
      amending_commencing:
        Enum.flat_map(acts, fn a ->
          [{a, :feed} | whole.(get_in(amending, [a, :commenced_by]) || [])]
        end)
    ]
    |> Enum.flat_map(fn {category, docs} ->
      Enum.map(docs, fn {x, part} -> %{category: category, law: x, part: part, for: law} end)
    end)
    |> Enum.uniq_by(&{&1.law, &1.part})
  end

  defp act?(law), do: (String.split(law, "_") |> Enum.at(1)) in @act_types

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
