defmodule SertantaiLegal.Scraper.LatHash.Query do
  @moduledoc """
  Database side of `LatHash` (fractalatai #62): the LAT manifest.

  - `served_query/1` — the rows the Zenoh LAT queryable serves for a law; the
    hash is defined over exactly this set, so both read the `lat` view with no
    other filter
  - `for_law/1`, `all/0` — `%{law_name, row_count, lat_hash, updated_at}`
    from `legal_register` (`lat_count`, `lat_hash`, `latest_lat_updated_at`),
    which the LAT stats triggers keep current on every write path
  - `computed_hash/1` — recompute via the SQL function `lat_hash_for()`
  - `event_metadata/1` — `row_count` + `lat_hash` for `lat` sync events

  `lat_hash_for()` (migration 20260926160743) mirrors `LatHash.hash/1`;
  `LatHashQueryTest` holds them equal.
  """

  import Ecto.Query

  alias SertantaiLegal.Legal.Lat
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatEffects, LatHash}

  @type manifest_entry :: %{
          law_name: String.t(),
          row_count: non_neg_integer(),
          lat_hash: String.t(),
          struct_hash: String.t(),
          updated_at: DateTime.t() | nil,
          coverage: String.t(),
          scope: String.t() | nil,
          status_hash: String.t() | nil,
          cause: String.t() | nil,
          source_hash: String.t() | nil,
          amended: boolean(),
          as_of: Date.t() | nil,
          effects_unapplied: String.t()
        }

  @no_cause %{cause: nil, source_hash: nil}

  # amended (#167 L8.4): the text differs from the made version, i.e. the law
  # has an amendment-type note (F-notes exist only where the text was
  # changed). as_of: the latest parse's <dct:valid>, else the metadata's.
  @select """
  SELECT r.name, r.lat_count, r.lat_hash, r.struct_hash, r.latest_lat_updated_at, r.lat_scope,
         EXISTS (SELECT 1 FROM amendment_annotations a
                 WHERE a.law_name = r.name AND a.code_type = 'amendment'),
         COALESCE((SELECT e.source_valid_date FROM lat_events e
                   WHERE e.law_name = r.name AND e.event = 'parsed' AND e.source_valid_date IS NOT NULL
                   ORDER BY e.at DESC LIMIT 1),
                  r.md_dct_valid_date)
  FROM legal_register r
  """

  # status_hash (#167), mirroring LatHash.status_hash/1 over the `lat` view:
  # NULL while any row's status is NULL. COLLATE "C" = bytewise order.
  @status_hash_sql """
  SELECT law_name,
         CASE WHEN bool_and(status IS NOT NULL) THEN
           encode(sha256(convert_to(
             string_agg(section_id || E'\\t' || status || E'\\n', '' ORDER BY section_id COLLATE "C"),
             'UTF8')), 'hex')
         END
  FROM lat
  """

  @doc "The rows the LAT queryable serves for `law_name`, in serving order."
  @spec served_query(String.t()) :: Ecto.Query.t()
  def served_query(law_name) do
    from(l in Lat, where: l.law_name == ^law_name, order_by: [asc: l.sort_key])
  end

  @doc "Manifest entry for one law; a law without LAT has row_count 0 and the empty hash."
  @spec for_law(String.t()) :: manifest_entry()
  def for_law(law_name) do
    case Repo.query!(@select <> " WHERE r.name = $1 AND r.lat_count > 0", [law_name]) do
      %{rows: [row]} ->
        row
        |> entry()
        |> Map.put(:status_hash, status_hashes([law_name])[law_name])
        |> Map.merge(Map.get(last_causes([law_name]), law_name, @no_cause))
        |> Map.put(:effects_unapplied, Map.get(effects_unapplied([law_name]), law_name, "[]"))

      %{rows: []} ->
        %{
          law_name: law_name,
          row_count: 0,
          lat_hash: LatHash.empty_hash(),
          struct_hash: LatHash.empty_hash(),
          updated_at: nil,
          coverage: "full",
          scope: nil,
          status_hash: LatHash.empty_hash(),
          cause: nil,
          source_hash: nil,
          amended: false,
          as_of: nil,
          effects_unapplied: "[]"
        }
    end
  end

  @doc "Manifest entries for every law with LAT rows, by law_name. Absent laws hold no LAT."
  @spec all() :: [manifest_entry()]
  def all do
    %{rows: rows} = Repo.query!(@select <> " WHERE r.lat_count > 0 ORDER BY r.name", [])
    hashes = status_hashes(:all)
    causes = last_causes(:all)
    effects = effects_unapplied(:all)

    Enum.map(rows, fn row ->
      e = entry(row)

      e
      |> Map.put(:status_hash, hashes[e.law_name])
      |> Map.merge(Map.get(causes, e.law_name, @no_cause))
      |> Map.put(:effects_unapplied, Map.get(effects, e.law_name, "[]"))
    end)
  end

  @doc """
  legislation.gov.uk effects not yet applied to each law's text (#167 L8.4),
  as a JSON list per law (`LatEffects.unapplied/3`), for the named laws or
  `:all`. Laws without any are absent (the manifest shows "[]").
  """
  @spec effects_unapplied([String.t()] | :all) :: %{String.t() => String.t()}
  def effects_unapplied(laws) do
    {filter, params} =
      if laws == :all, do: {"", []}, else: {" AND name = ANY($1)", [laws]}

    %{rows: stats} =
      Repo.query!(
        ~s|SELECT name, "🔻_affected_by_stats_per_law" FROM legal_register | <>
          ~s|WHERE lat_count > 0 AND "🔻_affected_by_stats_per_law"::text LIKE '%Not yet%'| <>
          filter,
        params,
        timeout: :infinity
      )

    names = Enum.map(stats, &hd/1)

    %{rows: id_rows} =
      Repo.query!(
        "SELECT law_name, section_id FROM legal_articles WHERE law_name = ANY($1)",
        [names],
        timeout: :infinity
      )

    ids = Enum.group_by(id_rows, &hd/1, &List.last/1)

    for [name, stat] <- stats,
        effects = LatEffects.unapplied(stat, name, MapSet.new(Map.get(ids, name, []))),
        effects != [],
        into: %{},
        do: {name, Jason.encode!(effects)}
  end

  # The latest parse with a recorded cause per law (#167, L8.3).
  @last_cause_sql """
  SELECT DISTINCT ON (law_name) law_name, cause, source_hash
  FROM lat_events WHERE event = 'parsed' AND cause IS NOT NULL
  """

  @doc "`%{cause, source_hash}` of each law's latest caused parse (#167), for the named laws or `:all`."
  @spec last_causes([String.t()] | :all) :: %{
          String.t() => %{cause: String.t(), source_hash: String.t() | nil}
        }
  def last_causes(:all), do: causes_query(" ORDER BY law_name, at DESC", [])

  def last_causes(laws) when is_list(laws),
    do: causes_query(" AND law_name = ANY($1) ORDER BY law_name, at DESC", [laws])

  defp causes_query(tail, params) do
    %{rows: rows} = Repo.query!(@last_cause_sql <> tail, params)
    Map.new(rows, fn [law, cause, hash] -> {law, %{cause: cause, source_hash: hash}} end)
  end

  @doc "`status_hash` per law (#167), for the named laws or `:all`."
  @spec status_hashes([String.t()] | :all) :: %{String.t() => String.t() | nil}
  def status_hashes(:all) do
    %{rows: rows} = Repo.query!(@status_hash_sql <> " GROUP BY law_name", [], timeout: :infinity)
    Map.new(rows, fn [law, hash] -> {law, hash} end)
  end

  def status_hashes(laws) when is_list(laws) do
    %{rows: rows} =
      Repo.query!(@status_hash_sql <> " WHERE law_name = ANY($1) GROUP BY law_name", [laws])

    Map.new(rows, fn [law, hash] -> {law, hash} end)
  end

  @doc "Recompute a law's hash from its rows via `lat_hash_for()` (verification; bypasses the stored value)."
  @spec computed_hash(String.t()) :: String.t()
  def computed_hash(law_name) do
    %{rows: [[hash]]} = Repo.query!("SELECT lat_hash_for($1)", [law_name])
    hash
  end

  @doc "Recompute a law's structural hash via `lat_struct_hash_for()` (verification)."
  @spec computed_struct_hash(String.t()) :: String.t()
  def computed_struct_hash(law_name) do
    %{rows: [[hash]]} = Repo.query!("SELECT lat_struct_hash_for($1)", [law_name])
    hash
  end

  @doc "`row_count`, `lat_hash` and `struct_hash` for a `lat` sync event about `law_name`."
  @spec event_metadata(String.t()) :: %{
          row_count: non_neg_integer(),
          lat_hash: String.t(),
          struct_hash: String.t()
        }
  def event_metadata(law_name) do
    law_name |> for_law() |> Map.take([:row_count, :lat_hash, :struct_hash])
  end

  # coverage/scope (#166): a scoped law's LAT is intentionally partial —
  # `scope` is JSON {fragments, purposes} (e.g. purposes ["enabling_extent"]).
  defp entry([law_name, count, hash, struct_hash, updated_at, scope, amended, as_of]) do
    %{
      amended: amended,
      as_of: as_of,
      law_name: law_name,
      row_count: count,
      lat_hash: hash,
      struct_hash: struct_hash,
      updated_at: to_utc(updated_at),
      coverage: if(scope, do: "partial", else: "full"),
      scope: scope && Jason.encode!(Map.take(scope, ["fragments", "purposes"]))
    }
  end

  defp to_utc(%NaiveDateTime{} = t), do: DateTime.from_naive!(t, "Etc/UTC")
  defp to_utc(t), do: t
end
