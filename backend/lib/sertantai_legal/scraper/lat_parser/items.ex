defmodule SertantaiLegal.Scraper.LatParser.Items do
  @moduledoc """
  Numbered list items that are rows of their own (CV-S02a, #184). Pure.

  legislation.gov.uk often writes a provision's points or numbered
  definitions as `ListItem`s with no id, yet addresses them as provisions
  (the feed's `article-57-a`, `article-2-15`). Such an item is a row when:

  - it is numbered (a NumberOverride, or an OrderedList with a Type);
  - it sits directly under a provision: every list item between it and the
    provision is a numbered item row too (items inside a definition — an
    unnumbered item — stay that definition's text);
  - a level is free for it below the provision (P1 has three: sub,
    paragraph, sub_paragraph; P4 none).

  The search stops at rows of their own (provisions, tables, figures) and
  at other laws' text (amendment blocks).
  """

  alias SertantaiLegal.Scraper.LatParser.{Ids, Xml}

  @typedoc "An xmerl element's place in its document: ancestors and position"
  @type key :: {list(), pos_integer()}

  @type item :: %{number: String.t()}

  @doc "The key of an element (its xmerl ancestors and position): unique in its document."
  @spec key(tuple()) :: key()
  def key(node), do: {elem(node, 5), elem(node, 6)}

  @doc """
  A provision node's item rows, by key, with each item's number, taking at
  most `levels` levels.
  """
  @spec rows(tuple(), non_neg_integer()) :: %{key() => item()}
  def rows(node, levels), do: node |> Xml.children() |> search(levels, %{})

  defp search(_children, 0, acc), do: acc

  defp search(children, levels, acc) do
    Enum.reduce(children, acc, fn child, acc ->
      name = Xml.element_name(child)

      cond do
        name in Xml.row_elements() or name in Xml.skip_elements() or
            name in Xml.quoted_elements() ->
          acc

        name in ~w(OrderedList UnorderedList) ->
          list_items(child, levels, acc)

        true ->
          child |> Xml.children() |> search(levels, acc)
      end
    end)
  end

  defp list_items(list, levels, acc) do
    list
    |> Xml.children()
    |> Enum.filter(&(Xml.element_name(&1) == "ListItem"))
    |> Enum.with_index(1)
    |> Enum.reduce(acc, fn {item, i}, acc ->
      case number(item, list, i) do
        nil ->
          acc

        number ->
          acc = Map.put(acc, key(item), %{number: number})
          item |> Xml.children() |> search(levels - 1, acc)
      end
    end)
  end

  @doc """
  A list item's number: its NumberOverride ("15." → 15), else counted from
  an OrderedList's Type (the second item of an alpha list → b); nil when
  the source doesn't number it.
  """
  @spec number(tuple(), tuple(), pos_integer()) :: String.t() | nil
  def number(item, list, i) do
    case Xml.attr(item, :NumberOverride) do
      "" ->
        type = Xml.attr(list, :Type)

        if Xml.element_name(list) == "OrderedList" and type not in ["", "none"],
          do: list_number(i, type)

      override ->
        case override |> Ids.clean() |> String.trim_trailing(".") |> unbracket() do
          "" -> nil
          n -> n
        end
    end
  end

  @doc "The i-th number of an OrderedList of a Type (alpha, roman, arabic…)."
  @spec list_number(pos_integer(), String.t()) :: String.t()
  def list_number(i, "alpha"), do: alpha(i)
  def list_number(i, "alphaUpper"), do: String.upcase(alpha(i))
  def list_number(i, "roman"), do: roman(i)
  def list_number(i, "romanUpper"), do: String.upcase(roman(i))
  def list_number(i, _arabic), do: Integer.to_string(i)

  defp alpha(i) when i <= 26, do: <<?a + i - 1>>
  defp alpha(i), do: alpha(div(i - 1, 26)) <> alpha(rem(i - 1, 26) + 1)

  @romans [{10, "x"}, {9, "ix"}, {5, "v"}, {4, "iv"}, {1, "i"}]
  defp roman(0), do: ""

  defp roman(i),
    do: @romans |> Enum.find(fn {v, _} -> v <= i end) |> then(fn {v, r} -> r <> roman(i - v) end)

  defp unbracket(n), do: n |> String.replace(~r/\A[(\[]|[)\]]\z/u, "") |> String.trim()
end
