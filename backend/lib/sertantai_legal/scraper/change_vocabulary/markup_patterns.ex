defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns do
  @moduledoc """
  The revised text's change markup patterns, in the markup reader's own
  terms (CV-S03). Pure.

  A change is a key: the effect id a ChangeId carries, else the ChangeId
  (`Readers.Markup`), with every change element of it and every note ref
  (`CommentaryRef Ref="key-…"`) naming it. It is classed on each dimension
  the reader decides — one pattern per dimension and value:

  - `key`: the id's grammar (`key-HEX`, `dNpN`, `M_F_U`, `V_W_U`), or a
    note ref only;
  - `operation`: the elements (a Repeal paired with a substitution marked)
    and the operation read;
  - `where`: where its elements sit — the number, a heading, the text, a
    table — or outside any provision;
  - `level`: provision or words, and what made it whole (the number
    wrapped, all the provision's text);
  - `retained`: a Repeal's RetainText;
  - `extent`: the Extent attribute and the territory read;
  - `placement`: how many elements, the provision id they share (its
    grammar, `FeedPatterns.id_shape/1`) and the targets read
    (`FeedPatterns.target_shape/1`), or nowhere;
  - `pointers`: an effect id or a legacy id, and what its note gives
    (the cited law, the amending provisions) — pointers, never facts.

  An example is the smallest element holding all the change's elements and
  note refs (up to a provision with an id, or its heading group) with the
  notes it cites, as XML, and what the reader made of it (`outcome/1`). No
  legislation.gov.uk effect id is kept (they trip push protection): the
  change's own is `key-E`, others `key-E2`, `key-E3`, … in order.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, FeedPatterns}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.EffectIndex

  @type pattern :: {String.t(), String.t()}
  @type set :: {String.t(), String.t(), [Claim.t()]}

  @changes ~w(Addition Substitution Repeal)a
  @effect_key ~r/key-[0-9a-f]{32}/

  @typedoc "A change as the catalogue sees it: its key, elements and note refs."
  @type change :: %{
          key: String.t(),
          elements: [%{change_id: String.t(), kind: atom(), attrs: map(), stack: [tuple()]}],
          refs: [%{stack: [tuple()]}]
        }

  @doc """
  The document's changes, by key: every change element with a ChangeId and
  every note ref carrying an effect id, each with the elements above it
  (root first).
  """
  @spec changes(tuple()) :: %{String.t() => change()}
  def changes(doc) do
    doc
    |> walk([], [])
    |> Enum.reverse()
    |> Enum.group_by(& &1.key)
    |> Map.new(fn {key, items} ->
      {elements, refs} = Enum.split_with(items, &Map.has_key?(&1, :change_id))
      {key, %{key: key, elements: elements, refs: refs}}
    end)
  end

  defp walk({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el, stack, acc) do
    stack = stack ++ [el]
    a = attrs(attrs)

    acc =
      cond do
        name in @changes and a["ChangeId"] ->
          key = Markup.key(a["ChangeId"])
          [%{key: key, change_id: a["ChangeId"], kind: name, attrs: a, stack: stack} | acc]

        name == :CommentaryRef and String.starts_with?(a["Ref"] || "", "key-") ->
          [%{key: a["Ref"], stack: stack} | acc]

        true ->
          acc
      end

    Enum.reduce(children, acc, &walk(&1, stack, &2))
  end

  defp walk(_other, _stack, acc), do: acc

  @doc "The reader's claim sets for one change: `Markup.read/3`, its key only."
  @spec read(String.t() | tuple(), String.t(), String.t() | nil, %{String.t() => String.t()}) ::
          [set()]
  def read(xml_or_doc, key, law, xml_ids \\ %{}) do
    xml_or_doc
    |> Markup.read(law, xml_ids)
    |> Enum.filter(fn {k, _, _} -> k == key end)
    |> Enum.sort_by(fn {k, t, _} -> {k, t} end)
  end

  @doc "The patterns of a change, from it and the reader's claim sets for it."
  @spec patterns(change(), [set()]) :: [pattern()]
  def patterns(change, sets) do
    Enum.uniq([
      {"key", key_shape(change)},
      {"operation", operation(change, sets)},
      {"where", where(change)},
      {"level", level(change, sets)},
      {"retained", retained(change, sets)},
      {"extent", extent(change, sets)},
      {"placement", placement(change, sets)},
      {"pointers", pointers(change, sets)}
    ])
  end

  @doc "A pattern as one string: `dimension: value`."
  @spec key(pattern()) :: String.t()
  def key({dimension, value}), do: "#{dimension}: #{value}"

  # ── key ──────────────────────────────────────────────────────────────

  @doc """
  A ChangeId's grammar: `key-HEX` (an effect id; `key-HEX-N`); a uuid `U`,
  a hex tail after it `H`
  (`M_F_<uuid>-1` → `M_F_U-N`); other numbers `N` (`d29p1234` → `dNpN`).
  """
  @spec id_shape(String.t()) :: String.t()
  def id_shape(change_id) do
    change_id
    |> String.replace(@effect_key, "key-HEX")
    |> String.replace(~r/[0-9a-f]{6,}(?:-[0-9a-f]+){4}/i, "U")
    # a hex tail after a uuid ("V_W_U-fNdNeNccN"): H
    |> String.replace(~r/(?<=U-)[0-9a-f]*\d[0-9a-f]*$/, "H")
    |> String.replace(~r/\d+/, "N")
  end

  defp key_shape(%{elements: []}), do: "note ref only"

  defp key_shape(%{elements: els}),
    do: els |> Enum.map(&id_shape(&1.change_id)) |> Enum.uniq() |> Enum.sort() |> Enum.join(" + ")

  # ── operation, where, level, retained, extent ────────────────────────

  defp operation(%{elements: []}, _sets), do: "none"

  defp operation(%{elements: els}, sets) do
    kinds =
      els
      |> Enum.map(fn e ->
        if e.kind == :Repeal and e.attrs["SubstitutionRef"],
          do: "Repeal(paired)",
          else: "#{e.kind}"
      end)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.join("+")

    "#{kinds} → #{values(sets, :operation)}"
  end

  defp where(%{elements: []}), do: "none"

  defp where(%{elements: els}) do
    els
    |> Enum.map(&place/1)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.join(" + ")
  end

  # where an element sits: its provision's number or heading, a table, the
  # text; outside any provision when no element above it has an id
  defp place(%{stack: stack}) do
    names = Enum.map(stack, &elem(&1, 1))

    cond do
      not Enum.any?(stack, &id?/1) -> "outside provisions"
      :Pnumber in names -> "number"
      :Title in names -> "heading"
      :Tabular in names -> "table"
      true -> "text"
    end
  end

  defp level(%{elements: []}, _sets), do: "none"

  defp level(%{elements: els}, sets) do
    case values(sets, :level) do
      "provision" ->
        if Enum.any?(els, &(place(&1) == "number")),
          do: "provision | number wrapped",
          else: "provision | all its text"

      other ->
        other
    end
  end

  defp retained(%{elements: els}, sets) do
    if Enum.any?(els, &(&1.kind == :Repeal)) do
      raw = els |> Enum.map(&(&1.attrs["RetainText"] || "unset")) |> Enum.uniq() |> Enum.sort()
      "#{Enum.join(raw, "+")} → #{values(sets, :retained)}"
    else
      "not a repeal"
    end
  end

  defp extent(%{elements: els}, sets) do
    raw = els |> Enum.map(&(&1.attrs["Extent"] || "unset")) |> Enum.uniq() |> Enum.sort()
    "#{Enum.join(raw, " | ")} → #{values(sets, :territory)}"
  end

  # ── placement, pointers ──────────────────────────────────────────────

  defp placement(change, sets) do
    stacks = Enum.map(change.elements ++ change.refs, & &1.stack)

    how =
      case length(change.elements) do
        0 -> "note refs only"
        1 -> "one element"
        _ -> "several elements"
      end

    shared =
      case stacks |> common() |> Enum.reverse() |> Enum.find_value(&provision_id/1) do
        nil -> "none"
        id -> FeedPatterns.id_shape(id)
      end

    targets =
      case sets |> Enum.map(&elem(&1, 1)) |> Enum.uniq() do
        [] ->
          "nowhere"

        [t] ->
          target_shape(t)

        ts ->
          "split: " <>
            (ts |> Enum.map(&target_shape/1) |> Enum.uniq() |> Enum.sort() |> Enum.join(", "))
      end

    "#{how} | #{shared} → #{targets}"
  end

  # a target's grammar (`FeedPatterns.target_shape/1`), a source suffix
  # (`s.28n1`) marked rather than numbered
  defp target_shape(target) do
    bare = String.replace(target, ~r/(?<=\d)n\d+/, "")
    shape = FeedPatterns.target_shape(bare)
    if bare == target, do: shape, else: shape <> " (source suffix)"
  end

  defp pointers(%{elements: []}, _sets), do: "none"

  defp pointers(%{key: key}, sets) do
    kind = if EffectIndex.effect_id(key), do: "effect id", else: "legacy"

    gives =
      case {values(sets, :cited), values(sets, :affecting)} do
        {"nil", _} -> "no cited law"
        {_, "nil"} -> "cited law"
        _ -> "cited law + amending provisions"
      end

    "#{kind} | #{gives}"
  end

  # the elements every stack shares, root first
  defp common([first | rest]) do
    Enum.reduce(rest, first, fn s, acc ->
      acc
      |> Enum.zip(s)
      |> Enum.take_while(fn {a, b} -> same?(a, b) end)
      |> Enum.map(&elem(&1, 0))
    end)
  end

  # elements are the same node when name, parents and position agree
  defp same?(a, b), do: node_of(a) == node_of(b)

  defp id?(el), do: attrs(elem(el, 7))["id"] != nil

  # an element's provision id: its own, or a heading group's provision
  defp provision_id({:xmlElement, :P1group, _, _, _, _, _, _, _, _, _, _} = el),
    do:
      case(xpath(el, ~x"./*[@id][1]/@id"s),
        do: (
          "" -> nil
          id -> id
        )
      )

  defp provision_id(el), do: attrs(elem(el, 7))["id"]

  # each value the reader claimed for an attribute, as one string
  defp values(sets, attribute) do
    sets
    |> Enum.flat_map(fn {_, _, claims} ->
      for c <- claims, c.attribute == attribute, do: c.value
    end)
    |> Enum.uniq()
    |> case do
      [] -> "nil"
      vs -> vs |> Enum.map(&show/1) |> Enum.uniq() |> Enum.sort() |> Enum.join(" + ")
    end
  end

  defp show(v) when is_list(v), do: "list"
  defp show(v) when is_atom(v), do: Atom.to_string(v)
  defp show(v) when is_binary(v), do: if(v =~ ~r/^UK_/, do: "law", else: v)

  # ── examples ─────────────────────────────────────────────────────────

  @doc """
  The example for a change, as XML with effect ids scrubbed, and its key as
  the example names it; with the notes its elements cite. The smallest
  element holding all its elements and note refs, climbed to a provision
  with an id or its heading group; when that holds more than `whole` bytes,
  the same element pruned to the provisions the change touches and the
  elements above them. Nil when that holds more than `max` bytes (the
  fixtures are kept small). A pruned example
  can read differently (a provision's own text is cut): the caller checks.
  """
  @spec example(change(), tuple(), pos_integer(), pos_integer()) :: {String.t(), String.t()} | nil
  def example(change, doc, whole \\ 8_000, max \\ 15_000) do
    stacks = Enum.map(change.elements ++ change.refs, & &1.stack)

    container =
      stacks
      |> common()
      |> Enum.reverse()
      |> Enum.find(&(id?(&1) or elem(&1, 1) == :P1group))
      |> Kernel.||(hd(hd(stacks)))

    notes = Enum.uniq(for e <- change.elements, n = e.attrs["CommentaryRef"], n != nil, do: n)

    commentaries =
      for c <- xpath(doc, ~x"//Commentary"l), xpath(c, ~x"./@id"s) in notes, do: c

    all = export(container, commentaries)

    xml =
      if byte_size(all) <= whole,
        do: all,
        else:
          container
          |> prune(Enum.map(change.elements, & &1.stack), Enum.map(change.refs, & &1.stack))
          |> export(commentaries)

    if byte_size(xml) <= max, do: scrub(xml, change.key)
  end

  defp export(container, commentaries) do
    [{:Legislation, [], [container, {:Commentaries, [], commentaries}]}]
    |> :xmerl.export_simple(:xmerl_xml, prolog: [])
    |> :unicode.characters_to_binary()
  end

  # each provision a change element touches (the deepest element above it
  # with an id, or its heading group) kept whole, and each note ref (its
  # place is all it gives); the elements above them kept with only the
  # children that lead to one; the rest cut
  defp prune(container, element_stacks, ref_stacks) do
    kept =
      for(
        stack <- element_stacks,
        provision = stack |> Enum.reverse() |> Enum.find(&(id?(&1) or elem(&1, 1) == :P1group)),
        provision != nil,
        do: node_of(provision)
      ) ++ for(stack <- ref_stacks, do: node_of(List.last(stack)))

    kept = MapSet.new(kept)

    above =
      for stack <- element_stacks ++ ref_stacks,
          {el, i} <- Enum.with_index(stack),
          Enum.any?(Enum.drop(stack, i), &MapSet.member?(kept, node_of(&1))),
          into: MapSet.new(),
          do: node_of(el)

    cut(container, kept, above)
  end

  defp cut({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el, kept, above) do
    cond do
      MapSet.member?(kept, node_of(el)) ->
        el

      true ->
        children =
          for {:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = c <- children,
              MapSet.member?(above, node_of(c)),
              do: cut(c, kept, above)

        put_elem(el, 8, children)
    end
  end

  defp node_of(el), do: {elem(el, 1), elem(el, 5), elem(el, 6)}

  # every effect id out: the change's own key-E, the others key-E2, … in order
  defp scrub(xml, key) do
    own =
      if EffectIndex.effect_id(key),
        do: @effect_key |> Regex.run(key) |> List.wrap() |> List.first()

    others =
      @effect_key
      |> Regex.scan(xml)
      |> List.flatten()
      |> Enum.uniq()
      |> Enum.reject(&(&1 == own))
      |> Enum.with_index(2)
      |> Map.new(fn {k, i} -> {k, "key-E#{i}"} end)

    scrubbed =
      Regex.replace(@effect_key, xml, fn k -> if k == own, do: "key-E", else: others[k] end)

    {scrubbed, if(own, do: String.replace(key, own, "key-E"), else: key)}
  end

  @doc """
  What the reader made of an example, as JSON (`FeedPatterns.outcome/1`),
  sorted: one change's sets on one provision come in no set order.
  """
  @spec outcome([set()]) :: [map()]
  def outcome(sets), do: sets |> FeedPatterns.outcome() |> Enum.sort()

  @doc "An outcome with the change's effect id named `key-E`, as its example names it."
  @spec rekey([map()], String.t(), String.t()) :: [map()]
  def rekey(outcome, key, key), do: outcome

  def rekey(outcome, _real, named), do: Enum.map(outcome, &%{&1 | "key" => named})

  defp attrs(attrs) do
    Map.new(attrs, fn {:xmlAttribute, name, _, _, _, _, _, _, value, _} ->
      {Atom.to_string(name), to_string(value)}
    end)
  end
end
