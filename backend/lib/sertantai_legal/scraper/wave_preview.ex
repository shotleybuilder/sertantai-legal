defmodule SertantaiLegal.Scraper.WavePreview do
  @moduledoc """
  What a re-parse wave changes for a law (lat-refactor LR-25), compared
  before and after: its labels as at today (the timeline's `lat_labels_today`)
  and the parse-time columns the labels are built from. Pure: `mix
  lat.wave_preview` runs the real parse path for each law in a transaction
  it always rolls back, and passes the before / after snapshots here.

  A provision with no period today is unknown (nil) on either side.
  """

  @label_fields [:status, :effective_from, :changed_by, :territory]
  @columns [:effect_ids, :excluded_extent, :territory_provenance]

  @type labels :: %{
          status: String.t() | nil,
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil,
          territory: String.t() | nil
        }
  @type diff :: {String.t(), atom(), term(), term()}

  @doc "Each label field that differs as at today, by section_id then field."
  @spec label_diffs(%{String.t() => labels()}, %{String.t() => labels()}) :: [diff()]
  def label_diffs(before, after_) do
    # (no `x = …` inside the `for`: a match there filters out nil and false)
    for sid <- (Map.keys(before) ++ Map.keys(after_)) |> Enum.uniq() |> Enum.sort(),
        field <- @label_fields,
        get_in(before, [sid, field]) != get_in(after_, [sid, field]),
        do: {sid, field, get_in(before, [sid, field]), get_in(after_, [sid, field])}
  end

  @doc "A diff's class, for the counts Jason reviews."
  @spec class(diff()) :: String.t()
  def class({_sid, :status, old, new}), do: "status #{v(old)}→#{v(new)}"
  def class({_sid, :effective_from, nil, _}), do: "effective_from gained"
  def class({_sid, :effective_from, _, nil}), do: "effective_from emptied"
  def class({_sid, :effective_from, _, _}), do: "effective_from moved"
  def class({_sid, :changed_by, nil, _}), do: "changed_by gained"
  def class({_sid, :changed_by, _, nil}), do: "changed_by emptied"
  def class({_sid, :changed_by, _, _}), do: "changed_by changed"
  def class({_sid, :territory, old, new}), do: "territory #{v(old)}→#{v(new)}"

  defp v(nil), do: "unknown"
  defp v(value), do: value

  @doc "Rows whose parse-time columns change, by column; rows added / removed by the parse."
  @spec column_drift(%{String.t() => map()}, %{String.t() => map()}) :: %{atom() => integer()}
  def column_drift(before, after_) do
    shared = for sid <- Map.keys(before), Map.has_key?(after_, sid), do: sid

    @columns
    |> Map.new(fn c ->
      {c, Enum.count(shared, &(norm(before[&1][c]) != norm(after_[&1][c])))}
    end)
    |> Map.merge(%{
      rows_added: Enum.count(Map.keys(after_), &(not Map.has_key?(before, &1))),
      rows_removed: Enum.count(Map.keys(before), &(not Map.has_key?(after_, &1)))
    })
  end

  defp norm(nil), do: nil
  defp norm([]), do: nil
  defp norm(list) when is_list(list), do: Enum.sort(list)
  defp norm(v), do: v
end
