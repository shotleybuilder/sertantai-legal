defmodule SertantaiLegal.Scraper.CatalogueRun do
  @moduledoc """
  A whole-store catalogue run's record: which catalogue, over what scope, at
  which commit, each cache's hits and reads, the wall time and its serial
  part, the workers and the peak memory — so every run is cold, warm or
  mixed on the record, and a round's retrospective compares runs from the
  log (`CatalogueRun.Log`), not from prose (Catalogues Across the Workflow,
  Jason 2026-11-21: "having timings is really useful"). Pure.
  """

  @enforce_keys [
    :catalogue,
    :scope,
    :started_at,
    :commit,
    :caches,
    :wall_s,
    :serial_s,
    :workers,
    :peak_mb
  ]
  defstruct @enforce_keys

  @type tally :: %{hits: non_neg_integer(), read: non_neg_integer()}
  @type t :: %__MODULE__{
          catalogue: String.t(),
          scope: String.t(),
          started_at: DateTime.t(),
          commit: String.t() | nil,
          caches: %{String.t() => tally()},
          wall_s: float(),
          serial_s: float(),
          workers: pos_integer(),
          peak_mb: non_neg_integer()
        }

  @doc "A run's record from its fields (every one required)."
  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)

  @doc """
  A run's scope from its options: `"family:<F>"`, `"laws:<n>"`,
  `"orders:<n>"` (comma-separated lists, counted), else `"all"`.
  """
  @spec scope(keyword()) :: String.t()
  def scope(opts) do
    cond do
      opts[:family] -> "family:#{opts[:family]}"
      opts[:laws] -> "laws:#{count(opts[:laws])}"
      opts[:orders] -> "orders:#{count(opts[:orders])}"
      true -> "all"
    end
  end

  defp count(list), do: list |> String.split(",", trim: true) |> length()

  @doc "A cache's tally from each law's `:hit | :read`."
  @spec tally([:hit | :read]) :: tally()
  def tally(sources),
    do: %{hits: Enum.count(sources, &(&1 == :hit)), read: Enum.count(sources, &(&1 == :read))}

  @doc "Cold when no cache had a hit, warm when none read, mixed otherwise; uncached with no cache."
  @spec kind(t()) :: :cold | :warm | :mixed | :uncached
  def kind(%__MODULE__{caches: caches}) when map_size(caches) == 0, do: :uncached

  def kind(%__MODULE__{caches: caches}) do
    tallies = Map.values(caches)

    cond do
      Enum.all?(tallies, &(&1.hits == 0)) -> :cold
      Enum.all?(tallies, &(&1.read == 0)) -> :warm
      true -> :mixed
    end
  end

  @doc "The line a catalogue prints at its end."
  @spec line(t()) :: String.t()
  def line(%__MODULE__{} = run) do
    caches =
      for {name, %{hits: h, read: r}} <- Enum.sort(run.caches),
          do: ", #{name}: #{h} hits #{r} read"

    "run: #{kind(run)}#{caches}, #{run.wall_s} s (serial #{run.serial_s} s), " <>
      "#{run.peak_mb} MB, #{run.workers} workers"
  end

  @doc "The record as the log's JSON object."
  @spec to_json(t()) :: map()
  def to_json(%__MODULE__{} = run) do
    %{
      "catalogue" => run.catalogue,
      "kind" => to_string(kind(run)),
      "scope" => run.scope,
      "started_at" => DateTime.to_iso8601(run.started_at),
      "commit" => run.commit,
      "caches" =>
        Map.new(run.caches, fn {k, t} -> {k, %{"hits" => t.hits, "read" => t.read}} end),
      "wall_s" => run.wall_s,
      "serial_s" => run.serial_s,
      "workers" => run.workers,
      "peak_mb" => run.peak_mb
    }
  end
end
