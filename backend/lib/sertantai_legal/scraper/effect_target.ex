defmodule SertantaiLegal.Scraper.EffectTarget do
  @moduledoc """
  Where an effect lands in a document (lat-refactor LR-29): the element ids
  of the provisions it changed, at the granularity its own text states.

  An effect carries two descriptions of its target, both legislation.gov.uk's
  data about the effect (never a note):
  - its `AffectedProvisions` text — the true granularity ("s. 27ZA and
    cross-heading", "Pt. 2 Ch. 3", "s. 50 - 55"), read by `ProvisionText`;
  - its structured refs — sometimes coarser (only the container) or
    truncated (a range's first id).

  The effect lands where its text says; the refs are the fallback when the
  text can't be read or names nothing the document holds, and a cross-check:
  text and refs covering nothing in common keep the refs and are marked
  `:disagree` (a gap for review, never a guess). Measured over the store
  (LR-29): text and refs agree for 94.5% of effects; the text narrows 0.9%
  (container over-reach) and widens 0.2% (truncated ranges).

  Granularity of the ids returned (as before LR-29): a provision gives its
  own id (its sub-provisions are reached through their ancestors); a Part,
  Chapter or Schedule named gives itself and every element inside it; a
  "cross-heading" is the heading element alone (provisions inserted with it
  are named in the text); a range gives every id in its span.

  Pure: `tree/1` reads an already-parsed document.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.ProvisionText

  @enforce_keys [:order, :positions, :inside]
  defstruct @enforce_keys

  @typedoc "A document's ids in order, each id's positions, and each element's ids inside it."
  @type t :: %__MODULE__{
          order: [String.t()],
          positions: %{String.t() => [non_neg_integer()]},
          inside: %{String.t() => [String.t()]}
        }

  @type source :: :text | :refs | :disagree

  @roman ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX XXI XXII XXIII XXIV XXV)

  @doc "A document's element tree (an xmerl document or element)."
  @spec tree(tuple()) :: t()
  def tree(doc) do
    els = xpath(doc, ~x"//*[@id]"l)
    order = Enum.map(els, &to_string(xpath(&1, ~x"./@id"s)))

    inside =
      Map.new(Enum.zip(order, els), fn {id, el} ->
        {id, el |> xpath(~x".//*/@id"ls) |> Enum.map(&to_string/1)}
      end)

    %__MODULE__{order: order, positions: positions(order), inside: inside}
  end

  @doc "An ids-only tree (no containment): ranges resolve, containers don't expand."
  @spec flat([String.t()]) :: t()
  def flat(order), do: %__MODULE__{order: order, positions: positions(order), inside: %{}}

  defp positions(order),
    do: order |> Enum.with_index() |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

  @doc "The ids an effect lands on, and where they came from."
  @spec resolve(Effect.t(), t()) :: {source(), [String.t()]}
  def resolve(%Effect{} = e, %__MODULE__{} = tree) do
    refs = refs(e, tree)

    with {:ok, designators} <- ProvisionText.parse(e.affected_provisions),
         false <- :whole in designators,
         {:ok, ids} <- designated(designators, e, tree) do
      if refs != [] and disjoint?(cover(ids, tree), cover(refs, tree)),
        do: {:disagree, refs},
        else: {:text, ids}
    else
      _ -> {:refs, refs}
    end
  end

  @doc """
  Every id from `first` to `last` in document order, taking the smallest
  span: versions repeat ids later, so an end's first occurrence can lie far
  from its start (1990/43 s.34(2A)-(2D)). [] when either end isn't held.
  """
  @spec span(t(), String.t(), String.t()) :: [String.t()]
  def span(%__MODULE__{order: order, positions: positions}, first, last) do
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
  end

  # the structured refs as given: exact ids and range spans
  defp refs(e, tree) do
    (e.affected_refs || []) ++
      Enum.flat_map(e.affected_ranges || [], fn {a, b} -> span(tree, a, b) end)
  end

  defp designated(designators, e, tree) do
    ids = Enum.map(designators, &ids(&1, e, tree))

    if Enum.any?(ids, &(&1 == [])),
      do: :error,
      else: {:ok, ids |> Enum.concat() |> Enum.uniq()}
  end

  defp ids({:provision, kind, n, [], nil}, _e, tree), do: held(tree, ["#{kind}-#{n}"])

  defp ids({:provision, kind, n, path, to}, _e, tree) when is_binary(to) do
    parent = Enum.join(["#{kind}-#{n}" | Enum.drop(path, -1)], "-")
    span(tree, "#{parent}-#{List.last(path)}", "#{parent}-#{to}")
  end

  defp ids({:provision, kind, n, path, nil}, _e, tree) do
    base = "#{kind}-#{n}"
    full = Enum.join([base | path], "-")

    # brackets with no space are a path ("33(1)(e)"); a list when the path
    # isn't held ("36(1)(2)": subsections 1 and 2)
    each = Enum.map(path, &"#{base}-#{&1}")

    cond do
      held(tree, [full]) != [] -> [full]
      length(held(tree, each)) == length(each) -> each
      true -> []
    end
  end

  defp ids({:range, kind, a, b}, _e, tree), do: span(tree, "#{kind}-#{a}", "#{kind}-#{b}")
  defp ids({:element, kind, n}, _e, tree), do: held(tree, ["#{kind}-#{n}"])

  defp ids({:part, p, c}, _e, tree),
    do: tree |> part_id(p, c) |> container(tree)

  defp ids({:part_element, p, c}, _e, tree), do: tree |> part_id(p, c) |> List.wrap()

  defp ids({:schedule, s, nil}, _e, tree), do: container("schedule-#{s}", tree)
  defp ids({:schedule, s, para}, _e, tree), do: held(tree, ["schedule-#{s}-paragraph-#{para}"])

  # "cross-heading": the heading element the refs name, never what sits
  # under it (provisions inserted with it are named: "ss. 27U-27Y and
  # cross-heading")
  defp ids(:heading, e, tree),
    do: held(tree, Enum.filter(e.affected_refs || [], &(&1 =~ ~r/crossheading|pblock/i)))

  defp ids(:whole, _e, _tree), do: []

  # "Pt. 1" / "Ch. 3" in Arabic numerals, ids sometimes in Roman (part-I)
  defp part_id(tree, p, c) do
    for pp <- Enum.uniq([p, roman(p)]),
        cc <- Enum.uniq([c, roman(c)]),
        id = if(c, do: "part-#{pp}-chapter-#{cc}", else: "part-#{pp}"),
        Map.has_key?(tree.positions, id) do
      id
    end
    |> List.first()
  end

  defp roman(nil), do: nil

  defp roman(n) do
    case Integer.parse(n) do
      {i, ""} when i in 1..length(@roman)//1 -> Enum.at(@roman, i - 1)
      _ -> n
    end
  end

  defp container(nil, _tree), do: []

  defp container(id, tree) do
    if Map.has_key?(tree.positions, id), do: [id | Map.get(tree.inside, id, [])], else: []
  end

  defp held(tree, ids), do: Enum.filter(ids, &Map.has_key?(tree.positions, &1))

  # everything ids reach: themselves and what's inside them
  defp cover(ids, tree),
    do: MapSet.new(ids ++ Enum.flat_map(ids, &Map.get(tree.inside, &1, [])))

  defp disjoint?(a, b), do: MapSet.disjoint?(a, b)
end
