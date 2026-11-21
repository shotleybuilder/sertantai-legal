defmodule SertantaiLegal.Scraper.Commencement.OrderMisreads do
  @moduledoc """
  A commencement order's misreads: each statement (`OrderLeftovers.order_units/2`)
  with what its rules misread (`Misreads.of/3`), and its list items' other
  law (`order_items/2`). For the order catalogue (`mix lat.order_patterns`);
  apart from the own clause's (`Misreads`), so the commencement catalogue
  reaches no order reading. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.{
    Misreads,
    OrderLeftovers,
    OrderPatterns,
    Rule,
    TextRefs
  }

  # ── a commencement order ────────────────────────────────────────────

  @doc """
  Each statement of a commencement order (`OrderLeftovers.order_units/2`) with
  its `misreads`, given the order's `rules` and `ctx`: the Act it commences
  (`own`) and the bare ids of the Act's rows (`ids`, nil where none held).
  """
  @spec order_units(Doc.t(), [Rule.t()], map()) :: [map()]
  def order_units(doc, rules, ctx) do
    ctx = Map.put(ctx, :refs, &TextRefs.refs_in/1)

    for %{unit: unit} = statement <- OrderLeftovers.order_units(doc, rules) do
      Map.put(statement, :misreads, order_misreads(unit, rules, ctx))
    end
  end

  defp order_misreads(%{kind: kind}, _rules, _ctx) when kind in ["own", "table_header"], do: []

  defp order_misreads(unit, rules, ctx) do
    text = if unit.kind == "table", do: unit.text |> String.split(" | ") |> hd(), else: unit.text
    own = OrderPatterns.own_rules(unit, rules)
    Enum.uniq(Misreads.of(%{head: text, items: []}, own, ctx) ++ order_items(own, ctx))
  end

  @doc """
  Another law's provisions in the rules of an order's list items: each
  item (a rule's source words after its head, "head … item") read with the
  rules it gave.
  """
  @spec order_items([Rule.t()], Misreads.ctx()) :: [Misreads.misread()]
  def order_items(rules, ctx) do
    rules
    |> Enum.group_by(&item/1)
    |> Enum.sort()
    |> Enum.flat_map(fn
      {nil, _} -> []
      {item, of_item} -> Misreads.other_law(item, of_item, ctx)
    end)
  end

  defp item(%Rule{source: %{text: text}}) when is_binary(text) do
    case String.split(text, " … ", parts: 2) do
      [_head, item] -> item
      _ -> nil
    end
  end

  defp item(_rule), do: nil
end
