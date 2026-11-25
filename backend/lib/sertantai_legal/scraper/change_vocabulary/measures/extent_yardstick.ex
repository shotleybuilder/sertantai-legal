defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.ExtentYardstick do
  @moduledoc """
  The Extent reader's standard figures against the feed: each text change
  of a family by how the feed's effect extent compares with the bound the
  amending law's text gives (`agree`, `law_wider`, `law_narrower`,
  `overlap`, `disjoint`, `feed_only`, `law_only`, `neither`), and the
  family gate's no-bound changes by whether the feed speaks for them
  (RULES `extent-feed-first-where-it-speaks`: where it does, a cause is a
  known limit). Recorded by `mix lat.extent_check --family F`, published
  by `mix lat.measures --family F`, as `FeedYardstick` is for the
  Commencement reader. Pure but for the record file.
  """

  alias SertantaiLegal.Scraper.Territory

  @dir "data/reports/extent-reader/yardstick"
  @classes ~w(agree law_wider law_narrower overlap disjoint feed_only law_only neither)

  @type t :: %{
          family: String.t(),
          at: DateTime.t(),
          counts: %{String.t() => non_neg_integer()},
          no_bound: %{String.t() => non_neg_integer()}
        }

  @doc "The classes, in the order printed."
  @spec classes() :: [String.t()]
  def classes, do: @classes

  @doc """
  How the feed's effect extent (`feed`) and the law's text bound (`law`)
  of one change compare; each an extent code or nil (\"UK\" is the UK).
  """
  @spec classify(String.t() | nil, String.t() | nil) :: String.t()
  def classify(nil, nil), do: "neither"
  def classify(_feed, nil), do: "feed_only"
  def classify(nil, _law), do: "law_only"

  def classify(feed, law) do
    {f, l} = {code(feed), code(law)}

    cond do
      f == l -> "agree"
      Territory.covers?(l, f) -> "law_wider"
      Territory.covers?(f, l) -> "law_narrower"
      Territory.disjoint?(f, l) -> "disjoint"
      true -> "overlap"
    end
  end

  # the UK in full, so "UK" and "E+W+S+NI" agree
  defp code(extent), do: Territory.normalize(extent) || "E+W+S+NI"

  @doc "The changes (`feed_extent`, `law_extent`) counted by class, every class present."
  @spec counts([map()]) :: %{String.t() => non_neg_integer()}
  def counts(changes) do
    tallies = Enum.frequencies_by(changes, &classify(&1[:feed_extent], &1[:law_extent]))
    Map.merge(Map.new(@classes, &{&1, 0}), tallies)
  end

  @doc "Whether the feed gives `change` an effect extent."
  @spec feed_speaks?(map()) :: boolean()
  def feed_speaks?(change), do: change[:feed_extent] not in [nil, ""]

  @doc """
  The record of one check: its text changes (`counts/1`) and those with no
  bound (`outcome` `none:…`) split by whether the feed speaks for them.
  """
  @spec record(String.t(), DateTime.t(), [map()]) :: t()
  def record(family, at, change_rows) do
    none = Enum.filter(change_rows, &String.starts_with?(&1.outcome, "none:"))
    {speaks, silent} = Enum.split_with(none, &feed_speaks?/1)

    %{
      family: family,
      at: at,
      counts: counts(change_rows),
      no_bound: %{"feed_speaks" => length(speaks), "feed_silent" => length(silent)}
    }
  end

  @doc "The record file for `family`."
  @spec path(String.t()) :: String.t()
  def path(family) do
    slug = family |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
    Path.join(@dir, slug <> ".json")
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
    with {:ok, body} <- File.read(path),
         m = Jason.decode!(body),
         {:ok, at, _} <- DateTime.from_iso8601(m["at"]) do
      %{family: m["family"], at: at, counts: m["counts"], no_bound: m["no_bound"]}
    else
      _ -> nil
    end
  end

  @doc "The table `mix lat.measures` prints; `built_at` the family's last build."
  @spec lines(t() | nil, DateTime.t() | nil) :: [String.t()]
  def lines(nil, _built_at),
    do: ["Extent against the feed: no record; run `mix lat.extent_check --family F`"]

  def lines(r, built_at) do
    total = r.counts |> Map.values() |> Enum.sum()
    order = if built_at && DateTime.compare(r.at, built_at) == :lt, do: "BEFORE", else: "after"

    [
      "Extent against the feed (the check of #{DateTime.to_string(r.at)}, #{order} the last build):"
    ] ++
      Enum.map(@classes, &count_line(&1, r.counts[&1] || 0, total)) ++
      [
        "  no bound from the law: #{r.no_bound["feed_speaks"]} where the feed speaks (known), " <>
          "#{r.no_bound["feed_silent"]} where it is silent (the gate's)"
      ]
  end

  defp count_line(k, n, total),
    do: "  #{String.pad_leading(to_string(n), 7)}  #{pct(n, total)}  #{k}"

  defp pct(_n, 0), do: "   n/a"

  defp pct(n, total),
    do: String.pad_leading(:erlang.float_to_binary(100 * n / total, decimals: 1) <> "%", 6)
end
