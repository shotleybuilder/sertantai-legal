defmodule SertantaiLegal.Scraper.AmendingLaw.Doc.ListItems do
  @moduledoc """
  An amending provision's list items that legislation.gov.uk gives no id,
  each an instruction of its own: numbered from the list's `Start` (or the
  item's `NumberOverride`) under the nearest provision with an id, so each
  is read on its own ("(c) in the definition of “the IBC Code” for “1998”
  substitute “2007”;" → `schedule-1-paragraph-2-c`: SI 2011/2616 Sch.1
  para.2, nested in the list quoting (b)'s words; parked bug
  `unnumbered-list-items-collapsed`, fixed in Amending-law reader: parked
  bugs, 2026-11-10). A list of places or words, not instructions, is left
  as its provision's words. Never inside quoted text. Pure.
  """

  require Record

  Record.defrecordp(
    :el,
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :attr,
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  @quotes ~w(BlockAmendment InlineAmendment)a
  # every item an instruction: its own verb, quoted words aside
  @verb ~r/\b(?:insert|substitute|omit|add|delete|repeal|revoke)(?:ed)?\b/iu

  @doc "The document with an id on each id-less list item that is an instruction."
  @spec number(tuple()) :: tuple()
  def number(root), do: walk(root, nil)

  defp walk(el(name: name) = e, _id) when name in @quotes, do: e

  defp walk(el(name: :OrderedList, content: content) = e, id) when is_binary(id) do
    items = for c <- content, Record.is_record(c, :xmlElement), el(c, :name) == :ListItem, do: c

    if instructions?(items),
      do: el(e, content: numbered(content, label_from(e), id)),
      else: el(e, content: Enum.map(content, &walk(&1, id)))
  end

  defp walk(el(content: content) = e, id) do
    own = attr_value(e, :id) || id
    el(e, content: Enum.map(content, &walk(&1, own)))
  end

  defp walk(node, _id), do: node

  defp instructions?([_ | _] = items),
    do: Enum.all?(items, &(attr_value(&1, :id) == nil and own_words(&1) =~ @verb))

  defp instructions?([]), do: false

  defp numbered(content, label, id) do
    {out, _} =
      Enum.map_reduce(content, 0, fn
        c, n when Record.is_record(c, :xmlElement) ->
          if el(c, :name) == :ListItem do
            l = attr_value(c, :NumberOverride) || label.(n)
            {el(c, attributes: [new_attr(:id, "#{id}-#{l}") | el(c, :attributes)]), n + 1}
          else
            {c, n}
          end

        c, n ->
          {c, n}
      end)

    out
  end

  # the list's numbering: its Type and Start ("alpha", Start 3 → c, d, e)
  defp label_from(list) do
    start = list |> attr_value(:Start) |> parse_int()

    case attr_value(list, :Type) do
      "arabic" -> &Integer.to_string(start + &1)
      "roman" -> &roman(start + &1)
      _ -> &<<?a + start - 1 + &1>>
    end
  end

  defp parse_int(nil), do: 1
  defp parse_int(s), do: String.to_integer(s)

  @romans [{10, "x"}, {9, "ix"}, {5, "v"}, {4, "iv"}, {1, "i"}]
  defp roman(0), do: ""

  defp roman(n) do
    {v, r} = Enum.find(@romans, fn {v, _} -> v <= n end)
    r <> roman(n - v)
  end

  # an item's words, quotes and quoted words aside
  defp own_words(item) do
    item
    |> text()
    |> String.replace(~r/[“"][^”"]*[”"]/u, "")
  end

  defp text(el(name: name)) when name in @quotes, do: ""
  defp text(el(content: content)), do: Enum.map_join(content, " ", &text/1)
  defp text({:xmlText, _, _, _, value, _}), do: to_string(value)
  defp text(_node), do: ""

  defp attr_value(el(attributes: attrs), name) do
    case List.keyfind(attrs, name, attr(:name)) do
      nil -> nil
      a -> a |> attr(:value) |> to_string()
    end
  end

  defp attr_value(_node, _name), do: nil

  defp new_attr(name, value), do: attr(name: name, value: String.to_charlist(value))
end
