defmodule SertantaiLegal.Scraper.LatParser.Inline do
  @moduledoc """
  Inline CLML → segments (`LatSegments`) for the LAT parser (LR-04).

  - an element's inline text in document order, markup joined without
    extra spaces ("<Term>X</Term>" → "X")
  - change markup → `%LatTerritory.Change{}`: a retained Repeal (:keep), an
    Addition / Substitution (:ins), a territorial substitution (:pair, or
    halves marked for `LatTerritory.pair_up/1`)
  - a change wrapping whole blocks (`block_change/1`, `changed_block/2`)

  Territory is decided later, per row (`LatTerritory`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.Xml
  alias SertantaiLegal.Scraper.{LatSegments, LatTerritory}

  @doc """
  An element's inline text as segments, in document order. Substitution
  halves anywhere in it are paired (`LatTerritory.pair_up/1`).
  """
  @spec text(tuple()) :: LatSegments.t()
  def text(element) do
    subrefs =
      element |> xpath(~x".//@SubstitutionRef"ls) |> Enum.map(&to_string/1) |> MapSet.new()

    element
    |> render_inline(subrefs)
    |> LatTerritory.pair_up()
    |> LatSegments.trim()
  end

  @doc "An element's inline words as a plain string (numbers, signatures)."
  @spec plain(tuple()) :: String.t()
  def plain(element),
    do:
      element
      |> text()
      |> LatSegments.plain()
      |> String.replace(~r/\s+/, " ")
      |> String.trim()

  @doc "A change element around whole blocks: a retained Repeal or an insertion (else nil)."
  @spec block_change(tuple()) :: LatTerritory.Change.t() | nil
  def block_change(el) do
    cond do
      elem(el, 1) == :Repeal and xpath(el, ~x"./@RetainText"s) == "true" -> change(el, :keep)
      elem(el, 1) in [:Addition, :Substitution] -> change(el, :ins)
      true -> nil
    end
  end

  @doc "A text block (segments, or an AppendText block) wrapped in a block change."
  @spec changed_block(term(), LatTerritory.Change.t()) :: term()
  def changed_block(segments, change) when is_list(segments), do: [{:words, change, segments}]
  def changed_block({:append, segments}, change), do: {:append, [{:words, change, segments}]}
  def changed_block(block, _change), do: block

  # Inline segments. Changes become {:words, change, inner}: a retained
  # Repeal (:keep) or an Addition/Substitution (:ins); their territory is
  # decided per row (LatTerritory). A territorial substitution — <Repeal
  # RetainText SubstitutionRef="X">old</Repeal> … <Substitution
  # ChangeId="X">new</Substitution> — is a {:pair, …}: siblings here, else
  # its halves are marked for LatTerritory.pair_up/1 (`subrefs`: the
  # block's SubstitutionRefs).
  defp render_inline(element, subrefs) do
    siblings = elem(element, 8)
    content = Enum.with_index(siblings)

    partners =
      for {el, i} <- content,
          elem(el, 0) == :xmlElement,
          id = Xml.change_id(el),
          into: %{},
          do: {id, {el, i}}

    {parts, _skip_to} =
      Enum.map_reduce(content, -1, fn {child, i}, skip_to ->
        cond do
          i <= skip_to ->
            {[], skip_to}

          elem(child, 0) == :xmlElement ->
            render_child(child, i, siblings, partners, skip_to, subrefs)

          true ->
            {render_node(child, subrefs), skip_to}
        end
      end)

    Enum.concat(parts)
  end

  # A sibling pair renders where its first retained Repeal sits and takes
  # everything up to its partner as the old wording: it can be split across
  # Repeals sharing the SubstitutionRef and wrap or sit inside other markup
  # (a Term).
  defp render_child(child, i, siblings, partners, skip_to, subrefs) do
    ref = substitution_ref(child)

    case ref && Map.get(partners, ref) do
      {partner, j} when j > i ->
        old = siblings |> Enum.slice(i..(j - 1)//1) |> Enum.flat_map(&render_node(&1, subrefs))
        {[{:pair, pair_change(child, partner), render_inline(partner, subrefs), old}], j}

      _ ->
        inner = render_inline(child, subrefs)

        cond do
          ref != nil ->
            {[{:pair_old, ref, change(child, :keep), inner}], skip_to}

          MapSet.member?(subrefs, Xml.change_id(child)) ->
            {[{:pair_new, Xml.change_id(child), change(child, :ins), inner}], skip_to}

          retained_words?(child) ->
            {[{:words, change(child, :keep), inner}], skip_to}

          elem(child, 1) in [:Addition, :Substitution] ->
            {[{:words, change(child, :ins), inner}], skip_to}

          elem(child, 1) == :InlineAmendment ->
            {tidy_quotes(inner), skip_to}

          true ->
            {inner, skip_to}
        end
    end
  end

  # An InlineAmendment's quote marks hold its words, not the source's line
  # breaks ("“⏎ general ⏎”" → "“general”"; anaw 2016/3 s.5(3)(a); LR-05)
  # (a quote it opens and the text after it closes: its trailing break too;
  # 2012/3119 reg.20(b))
  defp tidy_quotes(segments) do
    segments = merge_texts(segments)
    plain = segments |> LatSegments.plain() |> String.trim()
    open_only = String.match?(plain, ~r/\A[“‘]/u) and not String.match?(plain, ~r/[”’]\z/u)

    segments
    |> LatSegments.update_first_text(&String.replace(&1, ~r/\A(\s*[“‘"])\s+/u, "\\1"))
    |> LatSegments.update_last_text(&String.replace(&1, ~r/\s+([”’"]\s*)\z/u, "\\1"))
    |> then(
      &if(open_only,
        do: LatSegments.update_last_text(&1, fn s -> String.trim_trailing(s) end),
        else: &1
      )
    )
  end

  # adjacent plain texts as one (split by markup that renders nothing, a
  # CommentaryRef), so a quote's edge is one text
  defp merge_texts([{:text, a}, {:text, b} | rest]), do: merge_texts([{:text, a <> b} | rest])
  defp merge_texts([seg | rest]), do: [seg | merge_texts(rest)]
  defp merge_texts([]), do: []

  # Words repealed (text kept) with no replacement.
  defp retained_words?(el) do
    elem(el, 1) == :Repeal and xpath(el, ~x"./@RetainText"s) == "true" and
      substitution_ref(el) == nil
  end

  defp change(el, kind) do
    %LatTerritory.Change{
      kind: kind,
      attribute: Xml.blank_to_nil(xpath(el, ~x"./@Extent"s)),
      ref: Xml.blank_to_nil(xpath(el, ~x"./@CommentaryRef"s)),
      change_id: Xml.change_id(el),
      substitution: elem(el, 1) == :Substitution
    }
  end

  # A pair's territory: the first Extent of its halves, and the old half's note.
  defp pair_change(repeal, partner) do
    attribute =
      [repeal, partner]
      |> Enum.map(&Xml.blank_to_nil(xpath(&1, ~x"./@Extent"s)))
      |> Enum.find(& &1)

    %LatTerritory.Change{
      kind: :pair,
      attribute: attribute,
      ref: Xml.blank_to_nil(xpath(repeal, ~x"./@CommentaryRef"s)),
      change_id: Xml.change_id(repeal)
    }
  end

  defp render_node(node, subrefs) do
    case elem(node, 0) do
      :xmlText ->
        node |> elem(4) |> to_string() |> LatSegments.strip_invisible() |> LatSegments.text()

      # an element's content (a pair's old half renders as plain words)
      :xmlElement ->
        render_inline(node, subrefs)

      _ ->
        []
    end
  end

  defp substitution_ref(element) do
    if elem(element, 1) == :Repeal and xpath(element, ~x"./@RetainText"s) == "true",
      do: Xml.blank_to_nil(xpath(element, ~x"./@SubstitutionRef"s))
  end
end
