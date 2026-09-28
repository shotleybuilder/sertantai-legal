defmodule SertantaiLegal.Scraper.LiveStatus.EffectsBackfill do
  @moduledoc """
  Backfill of legislation.gov.uk changes-feed effect data into existing laws
  (the live status parse session, 2026-09-28), in two steps:

  1. `fetch_all/2` — fetch each law's changes feed once into a local JSON cache
     (`data/cache/changes-feed/<law>.json`); resumable, read-only on the DB.
  2. `plan/0` + `apply!/2` — from the cache:
     - add `affected_extent` / `effect_extent` / `territorial_application` to
       the stored revocation rows (`🔻_rescinded_by_stats_per_law` details),
       matched as `ChangesFeed.enrich/2` does (legacy rows split first);
     - re-resolve `geo_extent` where it has no source or only the type floor,
       with the `affected_effects` source (`ExtentResolver`).

  `enrich_stats/2` is pure. `apply!/2` snapshots the columns it writes.
  """

  alias SertantaiLegal.Legal.ReadinessTiers
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ExtentResolver
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.LiveStatus

  @cache_dir Path.join(["data", "cache", "changes-feed"])

  defmodule Change do
    @moduledoc "One law's backfill outcome."
    @enforce_keys [:name]
    defstruct [
      :name,
      :stats,
      :matched,
      :revocation_rows,
      :old_extent,
      :old_source,
      :new_extent,
      :new_region,
      :new_source
    ]

    @type t :: %__MODULE__{}
  end

  @doc "The cache directory (overridable with `:dir`)."
  @spec cache_dir(keyword()) :: String.t()
  def cache_dir(opts \\ []), do: Keyword.get(opts, :dir, @cache_dir)

  @batch_size 1000

  @doc """
  UK laws needing the feed — with revocation rows, or an unsourced / type-floor
  extent — as `{tier, group, name}` in batch order.

  Meta-batched by readiness tier (`Legal.ReadinessTiers`): Tier 0 (QQ's
  register), then the Tier 1 family clusters (`1a`…`1e`), then Tier 2. Within
  a tier (Tier 2: laws with a Family before those without), by group — `revoked`, `part_revoked`, `in_force_rows` (laws with
  revocation rows, by current `live`), then `unsourced` and `type_floor`
  (extent-only) — then Making laws first, laws with no extent source first,
  then name. Malformed names (no type code) are left out.
  """
  @spec target_laws() :: [{String.t(), String.t(), String.t()}]
  def target_laws do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT tier, grp, name FROM (
          SELECT r.name, r.is_making, r.geo_extent_source,
            #{ReadinessTiers.tier_sql()} AS tier,
            CASE WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL AND r.live LIKE '❌%' THEN 1
                 WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL AND r.live LIKE '⭕%' THEN 2
                 WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL THEN 3
                 WHEN r.geo_extent_source IS NULL THEN 4
                 ELSE 5 END AS rank,
            CASE WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL AND r.live LIKE '❌%' THEN 'revoked'
                 WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL AND r.live LIKE '⭕%' THEN 'part_revoked'
                 WHEN r."🔻_rescinded_by_stats_per_law" IS NOT NULL THEN 'in_force_rows'
                 WHEN r.geo_extent_source IS NULL THEN 'unsourced'
                 ELSE 'type_floor' END AS grp
          FROM legal_register r
          WHERE r.country = 'uk' AND r.name !~ '^UK__' AND r.name !~ '_$'
            AND (r."🔻_rescinded_by_stats_per_law" IS NOT NULL
                 OR r.geo_extent_source IS NULL OR r.geo_extent_source = 'type_code')
        ) t
        ORDER BY tier, rank, coalesce(is_making, false) DESC, (geo_extent_source IS NULL) DESC, name
        """,
        [],
        timeout: :infinity
      )

    Enum.map(rows, fn [tier, grp, name] -> {tier, grp, name} end)
  end

  @doc """
  The batch plan: one batch per tier / Tier 1 cluster (`"0"`, `"1a"`…),
  split into `.1`, `.2`… when over `size`; Tier 2 in numbered batches
  (`"2.01"`…, laws with a Family) then `"2n.01"`… (no Family). Each batch: label, names, groups covered, laws already cached.
  """
  @spec batches([{String.t(), String.t(), String.t()}], keyword()) :: [map()]
  def batches(targets, opts \\ []) do
    size = Keyword.get(opts, :size, @batch_size)
    dir = cache_dir(opts)

    targets
    |> Enum.chunk_by(&elem(&1, 0))
    |> Enum.flat_map(fn [{tier, _, _} | _] = laws ->
      chunks = Enum.chunk_every(laws, size)

      chunks
      |> Enum.with_index(1)
      |> Enum.map(fn {chunk, i} -> {label(tier, i, length(chunks)), chunk} end)
    end)
    |> Enum.map(fn {label, chunk} ->
      names = Enum.map(chunk, &elem(&1, 2))

      %{
        batch: label,
        names: names,
        laws: length(names),
        groups: chunk |> Enum.map(&elem(&1, 1)) |> Enum.uniq(),
        cached: Enum.count(names, &File.exists?(path(dir, &1)))
      }
    end)
  end

  @doc "The names in batch `label` of the plan (nil when there is no such batch)."
  @spec batch([{String.t(), String.t(), String.t()}], String.t(), keyword()) ::
          [String.t()] | nil
  def batch(targets, label, opts \\ []) do
    case Enum.find(batches(targets, opts), &(&1.batch == label)) do
      nil -> nil
      b -> b.names
    end
  end

  defp label(tier, i, _n) when tier in ["2", "2n"],
    do: "#{tier}." <> String.pad_leading("#{i}", 2, "0")

  defp label(tier, _i, 1), do: tier
  defp label(tier, i, _n), do: "#{tier}.#{i}"

  @doc """
  Fetch and cache the feed for each law not yet cached. Returns counts of
  `:fetched`, `:cached` (skipped) and `:failed` (logged to `errors.log`).
  """
  @spec fetch_all([String.t()], keyword()) :: %{atom() => non_neg_integer()}
  def fetch_all(names, opts \\ []) do
    dir = cache_dir(opts)
    File.mkdir_p!(dir)
    progress = Keyword.get(opts, :on_progress, fn _ -> :ok end)

    names
    |> Enum.with_index(1)
    |> Enum.reduce(%{fetched: 0, cached: 0, failed: 0}, fn {name, i}, acc ->
      progress.({i, length(names), name})

      cond do
        File.exists?(path(dir, name)) ->
          Map.update!(acc, :cached, &(&1 + 1))

        true ->
          case fetch_one(name) do
            {:ok, effects} ->
              File.write!(path(dir, name), Jason.encode!(Enum.map(effects, &Map.from_struct/1)))
              Map.update!(acc, :fetched, &(&1 + 1))

            {:error, msg} ->
              File.write!(Path.join(dir, "errors.log"), "#{name}\t#{msg}\n", [:append])
              Map.update!(acc, :failed, &(&1 + 1))
          end
      end
    end)
  end

  @doc "A law's cached effects, or nil when not cached."
  @spec load(String.t(), keyword()) :: [Effect.t()] | nil
  def load(name, opts \\ []) do
    case File.read(path(cache_dir(opts), name)) do
      {:ok, json} ->
        json
        |> Jason.decode!()
        |> Enum.map(fn e ->
          fields = %Effect{type: nil, affecting: nil} |> Map.from_struct() |> Map.keys()
          struct!(Effect, Map.new(fields, &{&1, e[Atom.to_string(&1)]}))
        end)

      _ ->
        nil
    end
  end

  @doc """
  Add effect extents to stored revocation rows. Each detail is matched on its
  revoking law, target and affect (legacy rows split as
  `LiveStatus.rows_from_stats/1` does). Returns `{stats, matched, rows}`.
  """
  @spec enrich_stats(map() | nil, [Effect.t()]) ::
          {map() | nil, non_neg_integer(), non_neg_integer()}
  def enrich_stats(nil, _effects), do: {nil, 0, 0}

  def enrich_stats(stats, effects) do
    index = ChangesFeed.index(effects)

    {new, {matched, total}} =
      Enum.map_reduce(stats, {0, 0}, fn {law, entry}, {m, t} ->
        {details, m2} =
          Enum.map_reduce(Map.get(entry, "details") || [], m, fn d, acc ->
            [row] = LiveStatus.rows_from_stats(%{law => %{"details" => [d]}})

            case ChangesFeed.lookup(index, law, row.target, row.affect) do
              %Effect{} = e ->
                {d
                 |> Map.put("feed", "matched")
                 |> put_present("affected_extent", e.affected_extent)
                 |> put_present("effect_extent", e.effect_extent)
                 |> put_present("territorial_application", e.territorial_application), acc + 1}

              nil ->
                {Map.put(d, "feed", "unmatched"), acc}
            end
          end)

        {{law, Map.put(entry, "details", details)}, {m2, t + length(details)}}
      end)

    {Map.new(new), matched, total}
  end

  @doc "Every cached law's outcome."
  @spec plan(keyword()) :: [Change.t()]
  def plan(opts \\ []) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT name, "🔻_rescinded_by_stats_per_law", geo_extent, geo_extent_source,
               md_restrict_extent, document_status, type_code
        FROM legal_register WHERE country = 'uk' ORDER BY name
        """,
        [],
        timeout: :infinity
      )

    for [name, stats, extent, source, restrict, doc_status, type] <- rows,
        effects = load(name, opts),
        effects != nil do
      {new_stats, matched, total} = enrich_stats(stats, effects)
      resolution = resolve_extent(source, restrict, doc_status, type, effects)

      %Change{
        name: name,
        stats: if(new_stats != stats, do: new_stats),
        matched: matched,
        revocation_rows: total,
        old_extent: extent,
        old_source: source,
        new_extent: resolution && resolution.geo_extent,
        new_region: resolution && resolution.geo_region,
        new_source: resolution && resolution.source
      }
    end
  end

  @doc "Write the planned stats and extents, after snapshotting them to `snapshot_table`."
  @spec apply!([Change.t()], String.t()) :: %{stats: non_neg_integer(), extent: non_neg_integer()}
  def apply!(changes, snapshot_table) do
    {:ok, counts} =
      Repo.transaction(
        fn ->
          Repo.query!(
            ~s|CREATE TABLE #{snapshot_table} AS SELECT id, country, name, "🔻_rescinded_by_stats_per_law", geo_extent, geo_region, geo_extent_source, now() AS snapshot_at FROM legal_register WHERE country = 'uk'|,
            [],
            timeout: :infinity
          )

          Enum.reduce(changes, %{stats: 0, extent: 0}, fn c, acc ->
            acc =
              if c.stats do
                Repo.query!(
                  ~s|UPDATE legal_register SET "🔻_rescinded_by_stats_per_law" = $2 WHERE country = 'uk' AND name = $1|,
                  [c.name, c.stats]
                )

                Map.update!(acc, :stats, &(&1 + 1))
              else
                acc
              end

            if extent_change?(c) do
              Repo.query!(
                "UPDATE legal_register SET geo_extent = $2, geo_region = $3, geo_extent_source = $4 WHERE country = 'uk' AND name = $1",
                [c.name, c.new_extent, c.new_region, c.new_source]
              )

              Map.update!(acc, :extent, &(&1 + 1))
            else
              acc
            end
          end)
        end,
        timeout: :infinity
      )

    counts
  end

  @doc "Does this outcome change the stored extent?"
  @spec extent_change?(Change.t()) :: boolean()
  def extent_change?(%Change{new_source: nil}), do: false

  def extent_change?(%Change{} = c),
    do:
      ExtentResolver.overwrite?(c.old_source, c.new_source) and
        {c.new_extent, c.new_source} != {c.old_extent, c.old_source}

  # --- helpers ---

  # Only a law with no source or the type floor is re-resolved, and only the
  # affected_effects source can be new here (higher sources were resolved already).
  defp resolve_extent(source, restrict, doc_status, type, effects)
       when source in [nil, "type_code"] do
    r =
      ExtentResolver.resolve(%{
        restrict_extent: restrict,
        document_status: doc_status,
        lat_extent_codes: [],
        contents_item_extents: [],
        extent_clauses: [],
        type_code: type,
        affected_extents: ChangesFeed.affected_extents(effects)
      })

    if r.source == "affected_effects", do: r
  end

  defp resolve_extent(_source, _restrict, _doc_status, _type, _effects), do: nil

  defp fetch_one(name) do
    case String.split(name, "_") do
      ["UK", type, year | number] when number != [] ->
        if Regex.match?(~r/^\d{4}$/, year),
          do: ChangesFeed.fetch(type, year, Enum.join(number, "_")),
          else: {:error, "non-numeric year"}

      _ ->
        {:error, "unrecognised name"}
    end
  end

  defp path(dir, name), do: Path.join(dir, name <> ".json")

  defp put_present(map, _key, nil), do: map
  defp put_present(map, key, value), do: Map.put(map, key, value)
end
