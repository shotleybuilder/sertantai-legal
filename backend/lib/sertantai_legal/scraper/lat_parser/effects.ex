defmodule SertantaiLegal.Scraper.LatParser.Effects do
  @moduledoc """
  The effects layer in the LAT walk (LR-03 / LR-07): joins a law's
  changes-feed effects to its CLML so territory and change facts come from
  markup + effects, never note text.

  - the law's effect index against this document's ids, with orphan
    change markup (`index/3`), and the law's own extent (`law_extent/2`)
  - whole-provision changes an applied effect makes on a provision with no
    joinable markup, inherited by its descendants (`with_whole_provision/2`)
  - a row's segments with territory resolved (`row_segments/4`), its
    excluded extent (`excluded/3`) and its effect ids (`row_effect_ids/4`,
    with their join kinds: `row_effect_joins/4`)

  `ctx` is the walk context (`:effects`, `:provision_changes`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.{
    CommentaryParser,
    EffectIndex,
    EffectTarget,
    LatSegments,
    LatTerritory
  }

  alias SertantaiLegal.Scraper.LatParser.{Text, Xml}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @doc """
  LR-07: the effects on a row — its text's change joins, its whole-provision
  changes and the effects naming its provision (commencement, modification).
  """
  @spec row_effect_ids(LatSegments.t(), LatSegments.t(), map(), tuple()) :: [String.t()]
  def row_effect_ids(segments, whole, ctx, node),
    do: segments |> row_effect_joins(whole, ctx, node) |> Enum.map(&elem(&1, 0))

  @doc """
  LR-23: `row_effect_ids/4` with how each effect reached the row, first join
  kept: `:markup` (a change element in its text), `:whole` (a whole-provision
  change it carries), `:ref` (the effect names its provision).
  """
  @spec row_effect_joins(LatSegments.t(), LatSegments.t(), map(), tuple()) ::
          [{String.t(), :markup | :whole | :ref}]
  def row_effect_joins(segments, whole, ctx, node) do
    joined = for {_ref, id} <- LatTerritory.note_effects(segments), do: {id, :markup}
    claimed = for %{effect_id: id} <- LatTerritory.provenance(whole), id != nil, do: {id, :whole}

    # words-level effects join through the markup only (their ref is coarse)
    named =
      for %{effect_id: id} = e <- EffectIndex.on(ctx.effects, Xml.xml_id(node)),
          id != nil,
          not EffectIndex.words_level?(e),
          do: {id, :ref}

    Enum.uniq_by(joined ++ claimed ++ named, &elem(&1, 0))
  end

  @doc """
  excluded_extent (LatTerritory.excluded/3) from the same segments the
  text is built from: the row's own text decides (its children are rows of
  their own); the whole subtree only when the row has no text of its own.
  Numbers and titles never count (not text).
  """
  @spec excluded(tuple(), String.t() | nil, map()) :: {String.t() | nil, LatSegments.t()}
  def excluded(node, row_extent, ctx) do
    own = node |> Text.text_blocks(:structural) |> Text.join_blocks()

    segments =
      if(LatSegments.blank?(own),
        do: node |> Text.text_blocks(:leaf) |> Text.join_blocks(),
        else: own
      )
      |> row_segments(ctx, row_extent, node)

    {LatTerritory.excluded(segments, row_extent), segments}
  end

  @doc """
  The law's effects (`context.effects`: a list of ChangesFeed effects, or an
  EffectIndex), indexed against this document's ids in order (ranges).
  """
  @spec index([Effect.t()] | EffectIndex.t() | nil, tuple(), String.t() | nil) :: EffectIndex.t()
  def index(nil, _doc, _law_extent), do: EffectIndex.empty()
  def index(%{by_id: _, by_ref: _} = index, _doc, _law_extent), do: index

  def index(effects, doc, law_extent) when is_list(effects) do
    index =
      EffectIndex.new(
        effects,
        doc |> xpath(~x"//@id"ls) |> Enum.map(&to_string/1),
        law_extent,
        EffectTarget.tree(doc)
      )

    changes = change_occurrences(doc, index)
    cites = CommentaryParser.cited_laws(doc)

    # LR-19 D2: effects another change owns — joined by their own markup, or
    # with their own note — and the law each orphan's note cites
    held =
      MapSet.new(
        for({_, _, _, _, id} <- changes, id != nil, do: id) ++
          for(
            id <- doc |> xpath(~x"//Commentaries/Commentary/@id"ls) |> Enum.map(&to_string/1),
            EffectIndex.get(index, id) != nil,
            do: id
          )
      )

    orphans = for {change_id, _ref, path, kind, nil} <- changes, do: {change_id, path, kind}

    cited =
      for {change_id, ref, _, _, nil} <- changes,
          law = cites[ref],
          law != nil,
          into: %{},
          do: {change_id, law}

    EffectIndex.with_orphans(index, orphans, held: held, cited: cited)
  end

  # every change element: {ChangeId, its CommentaryRef, the ids of the
  # elements holding it (outermost first), kind, the id of the effect its ids
  # join | nil (an orphan)}, in document order (EffectIndex.with_orphans/3).
  # A walk carrying the path: xpath's ancestor axis is lost on nodes
  # selected from a list.
  defp change_occurrences(node, index, path \\ [])

  defp change_occurrences(node, index, path) when elem(node, 0) == :xmlElement do
    path =
      case Xml.blank_to_nil(Xml.attr(node, :id)) do
        nil -> path
        id -> path ++ [id]
      end

    own =
      with name when name in ~w(Addition Substitution Repeal) <- Xml.local_name(elem(node, 1)),
           change_id when change_id != nil <- Xml.change_id(node) do
        ref = Xml.blank_to_nil(Xml.attr(node, :CommentaryRef))
        joined = EffectIndex.for(index, change_id, ref)

        [
          {change_id, ref, path, if(name == "Repeal", do: :keep, else: :ins),
           joined && joined.effect_id}
        ]
      else
        _ -> []
      end

    own ++ Enum.flat_map(elem(node, 8), &change_occurrences(&1, index, path))
  end

  defp change_occurrences(_node, _index, _path), do: []

  @type_extent %{
    "ssi" => "S",
    "asp" => "S",
    "aosp" => "S",
    "nisr" => "NI",
    "nisi" => "NI",
    "nia" => "NI",
    "apni" => "NI",
    "mnia" => "NI",
    "wsi" => "E+W",
    "anaw" => "E+W",
    "asc" => "E+W",
    "mwa" => "E+W"
  }

  @doc """
  The law's own extent for territory (not stored on rows): the document's
  RestrictExtent, else its type's — a devolved instrument extends only
  there (LR-03: an SSI amended by an SSI is not "narrower than the UK").
  """
  @spec law_extent(tuple() | String.t(), map()) :: String.t() | nil
  def law_extent(doc, context),
    do: Xml.root_extent(doc) || Map.get(@type_extent, Map.get(context, :type_code))

  @doc """
  The extent a law's type fixes by its legislature (an SSI: S; a WSI: E+W;
  NI instruments: NI); nil for UK types (LR-26: a row with no extent of its
  own takes it; a UK Act or SI with none stays unknown).
  """
  @spec type_extent(String.t() | nil) :: String.t() | nil
  def type_extent(type_code), do: Map.get(@type_extent, type_code)

  @doc """
  A row's segments with territory resolved from the effects layer
  (LatTerritory.resolve/2), inside any whole-provision changes it inherits.
  """
  @spec row_segments(LatSegments.t(), map(), String.t() | nil, tuple()) :: LatSegments.t()
  def row_segments(segments, ctx, extent, node) do
    ctx.provision_changes
    |> Enum.reduce(segments, fn change, inner -> [{:words, change, inner}] end)
    |> LatTerritory.resolve(ctx.effects, extent, Xml.xml_id(node))
  end

  @doc """
  Rule 3 (LR-03): an applied effect repealing or inserting this whole
  provision, when none of the provision's change markup joins an effect
  (none at all, or legacy ids only — Jason 2026-10-09), is an outermost
  change on it and its descendants (1974/40 s.101 "repealed (S.)": no
  Repeal element; 1974/37 s.78: d29p ids).
  """
  @spec with_whole_provision(map(), tuple()) :: map()
  def with_whole_provision(ctx, node) do
    case EffectIndex.whole_provision(ctx.effects, Xml.xml_id(node)) do
      [] ->
        ctx

      effects ->
        if joinable_markup?(node, ctx.effects) do
          ctx
        else
          held = MapSet.new(ctx.provision_changes, & &1.effect_id)

          changes =
            for e <- effects, not MapSet.member?(held, e.effect_id) do
              kind = if e.type in ~w(inserted added), do: :ins, else: :keep
              %LatTerritory.Change{kind: kind, effect_id: e.effect_id, synthetic: true}
            end

          %{ctx | provision_changes: ctx.provision_changes ++ changes}
        end
    end
  end

  defp joinable_markup?(node, effects) do
    node
    |> Xml.descendants_xmerl([:Addition, :Substitution, :Repeal])
    |> Enum.any?(fn el ->
      EffectIndex.for(
        effects,
        Xml.change_id(el),
        Xml.blank_to_nil(Xml.attr(el, :CommentaryRef))
      ) !=
        nil
    end)
  end
end
