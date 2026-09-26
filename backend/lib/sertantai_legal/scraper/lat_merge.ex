defmodule SertantaiLegal.Scraper.LatMerge do
  @moduledoc """
  Pure matching of a law's existing LAT rows to a fresh parse, so a re-parse
  keeps provision enrichment instead of wiping it (Gemini review 2026-09-26).

  Old rows are matched to new rows (texts compared after
  `LatHash.normalise/1`), each new row claimed at most once:

  1. `same` — same section_id and same text: carry
  2. `unique_text` — old id gone, its text equals exactly one unclaimed new
     row whose id is new, and no other vanished old row has that text: rename
  3. `ordered_text` — equal-sized groups of vanished old / new-id rows with
     the same text: paired in document order (rename)
  4. otherwise: `changed` (same id, text differs), `ambiguous` (text shared
     by unequal groups) or `removed`

  Gate: `lost_unchanged` lists enriched old rows that were not carried
  although their text still exists in the new parse — losing their
  enrichment would be a matching failure, not a real change. Empty-text
  (structural) rows match by id only.
  """

  alias SertantaiLegal.Scraper.LatHash

  defstruct carry: %{}, renames: [], changed: [], ambiguous: [], removed: [], lost_unchanged: []

  @type old_row :: %{
          section_id: String.t(),
          text: String.t() | nil,
          position: integer(),
          enriched: boolean()
        }
  @type new_row :: %{section_id: String.t(), text: String.t() | nil, position: integer()}
  @type t :: %__MODULE__{
          carry: %{String.t() => String.t()},
          renames: [%{old: String.t(), new: String.t(), match: String.t()}],
          changed: [String.t()],
          ambiguous: [String.t()],
          removed: [String.t()],
          lost_unchanged: [String.t()]
        }

  @doc "Match old rows to new rows. `carry` maps new section_id → old section_id."
  @spec plan([old_row()], [new_row()]) :: t()
  def plan(old_rows, new_rows) do
    new_ids = MapSet.new(new_rows, & &1.section_id)
    old_ids = MapSet.new(old_rows, & &1.section_id)
    new_text = Map.new(new_rows, &{&1.section_id, norm(&1.text)})

    # 1. Same id
    {same, rest} =
      Enum.split_with(old_rows, fn o ->
        MapSet.member?(new_ids, o.section_id) and new_text[o.section_id] == norm(o.text)
      end)

    changed =
      rest |> Enum.filter(&MapSet.member?(new_ids, &1.section_id)) |> Enum.map(& &1.section_id)

    carry = Map.new(same, &{&1.section_id, &1.section_id})

    # 2–3. Renames: vanished old ids vs brand-new ids, grouped by non-empty text
    vanished = Enum.reject(rest, &MapSet.member?(new_ids, &1.section_id))
    fresh = Enum.reject(new_rows, &MapSet.member?(old_ids, &1.section_id))

    old_groups = group_by_text(vanished)
    new_groups = group_by_text(fresh)

    {renames, ambiguous} =
      Enum.reduce(old_groups, {[], []}, fn {text, olds}, {ren, amb} ->
        case Map.get(new_groups, text, []) do
          [] ->
            {ren, amb}

          news when length(news) == length(olds) ->
            match = if length(olds) == 1, do: "unique_text", else: "ordered_text"

            pairs =
              Enum.zip(Enum.sort_by(olds, & &1.position), Enum.sort_by(news, & &1.position))
              |> Enum.map(fn {o, n} -> %{old: o.section_id, new: n.section_id, match: match} end)

            {ren ++ pairs, amb}

          _unequal ->
            {ren, amb ++ Enum.map(olds, & &1.section_id)}
        end
      end)

    carry = Enum.reduce(renames, carry, &Map.put(&2, &1.new, &1.old))
    carried_old = MapSet.new(Map.values(carry))

    unmatched = Enum.reject(old_rows, &MapSet.member?(carried_old, &1.section_id))
    changed_set = MapSet.new(changed)
    ambiguous_set = MapSet.new(ambiguous)

    removed =
      unmatched
      |> Enum.map(& &1.section_id)
      |> Enum.reject(&(MapSet.member?(changed_set, &1) or MapSet.member?(ambiguous_set, &1)))

    surviving_texts =
      new_rows |> Enum.map(&norm(&1.text)) |> Enum.reject(&(&1 == "")) |> MapSet.new()

    lost_unchanged =
      for o <- unmatched,
          o.enriched,
          t = norm(o.text),
          t != "" and MapSet.member?(surviving_texts, t),
          do: o.section_id

    %__MODULE__{
      carry: carry,
      renames: renames,
      changed: changed,
      ambiguous: ambiguous,
      removed: removed,
      lost_unchanged: lost_unchanged
    }
  end

  defp group_by_text(rows) do
    rows
    |> Enum.group_by(&norm(&1.text))
    |> Map.delete("")
  end

  defp norm(text), do: LatHash.normalise(text)
end
