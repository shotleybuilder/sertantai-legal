defmodule SertantaiLegal.Scraper.LatTerritory do
  @moduledoc """
  Where a LAT row's words apply (LAT Parser Refactor, LR-02; design
  `docs/LAT-PARSER-REFACTOR-DESIGN.md`, rules `docs/LAT-QA-SAMPLE-SPEC.md`).

  One rule for every change: its territory is its `Extent` attribute and
  the territory its commentary note names, together (`territory/2`). The
  parser builds row text as `LatSegments`; this module turns them into the
  stored text and `excluded_extent` once the row's extent is known.

  Handles:
  - `territory/2` — a change's territory (attribute ∪ note)
  - `pair_up/1` — joins substitution halves that are not siblings
  - `render/4` — the row text: words bracketed with where they apply
    ("[E+W: words]"), substitutions as "[S: new] [E+W: old]", nested
    changes within their outer change's territory, plain when a change
    covers the row, misses it, or the whole row is territorial
  - `excluded/3` — the row's `excluded_extent` when its own words are all
    retained-repealed (their territories; none named → the whole extent)
    or all inserted for a narrower territory (the rest of the extent). The
    outermost change decides; insertions with no territory are transparent.

  Pure: the note territories come in as `lookup` (`%{commentary_id =>
  code | nil}`). Extent codes are "E+W+S+NI" forms; nil extent = the UK.
  """

  alias SertantaiLegal.Scraper.{LatSegments, Territory}

  defmodule Change do
    @moduledoc """
    A change in the text: `:keep` (words repealed but retained for other
    territories), `:ins` (words inserted or substituted) or `:pair` (a
    substitution's two versions), with its `Extent` attribute and
    commentary ref.
    """
    @enforce_keys [:kind]
    defstruct [:kind, :attribute, :ref]

    @type t :: %__MODULE__{
            kind: :keep | :ins | :pair,
            attribute: String.t() | nil,
            ref: String.t() | nil
          }
  end

  # note id → what the note says (`NoteTerritory`, `AmendmentNote.effect_of/1`)
  @type note :: %{applies: [String.t()], in_force: String.t() | nil, effect: String.t()}
  @type lookup :: %{String.t() => note()}

  @doc """
  A change's territory; nil when nothing names one. Notes are read as
  legislation.gov.uk documents them (`docs/LEGISLATION-GOV-UK-NOTE-TYPOLOGY.md`):

  - its `Extent` attribute — where the change applies — plus any bare
    "(X.)" clause of its note disjoint from it (a separate change: "repealed
    (E.W.) …; and … repealed (S.)" with Extent="S"; an overlapping clause is
    the same fact);
  - else the note's bare "(X.)" clauses (`NoteTerritory.applies/1`: the
    Extent attribute in words);
  - else, for a change that removes text (a retained repeal, a
    substitution's old words), where it is in force (`NoteTerritory.in_force/1`,
    "repealed (1.4.2015 for S.)"): the text is gone there and kept
    elsewhere. An insertion in force for some territories still extends to
    the others — commencement, which is status, not territory.

  A note counts only for a change of its kind: an insertion takes an
  inserting/substituting note, a retained repeal any but an inserting one
  (legacy markup wraps text in an Addition citing a repeal note: 1875/17
  s.115), a substitution pair any note.
  """
  @spec territory(Change.t(), lookup()) :: String.t() | nil
  def territory(%Change{kind: kind, attribute: attribute, ref: ref}, lookup) do
    note = note_for(kind, ref, lookup)
    applies = if note, do: note.applies, else: []

    case Territory.normalize(attribute) do
      nil ->
        cond do
          applies != [] -> Territory.union(applies)
          note && kind in [:keep, :pair] -> note.in_force
          true -> nil
        end

      attr ->
        Territory.union([attr | Enum.filter(applies, &Territory.disjoint?(&1, attr))])
    end
  end

  @inserting ~w(inserted substituted amended)

  defp note_for(kind, ref, lookup) do
    case ref && Map.get(lookup, ref) do
      %{effect: effect} = note -> if note_fits?(kind, effect), do: note
      _ -> nil
    end
  end

  defp note_fits?(:pair, _effect), do: true
  defp note_fits?(:ins, effect), do: effect in @inserting
  # a retained Repeal citing a substitution note: the old words (its new
  # words may be another row: 1998/494 reg.4(3)(e))
  defp note_fits?(:keep, effect), do: effect != "inserted"

  # ── Pairing ──────────────────────────────────────────────────────

  @doc """
  Substitution halves that are not siblings (each wrapped in other markup):
  the pair renders where the first old piece sits, its old version every
  old piece with that id, its new version every new piece; the other pieces
  leave their places, with the whitespace that separated them (an old
  version split over several Repeals, the new one nested in the last:
  1962/58 s.1(5)). Unmatched halves read as ordinary changed words; a
  SubstitutionRef naming its own enclosing change is no pair (1996/18
  s.75A(1A)(c)).
  """
  @spec pair_up(LatSegments.t()) :: LatSegments.t()
  def pair_up(segments) do
    news = collect_news(segments, %{}) |> Map.drop(self_enclosing(segments))
    olds = collect_olds(segments, %{})
    matched = MapSet.intersection(MapSet.new(Map.keys(news)), MapSet.new(Map.keys(olds)))

    {paired, _done} =
      pair_segments(segments, %{news: news, olds: olds, matched: matched}, MapSet.new())

    drop_moved(paired)
  end

  # id → every new piece {change, inner}, in document order
  defp collect_news(segments, acc) do
    Enum.reduce(segments, acc, fn
      {:pair_new, id, change, inner}, acc ->
        acc = collect_news(inner, acc)

        if holds_old?(inner, id),
          do: acc,
          else: Map.update(acc, id, [{change, inner}], &(&1 ++ [{change, inner}]))

      seg, acc ->
        Enum.reduce(children(seg), acc, &collect_news/2)
    end)
  end

  # ids of changes whose SubstitutionRef names themselves (an old half inside
  # its own enclosing change): never a pair, whatever sibling pieces share
  # the id (1968/73 s.113(5))
  defp self_enclosing(segments) do
    Enum.flat_map(segments, fn
      {:pair_new, id, _change, inner} ->
        if(holds_old?(inner, id), do: [id], else: []) ++ self_enclosing(inner)

      seg ->
        seg |> children() |> Enum.flat_map(&self_enclosing/1)
    end)
  end

  # ref → every old piece's inner segments, in document order
  defp collect_olds(segments, acc) do
    Enum.reduce(segments, acc, fn
      {:pair_old, ref, _change, inner}, acc ->
        Map.update(collect_olds(inner, acc), ref, [inner], &(&1 ++ [inner]))

      seg, acc ->
        Enum.reduce(children(seg), acc, &collect_olds/2)
    end)
  end

  defp holds_old?(segments, id) do
    Enum.any?(segments, fn
      {:pair_old, ^id, _change, _inner} -> true
      seg -> seg |> children() |> Enum.any?(&holds_old?(&1, id))
    end)
  end

  defp children({:words, _c, inner}), do: [inner]
  defp children({:aside, inner}), do: [inner]
  defp children({:pair, _c, new, old}), do: [new, old]
  defp children({:pair_old, _ref, _c, inner}), do: [inner]
  defp children({:pair_new, _id, _c, inner}), do: [inner]
  defp children(_seg), do: []

  defp pair_segments(segments, pairs, done) do
    Enum.flat_map_reduce(segments, done, fn seg, done -> pair_segment(seg, pairs, done) end)
  end

  defp pair_segment({:pair_old, ref, change, inner}, pairs, done) do
    cond do
      not MapSet.member?(pairs.matched, ref) ->
        {old, done} = pair_segments(inner, pairs, done)
        {[{:words, %{change | kind: :keep}, old}], done}

      # a later piece: already in the pair
      MapSet.member?(done, ref) ->
        {[:moved], done}

      true ->
        done = MapSet.put(done, ref)

        {old, done} =
          pairs.olds
          |> Map.fetch!(ref)
          |> Enum.flat_map_reduce(done, &pair_segments(&1, pairs, &2))

        pieces = Map.fetch!(pairs.news, ref)

        {new, done} =
          pieces
          |> Enum.map(&elem(&1, 1))
          |> Enum.flat_map_reduce(done, &pair_segments(&1, pairs, &2))

        {new_change, _} = hd(pieces)

        pair_change = %Change{
          kind: :pair,
          attribute: change.attribute || new_change.attribute,
          ref: change.ref
        }

        {[{:pair, pair_change, drop_moved(new), drop_moved(old)}], done}
    end
  end

  defp pair_segment({:pair_new, id, change, inner}, pairs, done) do
    if MapSet.member?(pairs.matched, id) and not holds_old?(inner, id) do
      {[:moved], done}
    else
      {new, done} = pair_segments(inner, pairs, done)
      {[{:words, %{change | kind: :ins}, new}], done}
    end
  end

  defp pair_segment({:words, change, inner}, pairs, done) do
    {paired, done} = pair_segments(inner, pairs, done)

    # everything in it moved into a pair: it moved too
    if paired != [] and Enum.all?(paired, &(&1 == :moved)),
      do: {[:moved], done},
      else: {[{:words, change, paired}], done}
  end

  defp pair_segment({:aside, inner}, pairs, done) do
    {inner, done} = pair_segments(inner, pairs, done)
    {[{:aside, inner}], done}
  end

  defp pair_segment({:pair, change, new, old}, pairs, done) do
    {new, done} = pair_segments(new, pairs, done)
    {old, done} = pair_segments(old, pairs, done)
    {[{:pair, change, new, old}], done}
  end

  defp pair_segment(seg, _pairs, done), do: {[seg], done}

  # A piece that moved into its pair leaves `:moved`; the whitespace that
  # separated it goes too ("293[W: B] [E: A], or", not "… , or").
  defp drop_moved(segments) do
    {kept, _} =
      segments
      |> Enum.reverse()
      |> Enum.reduce({[], false}, fn
        :moved, {acc, _after_moved} ->
          {acc, true}

        {:text, s} = seg, {acc, true} ->
          if String.trim(s) == "", do: {acc, false}, else: {[seg | acc], false}

        seg, {acc, _after_moved} ->
          {[drop_moved_inside(seg) | acc], false}
      end)

    kept
  end

  defp drop_moved_inside({:words, change, inner}), do: {:words, change, drop_moved(inner)}
  defp drop_moved_inside({:aside, inner}), do: {:aside, drop_moved(inner)}

  defp drop_moved_inside({:pair, change, new, old}),
    do: {:pair, change, drop_moved(new), drop_moved(old)}

  defp drop_moved_inside(seg), do: seg

  # ── Rendering ────────────────────────────────────────────────────

  @doc """
  The row text: segments rendered for the row's `extent`, whitespace
  collapsed, adjacent brackets for the same territories merged; nil when
  blank. With the row's `excluded_extent`, it renders within where the row
  is live: a change covering that reads plain (the column carries it), a
  narrower one keeps its bracket; live nowhere → all plain.
  """
  @spec render(LatSegments.t(), String.t() | nil, lookup(), String.t() | nil) :: String.t() | nil
  def render(segments, extent, lookup, excluded \\ nil) do
    segments
    |> render_row(extent, lookup, excluded)
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
    |> merge_brackets()
    |> case do
      "" -> nil
      text -> text
    end
  end

  defp render_row(segments, extent, lookup, nil),
    do: render_segments(segments, extent, lookup, false)

  defp render_row(segments, extent, lookup, excluded) do
    case Territory.subtract(whole(extent), excluded) do
      nil -> render_segments(segments, extent, lookup, true)
      live -> render_segments(segments, live, lookup, false)
    end
  end

  # `plain`: no brackets at all (a row live nowhere)
  defp render_segments(segments, extent, lookup, plain),
    do: Enum.map_join(segments, &render_segment(&1, extent, lookup, plain))

  defp render_segment({kind, s}, _extent, _lookup, _plain) when kind in [:text, :mark], do: s

  defp render_segment({:aside, inner}, extent, lookup, plain),
    do: render_segments(inner, extent, lookup, plain)

  defp render_segment({:pair_old, _ref, change, inner}, extent, lookup, plain),
    do: render_segment({:words, %{change | kind: :keep}, inner}, extent, lookup, plain)

  defp render_segment({:pair_new, _id, change, inner}, extent, lookup, plain),
    do: render_segment({:words, %{change | kind: :ins}, inner}, extent, lookup, plain)

  defp render_segment({:words, _change, inner}, extent, lookup, true),
    do: render_segments(inner, extent, lookup, true)

  defp render_segment({:words, %Change{kind: :keep} = change, inner}, extent, lookup, false) do
    live = live_after(change, extent, lookup)

    # repealed everywhere the row applies, or only where it doesn't: plain
    if live in [nil, whole(extent)],
      do: render_segments(inner, extent, lookup, false),
      else: bracket(live, render_segments(inner, live, lookup, false))
  end

  defp render_segment({:words, %Change{kind: :ins} = change, inner}, extent, lookup, false) do
    t = territory(change, lookup)

    if t == nil or outside?(extent, t) or Territory.covers?(t, extent),
      do: render_segments(inner, extent, lookup, false),
      else: bracket(within(extent, t), render_segments(inner, within(extent, t), lookup, false))
  end

  defp render_segment({:pair, change, new, old}, extent, lookup, true),
    do: render_segment({:pair, change, new, old}, extent, lookup, false)

  defp render_segment({:pair, change, new, old}, extent, lookup, false) do
    new_text = fn ext -> new |> render_segments(ext, lookup, false) |> String.trim() end
    old_text = fn ext -> old |> render_segments(ext, lookup, false) |> String.trim() end

    case territory(change, lookup) do
      nil ->
        old_text.(extent) <> " " <> new_text.(extent)

      t ->
        rest = Territory.subtract(extent, t)

        cond do
          rest == nil ->
            new_text.(extent)

          rest == whole(extent) ->
            old_text.(extent)

          true ->
            "[#{within(extent, t)}: #{new_text.(within(extent, t))}] [#{rest}: #{old_text.(rest)}]"
        end
    end
  end

  # where retained words are live: the extent outside the repeal's territory;
  # the whole extent when it names none
  defp live_after(change, extent, lookup) do
    case territory(change, lookup) do
      nil -> whole(extent)
      t -> Territory.subtract(extent, t)
    end
  end

  # the row's extent as a code (nil = the UK)
  defp whole(extent), do: Territory.subtract(extent, "")

  defp outside?(extent, t), do: Territory.subtract(extent, t) == whole(extent)

  # the part of `extent` within `t`
  defp within(extent, t), do: Territory.subtract(extent, Territory.subtract(extent, t) || "")

  # "[E+W: words]", the words' edge whitespace kept outside the brackets
  defp bracket(label, words) do
    case String.trim(words) do
      "" ->
        words

      trimmed ->
        lead = if String.match?(words, ~r/\A\s/u), do: " ", else: ""
        trail = if String.match?(words, ~r/\s\z/u), do: " ", else: ""
        lead <> "[#{label}: #{trimmed}]" <> trail
    end
  end

  # "[S: the 1993 Act] [S: , and]" → "[S: the 1993 Act , and]": adjacent
  # brackets for the same territories (fragmented markup) merge.
  defp merge_brackets(text) do
    merged = Regex.replace(~r/\[([A-Z+]+): ([^\[\]]*)\](\s*)\[\1: /u, text, "[\\1: \\2\\3")
    if merged == text, do: text, else: merge_brackets(merged)
  end

  # ── Whole-row territory ──────────────────────────────────────────

  @doc """
  The row's `excluded_extent`: the territories of its extent where none of
  its words is live; nil when some word is live everywhere, the whole
  extent when none is live anywhere.

  Each piece of visible words has a live territory, its changes composed
  from the outside in, from the row's extent: a retained repeal removes its
  territory (naming none: live nowhere — retained for purposes/savings);
  an insertion narrows to where it applies; an insertion naming no
  territory, or one outside the row (an England insertion in a Welsh
  version), changes nothing; one inside a retained repeal changes nothing
  when within the live territory (it is bracketed: 1967/10 s.29(1)(a)) and
  leaves the words live nowhere when outside it (1990/43 s.6(6A)(c)).

  The row's own words decide; a row with none is judged on its
  sub-provisions (the caller passes their segments). Numbers, titles, list
  labels, asides, and punctuation alone outside any change don't count.
  """
  @spec excluded(LatSegments.t(), String.t() | nil, lookup()) :: String.t() | nil
  def excluded(segments, extent, lookup) do
    whole = whole(extent)

    case pieces(segments, {nil, whole}, whole, lookup) do
      [] -> nil
      pieces -> outside(whole, pieces |> Enum.map(&elem(&1, 1)) |> union_live())
    end
  end

  # One {outermost change kind | nil, live territory | nil (= nowhere)} per
  # piece of visible words. `whole` is the row's extent.
  defp pieces(segments, state, whole, lookup),
    do: Enum.flat_map(segments, &piece(&1, state, whole, lookup))

  defp piece({:mark, _s}, _state, _whole, _lookup), do: []
  defp piece({:aside, _inner}, _state, _whole, _lookup), do: []

  # Whitespace never counts; punctuation alone outside any change ("." after
  # a substitution: 2018/482 reg.4(2)(b)) isn't the row's own words, but
  # inside a change it is (". . . ." is a repeal marker: 1967/10 s.1(2A)).
  defp piece({:text, s}, {nil, _live} = state, _whole, _lookup),
    do: if(String.match?(s, ~r/[\p{L}\p{N}]/u), do: [state], else: [])

  defp piece({:text, s}, state, _whole, _lookup),
    do: if(String.trim(s) == "", do: [], else: [state])

  defp piece({:words, change, inner}, {kind, live} = state, whole, lookup) do
    case compose(change, kind, live, whole, lookup) do
      :same -> pieces(inner, state, whole, lookup)
      live -> pieces(inner, {kind || change.kind, live}, whole, lookup)
    end
  end

  # a pair: both versions shown, bracketed within the live territory
  defp piece({:pair, _change, new, old}, {kind, live}, _whole, _lookup) do
    if LatSegments.blank?(new) and LatSegments.blank?(old), do: [], else: [{kind, live}]
  end

  defp piece({:pair_old, _ref, change, inner}, state, whole, lookup),
    do: piece({:words, %{change | kind: :keep}, inner}, state, whole, lookup)

  defp piece({:pair_new, _id, change, inner}, state, whole, lookup),
    do: piece({:words, %{change | kind: :ins}, inner}, state, whole, lookup)

  # The live territory inside a change (`outer`: the outermost change kind
  # around it); :same when it changes nothing.
  defp compose(%Change{kind: :keep} = change, _outer, live, _whole, lookup) do
    case territory(change, lookup) do
      nil -> nil
      t -> if live == nil, do: nil, else: Territory.subtract(live, t)
    end
  end

  defp compose(%Change{} = change, outer, live, whole, lookup) do
    t = territory(change, lookup)

    cond do
      t == nil or Territory.disjoint?(t, whole) -> :same
      live == nil -> nil
      Territory.disjoint?(t, live) -> nil
      outer == :keep -> :same
      true -> intersect(live, t)
    end
  end

  defp intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "")

  defp union_live(lives) do
    case Enum.reject(lives, &is_nil/1) do
      [] -> nil
      present -> Territory.union(present)
    end
  end

  # the extent outside `live`: nil when live is all of it, the whole extent
  # when live is nowhere
  defp outside(whole, nil), do: whole
  defp outside(whole, live), do: if(live == whole, do: nil, else: Territory.subtract(whole, live))
end
