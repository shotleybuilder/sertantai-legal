defmodule SertantaiLegal.Scraper.LatTextDiff do
  @moduledoc """
  Row-text differences between a law's stored LAT and a fresh parse (no
  persist), for telling fractalaw which section_ids a parser fix changes
  (LAT parser coverage session, 2026-10-07).

  Handles:
  - `diff/2` — changed, removed and inserted rows by section_id
  - `kind/2` — `"reordered"` when the new text has the same words as the
    old, only reordered, de-duplicated, re-spaced or marked " … " (the
    list-text fix); otherwise `"other"` (e.g. an amendment since the last
    parse)

  Pure: texts are passed in as `%{section_id => text}` maps.
  """

  @type change :: {String.t(), String.t(), String.t() | nil, String.t() | nil}

  @doc "Changes from `old` to `new` (`%{section_id => text}`), ordered by section_id."
  @spec diff(%{String.t() => String.t() | nil}, %{String.t() => String.t() | nil}) :: [change()]
  def diff(old, new) do
    (Map.keys(old) ++ Map.keys(new))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.flat_map(fn id ->
      case {Map.fetch(old, id), Map.fetch(new, id)} do
        {{:ok, same}, {:ok, same}} -> []
        {{:ok, o}, {:ok, n}} -> [{id, "text_changed", o, n}]
        {{:ok, o}, :error} -> [{id, "removed", o, nil}]
        {:error, {:ok, n}} -> [{id, "inserted", nil, n}]
      end
    end)
  end

  @doc """
  `"reordered"` when the old and new texts hold the same words, ignoring
  order, repeats and the " … " gap marker — an old word glued from two new
  words ("andany") counts as those two; else `"other"`.
  """
  @spec kind(String.t() | nil, String.t() | nil) :: String.t()
  def kind(old, new) do
    new_words = MapSet.new(words(new))

    old_words =
      old
      |> words()
      |> Enum.flat_map(fn w ->
        if MapSet.member?(new_words, w), do: [w], else: split_glued(w, new_words)
      end)
      |> MapSet.new()

    if old_words == new_words, do: "reordered", else: "other"
  end

  defp words(nil), do: []
  defp words(text), do: text |> String.split(~r/\s+/, trim: true) |> Enum.reject(&(&1 == "…"))

  # "andany" → ["and", "any"] when both halves are new words; else the word itself
  defp split_glued(word, new_words) do
    len = String.length(word)

    Enum.find_value(1..max(len - 1, 1)//1, [word], fn i ->
      {a, b} = String.split_at(word, i)
      if MapSet.member?(new_words, a) and MapSet.member?(new_words, b), do: [a, b]
    end)
  end
end
