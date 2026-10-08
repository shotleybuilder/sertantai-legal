defmodule SertantaiLegal.Scraper.NoteReorder do
  @moduledoc """
  One-off re-key of amendment note text (LAT parser coverage II): notes were
  stored scrambled (xmerl's `//text()` puts direct text before the
  Citations'). `mix lat.reorder_notes` re-reads each law's commentaries
  from the CLML store and rewrites the stored text in document order.

  Pure: `plan/2` pairs stored notes with `CommentaryParser.text_pairs/1` by
  `{code_type, code, old text}` — a note is only rewritten when its stored
  text is exactly the old extraction of that commentary (no drift since the
  last parse) and the ordered text is unambiguous. `rekey/2` maps the
  `change_id`s recorded in `lat_changes` to the ids of the reordered text.
  """

  @type note :: %{
          id: String.t(),
          code_type: String.t(),
          code: String.t(),
          text: String.t()
        }
  @type pair :: {String.t(), String.t(), String.t(), String.t()}

  @doc "Text updates for the stored notes, and how many could not be matched."
  @spec plan([note()], [pair()]) :: %{
          updates: [{String.t(), String.t()}],
          unmatched: non_neg_integer()
        }
  def plan(stored, pairs) do
    ordered =
      Enum.group_by(pairs, fn {t, c, old, _} -> {t, c, old} end, fn {_, _, _, new} -> new end)

    # already ordered (a re-run): the stored text is a commentary's new text
    done = MapSet.new(pairs, fn {t, c, _, new} -> {t, c, new} end)

    Enum.reduce(stored, %{updates: [], unmatched: 0}, fn n, acc ->
      case ordered |> Map.get({n.code_type, n.code, n.text}, []) |> Enum.uniq() do
        [same] when same == n.text ->
          acc

        [new] ->
          %{acc | updates: [{n.id, new} | acc.updates]}

        [] ->
          if MapSet.member?(done, {n.code_type, n.code, n.text}), do: acc, else: unmatched(acc)

        _ ->
          unmatched(acc)
      end
    end)
    |> Map.update!(:updates, &Enum.reverse/1)
  end

  defp unmatched(acc), do: %{acc | unmatched: acc.unmatched + 1}

  @doc "Replace each old change id with its new one; ids without a mapping stay."
  @spec rekey([String.t()], %{String.t() => String.t()}) :: [String.t()]
  def rekey(change_ids, mapping), do: Enum.map(change_ids, &Map.get(mapping, &1, &1))
end
