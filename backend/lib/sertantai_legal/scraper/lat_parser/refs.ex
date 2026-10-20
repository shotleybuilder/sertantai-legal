defmodule SertantaiLegal.Scraper.LatParser.Refs do
  @moduledoc """
  Note references on LAT rows (LR-04):

  - the CommentaryRef id → type letter lookup (F/C/I/E) from the
    document's Commentaries
  - per row: note counts by type over its subtree, and the refs it cites at
    its own level (placement, LH-06): child rows' refs excluded, a wrapper
    P2's and quoted blocks' refs included
  - a group Title's refs (`placement/2`), placed on the provision it wraps

  Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.{Ids, Xml}

  @doc """
  Build a lookup from CommentaryRef ID → type letter (F/C/I/E) by parsing
  the <Commentaries> block in the same XML document. This handles hash-style
  IDs (c7375871, key-abc123) where the type can't be inferred from the ID.
  """
  @spec type_lookup(tuple()) :: %{String.t() => String.t()}
  def type_lookup(doc) do
    case xpath(doc, ~x"//Commentary"l) do
      nil ->
        %{}

      commentaries ->
        Map.new(commentaries, fn c ->
          id = Xml.attr(c, :id) |> to_string()
          type = Xml.attr(c, :Type) |> to_string() |> String.upcase()
          {id, type}
        end)
    end
  end

  @doc """
  Each change's note ref by its ChangeId (AR-10): the Addition /
  Substitution / Repeal's CommentaryRef attribute, else a CommentaryRef
  element just before it in the same parent (older markup: `<Pnumber>
  <CommentaryRef Ref="c13981151"/><Addition ChangeId="d29p11612">10`) —
  the change's other occurrences (its text) carry neither.
  """
  @spec change_refs(tuple()) :: %{String.t() => String.t()}
  def change_refs(doc), do: change_refs(doc, %{})

  defp change_refs(node, acc) when elem(node, 0) == :xmlElement do
    {acc, _} =
      Enum.reduce(elem(node, 8), {acc, nil}, fn child, {acc, before} ->
        case child do
          {:xmlElement, name, _, _, _, _, _, _, _, _, _, _} ->
            local = Xml.local_name(name)

            acc =
              with true <- local in ~w(Addition Substitution Repeal),
                   id when id != nil <- Xml.change_id(child),
                   ref when ref != nil <-
                     Xml.blank_to_nil(Xml.attr(child, :CommentaryRef)) || before do
                Map.put_new(acc, id, ref)
              else
                _ -> acc
              end

            before = if local == "CommentaryRef", do: Xml.attr_or_nil(child, :Ref), else: nil
            {change_refs(child, acc), before}

          _ ->
            {acc, before}
        end
      end)

    acc
  end

  defp change_refs(_node, acc), do: acc

  @doc """
  Classify each CommentaryRef by looking up its type in the Commentaries block.
  Falls back to ID prefix matching (F1→amendment) for backwards compatibility.
  """
  @spec collect(tuple(), %{String.t() => String.t()}) ::
          {%{
             f: pos_integer() | nil,
             c: pos_integer() | nil,
             i: pos_integer() | nil,
             e: pos_integer() | nil
           }, [String.t()]}
  def collect(node, ref_type_lookup) do
    refs =
      for r <- Xml.descendants_xmerl(node, :CommentaryRef),
          v = Xml.attr_or_nil(r, :Ref),
          v != nil,
          do: v

    counts =
      refs
      |> Enum.map(fn ref_id -> classify_ref(ref_id, ref_type_lookup) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.frequencies()

    typed_counts = %{
      f: Map.get(counts, "F") |> nil_if_zero(),
      c: Map.get(counts, "C") |> nil_if_zero(),
      i: Map.get(counts, "I") |> nil_if_zero(),
      e: Map.get(counts, "E") |> nil_if_zero()
    }

    # Placement (affected_sections): the notes the row cites at its own level
    # (CommentaryRef elements and CommentaryRef attributes on
    # Addition/Substitution/Repeal), its child provisions' refs excluded —
    # they are rows of their own (LH-06). Counts stay subtree, element-only.
    {typed_counts, own_refs(node)}
  end

  # Refs in the element's own content: not inside a child row element,
  # except a P2 that only wraps its P1 (no row of its own) and anything
  # inside a quoted block (another law's provisions, never rows here).
  defp own_refs(node) do
    wrapper = elem(node, 1) == :P1 and Ids.p2_wrapper?(node, Ids.pnumber(node))
    node |> refs_within(wrapper, false) |> Enum.uniq()
  end

  defp refs_within(element, wrapper, quoted) do
    attribute = Xml.blank_to_nil(Xml.attr(element, :CommentaryRef))

    from_children =
      element
      |> elem(8)
      |> Enum.flat_map(fn child ->
        if elem(child, 0) == :xmlElement, do: child_refs(child, wrapper, quoted), else: []
      end)

    List.wrap(attribute) ++ from_children
  end

  defp child_refs(child, wrapper, quoted) do
    name = to_string(elem(child, 1))

    cond do
      name == "CommentaryRef" ->
        List.wrap(Xml.blank_to_nil(Xml.attr(child, :Ref)))

      name in Xml.quoted_elements() ->
        refs_within(child, wrapper, true)

      quoted ->
        refs_within(child, wrapper, true)

      name == "P2" and wrapper ->
        refs_within(child, false, false)

      name in Xml.row_elements() ->
        []

      # a group's Title notes go to the provision it wraps (group_refs),
      # never to the heading or Part above it (QA run 3)
      name in ~w(P1group P2group P3group) ->
        []

      true ->
        refs_within(child, wrapper, quoted)
    end
  end

  @doc """
  CommentaryRef elements' Ref and CommentaryRef attributes under `path`.
  """
  @spec placement(tuple(), String.t()) :: [String.t()]
  def placement(node, path) do
    under = under(node, path)

    elements =
      for n <- under,
          r <- Xml.descendants(n, :CommentaryRef),
          v = Xml.attr_or_nil(r, :Ref),
          v != nil,
          do: v

    attributes =
      for n <- under,
          el <- [n | Xml.descendants(n)],
          v = Xml.attr_or_nil(el, :CommentaryRef),
          v != nil,
          do: v

    (elements ++ attributes) |> Enum.uniq()
  end

  # the elements a `./Name` path selects (the one form callers use)
  defp under(node, "./" <> name), do: Xml.children(node, String.to_existing_atom(name))

  # Classify a ref ID: first try the lookup (handles hash-style IDs),
  # then fall back to prefix matching (F1, C2, I3, E4).
  defp classify_ref(ref_id, lookup) do
    case Map.get(lookup, ref_id) do
      type when type in ["F", "C", "I", "E"] -> type
      _ -> classify_ref_by_prefix(ref_id)
    end
  end

  defp classify_ref_by_prefix(ref_id) do
    cond do
      String.match?(ref_id, ~r/^F\d/) -> "F"
      String.match?(ref_id, ~r/^C\d/) -> "C"
      String.match?(ref_id, ~r/^I\d/) -> "I"
      String.match?(ref_id, ~r/^E\d/) -> "E"
      true -> nil
    end
  end

  defp nil_if_zero(0), do: nil
  defp nil_if_zero(n), do: n
end
