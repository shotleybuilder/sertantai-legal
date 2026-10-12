defmodule SertantaiLegal.Scraper.EffectIndex do
  @moduledoc """
  A law's effects (legislation.gov.uk changes feed, `ChangesFeed.Effect`)
  indexed for the LAT (lat-refactor LR-03; plan `docs/LAT-EFFECTS-LAYER-PLAN.md`).

  Handles:
  - `new/1` — by effect id and by structured affected ref (`section-101`)
  - `effect_id/1` — a markup `ChangeId` ("key-<hex>-<ts>") → its effect id
    ("key-<hex>"); legacy ids (`d29p…`) have none
  - `get/2`, `for_change/2`, `on/2` — lookups
  - `with_orphans/3`, `orphan/2` — one join per law for a change id that
    joins no effect, via `on_provision/4`
  - `parallel/2` — an effect and its parallels (the same change by
    another instrument for another territory)
  - `whole_provision/2` — applied effects that repeal or insert a whole
    provision (not words, not substitutions): rule 3

  Pure.
  """

  alias SertantaiLegal.Scraper.AmendmentNote
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type t :: %{
          by_id: %{String.t() => Effect.t()},
          by_ref: %{String.t() => [Effect.t()]},
          law_extent: String.t() | nil,
          orphans: %{{String.t(), :ins | :keep} => String.t()}
        }

  @whole ~w(repealed revoked omitted inserted added)

  @doc "An empty index (a law with no effects, or none loaded)."
  @spec empty() :: t()
  def empty, do: %{by_id: %{}, by_ref: %{}, law_extent: nil, orphans: %{}}

  @doc """
  Index effects by id and by affected ref. A range ("ss. 1-30") covers every
  id between its ends in `order` (the document's ids in document order),
  taking the smallest span — versions repeat ids later, so an end's first
  occurrence can lie far from its start (1990/43 s.34(2A)-(2D)). `law_extent` (the
  law's own extent) stands in for an effect's missing `AffectedExtent`, so a
  devolved instrument's amendment isn't read as narrower than the UK.
  """
  @spec new([Effect.t()], [String.t()], String.t() | nil) :: t()
  def new(effects, order \\ [], law_extent \\ nil) do
    positions = order |> Enum.with_index() |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    effects =
      Enum.map(effects, fn e -> %{e | affected_extent: e.affected_extent || law_extent} end)

    %{
      law_extent: law_extent,
      orphans: %{},
      by_id: for(%Effect{effect_id: id} = e <- effects, id != nil, into: %{}, do: {id, e}),
      by_ref:
        effects
        |> Enum.flat_map(fn e ->
          refs = (e.affected_refs || []) ++ in_ranges(e.affected_ranges || [], order, positions)
          refs |> Enum.uniq() |> Enum.map(&{&1, e})
        end)
        |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    }
  end

  defp in_ranges(ranges, order, positions) do
    Enum.flat_map(ranges, fn {first, last} ->
      ends = Map.get(positions, last, [])

      spans =
        for from <- Map.get(positions, first, []),
            to = Enum.find(ends, &(&1 >= from)),
            to != nil,
            do: from..to

      case spans do
        [] -> []
        spans -> Enum.slice(order, Enum.min_by(spans, &Range.size/1))
      end
    end)
  end

  @doc "The effect id in a markup ChangeId; nil for a legacy id."
  @spec effect_id(String.t() | nil) :: String.t() | nil
  def effect_id("key-" <> _ = change_id), do: String.replace(change_id, ~r/-\d+$/, "")
  def effect_id(_change_id), do: nil

  @doc "The effect with this id."
  @spec get(t(), String.t() | nil) :: Effect.t() | nil
  def get(_index, nil), do: nil
  def get(index, id), do: Map.get(index.by_id, id)

  @doc "The effect behind a markup ChangeId."
  @spec for_change(t(), String.t() | nil) :: Effect.t() | nil
  def for_change(index, change_id), do: get(index, effect_id(change_id))

  @doc """
  The effect behind a change: by its `ChangeId`, else by a `key-` commentary
  ref — the effect id itself, a structured join (an `M_F_` ChangeId carries
  one: 1993/11 s.20); a note's text is never read.
  """
  @spec for(t(), String.t() | nil, String.t() | nil) :: Effect.t() | nil
  def for(index, change_id, ref) do
    for_change(index, change_id) ||
      if(is_binary(ref) and String.starts_with?(ref, "key-"), do: get(index, ref))
  end

  @doc """
  The effect and its parallels: applied effects of the same type naming the
  same provision — legislation.gov.uk records one change made separately for
  E and for W (or S and NI) by two instruments, keying the markup to only one
  of them (uksi 2000/1043 reg.11(3)). The effect itself first.
  """
  @spec parallel(t(), Effect.t()) :: [Effect.t()]
  def parallel(index, %Effect{} = effect) do
    others =
      effect
      |> same_provision(index)
      |> Enum.filter(
        &(&1.effect_id != effect.effect_id and &1.applied == true and &1.type == effect.type and
            &1.affected_provisions == effect.affected_provisions)
      )
      |> Enum.uniq_by(& &1.effect_id)

    [effect | others]
  end

  # effects naming the effect's provisions: by structured ref; a
  # whole-instrument effect has none ("Regulations": uksi 1996/972)
  defp same_provision(%Effect{affected_refs: refs}, index) when refs not in [nil, []],
    do: Enum.flat_map(refs, &on(index, &1))

  defp same_provision(_effect, index), do: Map.values(index.by_id)

  @doc """
  The effect behind a change whose ids join none (an orphan `ChangeId`:
  2013/32 s.89(8)(h); a legacy `d29p…` id: 1981/69 s.41): the one applied
  effect on the row's provision whose type fits the change's kind —
  insertions and substitutions for `:ins`, repeals for `:keep`,
  substitutions for `:pair` — else the nearest ancestor's whole-provision
  effect of that kind (2010/2214 "Regs. 18A-18E inserted"). Parallels
  count as one; any other ambiguity is no join. The join is structural
  (`AffectedProvisions`), never a note's text.
  """
  @spec on_provision(t(), String.t() | nil, :ins | :keep | :pair, (Effect.t() -> boolean())) ::
          Effect.t() | nil
  def on_provision(index, ref, kind, keep? \\ fn _ -> true end)

  def on_provision(_index, nil, _kind, _keep?), do: nil

  def on_provision(index, ref, kind, keep?) do
    own = index |> on(ref) |> Enum.filter(&(fits?(kind, &1.type || "") and keep?.(&1)))

    candidates =
      case applied(own) do
        [] -> ref |> ancestors() |> Enum.find_value([], &whole_of_kind(index, &1, kind, keep?))
        found -> found
      end

    one(candidates)
  end

  defp applied(effects),
    do: effects |> Enum.filter(&(&1.applied == true)) |> Enum.uniq_by(& &1.effect_id)

  defp whole_of_kind(index, ref, kind, keep?) do
    case index
         |> whole_provision(ref)
         |> Enum.filter(&(fits?(kind, &1.type) and keep?.(&1)))
         |> applied() do
      [] -> nil
      found -> found
    end
  end

  # "section-41-2-a" → ["section-41-2", "section-41"]
  defp ancestors(ref) do
    case String.split(ref, "-") do
      [_kind, _number | path] when path != [] ->
        parent = ref |> String.split("-") |> Enum.drop(-1) |> Enum.join("-")
        [parent | ancestors(parent)]

      _ ->
        []
    end
  end

  defp one(candidates) do
    case candidates do
      [e | rest] ->
        if Enum.all?(
             rest,
             &(&1.type == e.type and &1.affected_provisions == e.affected_provisions)
           ),
           do: e

      [] ->
        nil
    end
  end

  # the type's leading verb, after an optional noun ("words substituted",
  # "sum substituted for words", "repealed in part (S)"); never a word later
  # in its text ("applied (with modifications) … (as inserted)": 1990/8) or
  # a change to an earlier amending provision
  @type_verb ~r/^(?:(?:words?|sums?|entry|entries|heading|sub-heading|definitions?) )?(inserted|added|substituted|repealed|repeal|revoked|omitted)\b(?! in earlier amending)/

  @words ~r/^(?:words?|sums?|entry|entries|figures?|definitions?|letters?|amounts?|expressions?|(?:[a-z]+\.\s*[\w()]+\s+)?(?:cross-|sub-)?headings?|titles?)\b/i

  @doc """
  True when an effect changes words in a provision, not the provision
  (LR-07): its structured ref is often only the section ("words
  substituted", ref `section-192A` for s.192A(b)), so it reaches a row only
  through the row's own change markup.
  """
  @spec words_level?(Effect.t()) :: boolean()
  def words_level?(%Effect{type: type}) when is_binary(type), do: Regex.match?(@words, type)
  def words_level?(_effect), do: false

  @doc "True when an effect's type is a substitution (its leading verb)."
  @spec substitution?(Effect.t() | nil) :: boolean()
  def substitution?(%Effect{type: type}) when is_binary(type), do: fits?(:pair, type)
  def substitution?(_effect), do: false

  defp fits?(kind, type) do
    case Regex.run(@type_verb, type, capture: :all_but_first) do
      [verb] -> verb in kind_verbs(kind)
      nil -> false
    end
  end

  defp kind_verbs(:ins), do: ~w(inserted added substituted)
  defp kind_verbs(:keep), do: ~w(repealed repeal revoked omitted)
  defp kind_verbs(:pair), do: ~w(substituted)

  @doc """
  Join each change id that joins no effect (an orphan `key-` id, or a legacy
  `d29p…` id) to one effect for the whole law: an id is one change, so its
  every occurrence of a kind takes the same effect. `occurrences` are `{change_id,
  path, kind}` in document order, the path being the ids of the elements
  holding the occurrence, outermost first. The join is `on_provision/3` at
  the lowest element holding every occurrence — only its whole-provision
  effects when every occurrence is below it (1981/69 s.41: a legacy
  repeal over s.41(1)-(6) is s.41's repeal, not s.41(1)'s own; 1974/37:
  s.18's words substitution isn't s.18(4A)-(4B)'s insertion); else each element
  just below it holding some must give the same effect (2010/2214 "Regs.
  18A-18E inserted", also marked on Part 3's heading).

  LR-19 D2: never an effect another change owns — `held`, the ids of
  effects with their own note or joined by their own markup (1968/47
  s.1(1): a legacy 2002 substitution took asp 2003/3's insertion) — and,
  where the change's note cites a law (`cited`: change id → law), only an
  effect by that law. Else no join.
  """
  @spec with_orphans(t(), [{String.t(), [String.t()], :ins | :keep | :pair}], keyword()) :: t()
  def with_orphans(index, occurrences, opts \\ []) do
    held = Keyword.get(opts, :held, MapSet.new())
    cited = Keyword.get(opts, :cited, %{})

    orphans =
      occurrences
      |> Enum.map(fn {change_id, path, kind} ->
        {change_id, orphan_key(change_id), path, kind}
      end)
      |> Enum.reject(fn {_id, key, _path, _kind} -> get(index, key) != nil end)
      |> Enum.group_by(fn {_id, key, _path, kind} -> {key, kind} end)
      |> Enum.flat_map(fn {{_key, kind} = id, found} ->
        paths = found |> Enum.map(&elem(&1, 2)) |> Enum.uniq()
        law = Enum.find_value(found, &cited[elem(&1, 0)])

        keep? = fn e ->
          not MapSet.member?(held, e.effect_id) and
            (law == nil or (e.affecting != nil and AmendmentNote.same_law?(e.affecting, law)))
        end

        case orphan_effect(index, paths, kind, keep?) do
          nil -> []
          effect -> [{id, effect.effect_id}]
        end
      end)
      |> Map.new()

    %{index | orphans: orphans}
  end

  @doc """
  The effect `with_orphans/2` joined a change id of this kind to; nil if
  none. Each kind joins on its own (one legacy id can mark a repeal and an
  insertion); a pair is either.
  """
  @spec orphan(t(), String.t() | nil, :ins | :keep | :pair) :: Effect.t() | nil
  def orphan(_index, nil, _kind), do: nil

  def orphan(index, change_id, :pair),
    do: orphan(index, change_id, :keep) || orphan(index, change_id, :ins)

  def orphan(index, change_id, kind),
    do: get(index, Map.get(index.orphans, {orphan_key(change_id), kind}))

  defp orphan_key(change_id), do: effect_id(change_id) || change_id

  defp orphan_effect(index, paths, kind, keep?) do
    common =
      Enum.reduce(paths, fn path, acc ->
        acc
        |> Enum.zip(path)
        |> Enum.take_while(fn {a, b} -> a == b end)
        |> Enum.map(&elem(&1, 0))
      end)

    lowest = List.last(common)

    # with every occurrence below it, only the lowest element's whole-
    # provision effects cover them (1974/37: s.18's words substitution
    # isn't the s.18(4A)-(4B) insertion)
    at_lowest =
      if Enum.any?(paths, &(length(&1) == length(common))),
        do: on_provision(index, lowest, kind, keep?),
        else: lowest && index |> whole_of_kind(lowest, kind, keep?) |> List.wrap() |> one()

    at_lowest ||
      paths
      |> Enum.map(&Enum.at(&1, length(common)))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.map(&on_provision(index, &1, kind, keep?))
      |> agreed()
  end

  defp agreed([%Effect{} = e | rest]) do
    if Enum.all?(rest, &(&1 != nil and &1.effect_id == e.effect_id)), do: e
  end

  defp agreed(_), do: nil

  @doc "Effects naming this provision (by structured ref)."
  @spec on(t(), String.t() | nil) :: [Effect.t()]
  def on(_index, nil), do: []
  def on(index, ref), do: Map.get(index.by_ref, ref, [])

  @doc "Applied effects that repeal or insert this whole provision."
  @spec whole_provision(t(), String.t() | nil) :: [Effect.t()]
  def whole_provision(index, ref) do
    index
    |> on(ref)
    |> Enum.filter(&(&1.applied == true and String.trim(&1.type || "") in @whole))
  end
end
