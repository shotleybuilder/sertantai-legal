defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.FeedYardstick do
  @moduledoc """
  The Commencement reader's standard figures against the feed: each
  family's last commencement check, recorded as a file, published by
  `mix lat.measures`. The counts per yardstick class, the proven feed
  errors, and the difference groups by status, by owning step and by row
  kind (Commencement reader retrospective, Decision 1 (e); owners, Jason
  2026-11-23).

  `mix lat.commencement_check --family F` writes the record
  (`record/1`, `write/2`); the measures read it back and say when it was
  taken and whether it follows the family's last build (`lines/2`). The
  check computes the figures, so they are its own, never re-derived.
  """

  alias SertantaiLegal.Scraper.Commencement.FeedDifferences

  @dir "data/reports/commencement-reader/yardstick"
  @classes ~w(agree differ feed_error feed_only feed_partial_only own_only neither)
  @kinds ~w(fix known check)

  @type t :: %{
          family: String.t(),
          at: DateTime.t(),
          fresh: boolean(),
          counts: %{String.t() => non_neg_integer()},
          feed_errors_proven: non_neg_integer(),
          groups: non_neg_integer(),
          by_status: %{String.t() => %{String.t() => non_neg_integer()}},
          by_owner: %{String.t() => %{String.t() => non_neg_integer()}},
          by_row: %{String.t() => %{String.t() => non_neg_integer()}}
        }

  @doc "The record file for `family`."
  @spec path(String.t()) :: String.t()
  def path(family) do
    slug = family |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    Path.join(@dir, slug <> ".json")
  end

  @doc """
  The record of one check: `yardstick` the check's `{class, rows}` tallies,
  `groups` its feed-difference groups (`FeedDifferences.groups/1`, with the
  inserted ones), `reviewed` the statuses (`feed_differences.json`).
  """
  @spec record(map()) :: t()
  def record(%{
        family: f,
        at: at,
        fresh: fresh,
        yardstick: tallies,
        groups: groups,
        reviewed: rev
      }) do
    counts = Map.new(tallies, fn {k, n} -> {to_string(k), n} end)
    shares = Enum.flat_map(groups, &law_shares(&1, rev))

    %{
      family: f,
      at: at,
      fresh: fresh,
      counts: Map.merge(Map.new(@classes, &{&1, 0}), counts),
      feed_errors_proven: Map.get(counts, "feed_error", 0),
      groups: length(groups),
      by_status: tally(shares, & &1.status),
      by_owner: tally(shares, & &1.owner),
      by_row: tally(shares, & &1.row)
    }
  end

  @doc "The table `mix lat.measures` prints; `built_at` the family's last build."
  @spec lines(t() | nil, DateTime.t() | nil) :: [String.t()]
  def lines(nil, _built_at),
    do: [
      "Commencement against the feed: no record; run `mix lat.commencement_check --family F --all`"
    ]

  def lines(r, built_at) do
    total = r.counts |> Map.values() |> Enum.sum()

    ["Commencement against the feed (the check of #{when_taken(r, built_at)}):"] ++
      Enum.map(@classes, &count_line(&1, r.counts[&1], total)) ++
      [
        "  proven feed errors: #{r.feed_errors_proven}",
        "  difference groups: #{r.groups}, by status: #{shares(r.by_status)}",
        "  by owning step: #{shares(r.by_owner)}",
        "  by row: #{shares(r.by_row)}"
      ]
  end

  @doc "Writes the record."
  @spec write(t(), String.t()) :: :ok
  def write(r, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(%{r | at: DateTime.to_iso8601(r.at)}, pretty: true))
  end

  @doc "Reads a record back, nil when there is none."
  @spec read(String.t()) :: t() | nil
  def read(path) do
    case File.read(path) do
      {:ok, body} -> body |> Jason.decode!() |> from_json()
      _ -> nil
    end
  end

  defp from_json(m) do
    {:ok, at, _} = DateTime.from_iso8601(m["at"])

    %{
      family: m["family"],
      at: at,
      fresh: m["fresh"],
      counts: m["counts"],
      feed_errors_proven: m["feed_errors_proven"],
      groups: m["groups"],
      by_status: m["by_status"],
      by_owner: m["by_owner"] || %{},
      by_row: m["by_row"]
    }
  end

  # each law's rows in a group, with its status kind and its row kind
  defp law_shares({shape, g}, reviewed) do
    row =
      if String.starts_with?(shape, "inserted"), do: "inserted provision", else: "own provision"

    for {law, n} <- g.by_law do
      %{
        shape: shape,
        rows: n,
        row: row,
        status: kind(FeedDifferences.status(reviewed, shape, law)),
        owner: FeedDifferences.owner(reviewed, shape, law) || "no owner"
      }
    end
  end

  defp kind(nil), do: "no status"

  defp kind(status) do
    k = status |> String.split(":", parts: 2) |> hd() |> String.trim()
    if k in @kinds, do: k, else: "no status"
  end

  defp tally(shares, key) do
    shares
    |> Enum.group_by(key)
    |> Map.new(fn {k, ss} ->
      {k,
       %{
         "rows" => Enum.sum_by(ss, & &1.rows),
         "groups" => ss |> Enum.uniq_by(& &1.shape) |> length()
       }}
    end)
  end

  defp when_taken(r, built_at) do
    mode = if r.fresh, do: "--fresh", else: "stored"
    order = if built_at && DateTime.compare(r.at, built_at) == :lt, do: "BEFORE", else: "after"
    "#{DateTime.to_string(r.at)}, #{mode}, #{order} the last build"
  end

  defp count_line(k, n, total),
    do: "  #{String.pad_leading(to_string(n), 7)}  #{pct(n, total)}  #{k}"

  defp pct(_n, 0), do: "   n/a"

  defp pct(n, total),
    do: String.pad_leading(:erlang.float_to_binary(100 * n / total, decimals: 1) <> "%", 6)

  defp shares(m) do
    m
    |> Enum.sort_by(fn {_, v} -> -v["rows"] end)
    |> Enum.map_join("; ", fn {k, v} -> "#{k} #{v["rows"]} rows (#{v["groups"]} groups)" end)
  end
end
