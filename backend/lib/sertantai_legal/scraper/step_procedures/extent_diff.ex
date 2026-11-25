defmodule SertantaiLegal.Scraper.StepProcedures.ExtentDiff do
  @moduledoc """
  A fix's reach over one law's stored extent rows: the rows a fresh
  reading adds and the stored ones it no longer gives, each row counted
  as often as it appears, and each pair of a gone and an added row on the
  same provision (kind and source ref) named by the fields that differ
  (`mix lat.amending --extents --preview`). Pure: the rows are
  `Extent.Write.plan/3`'s, on `Extent.Store.compared/0`'s columns.
  """

  @type row :: %{atom() => term()}
  @type change :: %{fields: [atom()], from: row() | nil, to: row() | nil}
  @type t :: %{added: [row()], gone: [row()], changes: [change()]}

  @doc "The rows `fresh` adds to `stored`, those it drops, and the changes they make, paired by provision."
  @spec diff([row()], [row()]) :: t()
  def diff(stored, fresh) do
    added = fresh -- stored
    gone = stored -- fresh
    %{added: added, gone: gone, changes: pair(gone, added)}
  end

  @doc "Whether the reading changes nothing."
  @spec same?(t()) :: boolean()
  def same?(%{added: [], gone: []}), do: true
  def same?(_diff), do: false

  @doc "The changes counted by the fields they touch (`\"items\"`, `\"place+items\"`, `\"added\"`, `\"gone\"`)."
  @spec by_field([change()]) :: %{String.t() => non_neg_integer()}
  def by_field(changes), do: Enum.frequencies_by(changes, &label/1)

  defp label(%{from: nil}), do: "added"
  defp label(%{to: nil}), do: "gone"
  defp label(%{fields: fields}), do: Enum.map_join(fields, "+", &to_string/1)

  # each gone row with the first added row on its provision; the rest alone
  defp pair([], added), do: Enum.map(added, &%{fields: [], from: nil, to: &1})

  defp pair([g | gone], added) do
    case Enum.split_with(added, &(key(&1) == key(g))) do
      {[a | more], rest} -> [change(g, a) | pair(gone, more ++ rest)]
      {[], rest} -> [%{fields: [], from: g, to: nil} | pair(gone, rest)]
    end
  end

  defp key(row), do: {row[:kind], row[:source_ref]}

  defp change(from, to) do
    fields = for k <- Enum.sort(Map.keys(from)), from[k] != to[k], do: k
    %{fields: fields, from: from, to: to}
  end
end
