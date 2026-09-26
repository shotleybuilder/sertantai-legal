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
  alias SertantaiLegal.Scraper.LatHash

  @type manifest_entry :: %{
          law_name: String.t(),
          row_count: non_neg_integer(),
          lat_hash: String.t(),
          updated_at: DateTime.t() | nil
        }

  @select "SELECT name, lat_count, lat_hash, latest_lat_updated_at FROM legal_register"

  @doc "The rows the LAT queryable serves for `law_name`, in serving order."
  @spec served_query(String.t()) :: Ecto.Query.t()
  def served_query(law_name) do
    from(l in Lat, where: l.law_name == ^law_name, order_by: [asc: l.sort_key])
  end

  @doc "Manifest entry for one law; a law without LAT has row_count 0 and the empty hash."
  @spec for_law(String.t()) :: manifest_entry()
  def for_law(law_name) do
    case Repo.query!(@select <> " WHERE name = $1 AND lat_count > 0", [law_name]) do
      %{rows: [row]} ->
        entry(row)

      %{rows: []} ->
        %{law_name: law_name, row_count: 0, lat_hash: LatHash.empty_hash(), updated_at: nil}
    end
  end

  @doc "Manifest entries for every law with LAT rows, by law_name. Absent laws hold no LAT."
  @spec all() :: [manifest_entry()]
  def all do
    %{rows: rows} = Repo.query!(@select <> " WHERE lat_count > 0 ORDER BY name", [])
    Enum.map(rows, &entry/1)
  end

  @doc "Recompute a law's hash from its rows via `lat_hash_for()` (verification; bypasses the stored value)."
  @spec computed_hash(String.t()) :: String.t()
  def computed_hash(law_name) do
    %{rows: [[hash]]} = Repo.query!("SELECT lat_hash_for($1)", [law_name])
    hash
  end

  @doc "`row_count` and `lat_hash` for a `lat` sync event about `law_name`."
  @spec event_metadata(String.t()) :: %{row_count: non_neg_integer(), lat_hash: String.t()}
  def event_metadata(law_name) do
    law_name |> for_law() |> Map.take([:row_count, :lat_hash])
  end

  defp entry([law_name, count, hash, updated_at]) do
    %{law_name: law_name, row_count: count, lat_hash: hash, updated_at: to_utc(updated_at)}
  end

  defp to_utc(%NaiveDateTime{} = t), do: DateTime.from_naive!(t, "Etc/UTC")
  defp to_utc(t), do: t
end
