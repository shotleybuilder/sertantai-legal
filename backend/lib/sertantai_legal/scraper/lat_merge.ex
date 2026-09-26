defmodule SertantaiLegal.Scraper.LatMerge do
  @moduledoc """
  Pure matching of a law's existing LAT rows to a fresh parse, so a re-parse
  keeps provision enrichment instead of wiping it (Gemini review 2026-09-26).

  Old rows are matched to new rows, each new row claimed at most once. Texts
  are compared by `match_key/1`: `LatHash.normalise/1`, then leading
  enumerators that older parser generations left in the text — amendment
  markers (`[F345`), `(11)`, bare provision numbers (`27 `) — are dropped.

  1. `same` — same section_id and: same match key, or the new text contains
     the old (≥ 15 chars; older parsers dropped trailing text). Old text
     containing the new (a parent that aggregated its children, a heading
     now empty) is `changed`: its enrichment described text no longer in
     the row
  2. `unique_text` — old id gone, its text equals exactly one unclaimed new
     row whose id is new, and no other vanished old row has that text: rename
  2b. `extent_tag` — old id gone, and exactly one new id equals it apart
     from its `[extent]` tag (tagging changed between parser generations),
     under the same text rules as 1: rename
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
        MapSet.member?(new_ids, o.section_id) and same_row?(norm(o.text), new_text[o.section_id])
      end)

    changed =
      rest |> Enum.filter(&MapSet.member?(new_ids, &1.section_id)) |> Enum.map(& &1.section_id)

    carry = Map.new(same, &{&1.section_id, &1.section_id})

    # 2. Renames where only the [extent] tag changed (1:1 by id stem)
    vanished = Enum.reject(rest, &MapSet.member?(new_ids, &1.section_id))
    fresh = Enum.reject(new_rows, &MapSet.member?(old_ids, &1.section_id))

    tag_renames = extent_tag_renames(vanished, fresh)
    tagged_old = MapSet.new(tag_renames, & &1.old)
    tagged_new = MapSet.new(tag_renames, & &1.new)
    vanished = Enum.reject(vanished, &MapSet.member?(tagged_old, &1.section_id))
    fresh = Enum.reject(fresh, &MapSet.member?(tagged_new, &1.section_id))

    # 3–4. Renames: remaining vanished vs brand-new ids, grouped by non-empty text
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

    renames = tag_renames ++ renames
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

  defp extent_tag_renames(vanished, fresh) do
    olds = Enum.group_by(vanished, &id_stem(&1.section_id))
    news = Enum.group_by(fresh, &id_stem(&1.section_id))

    for {stem, [o]} <- olds,
        [n] <- [Map.get(news, stem, [])],
        same_row?(norm(o.text), norm(n.text)),
        do: %{old: o.section_id, new: n.section_id, match: "extent_tag"}
  end

  defp id_stem(id), do: String.replace(id, ~r/\[[^\]]*\]$/, "")

  defp group_by_text(rows) do
    rows
    |> Enum.group_by(&norm(&1.text))
    |> Map.delete("")
  end

  # Leading markers older parser generations kept in the text.
  @leading_marker ~r/^(\[F\d+\s*|\([0-9A-Za-z]{1,6}\)\s*|\d+[A-Z]*\s+)+/

  @doc "Comparison key: normalised text without leading enumerators / amendment markers."
  @spec match_key(String.t() | nil) :: String.t()
  def match_key(text) do
    text
    |> LatHash.normalise()
    |> String.replace(~r/\s+([—–,;:.])/u, "\\1")
    |> String.replace(@leading_marker, "")
  end

  @min_contained 15

  # Same id: equal keys, or the new text contains the old one (older parsers
  # dropped trailing text). Not when the old contains the new (a parent that
  # used to aggregate its children, or a heading now empty): the old
  # enrichment would attribute the children's duties/actors to the
  # stripped-down row — aligned with fractalaw's diff-apply.
  @doc "Whether a same-id (or extent-tag) old row may carry onto the new row, given their match keys."
  @spec same_row?(String.t(), String.t()) :: boolean()
  def same_row?(old_key, new_key) do
    old_key == new_key or (old_key != "" and contained?(new_key, old_key))
  end

  defp contained?(outer, inner),
    do: String.length(inner) >= @min_contained and String.contains?(outer, inner)

  defp norm(text), do: match_key(text)
end
