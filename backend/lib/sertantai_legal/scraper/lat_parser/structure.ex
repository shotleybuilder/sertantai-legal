defmodule SertantaiLegal.Scraper.LatParser.Structure do
  @moduledoc """
  legislation.gov.uk structure faults in CLML (CV-S02a, #183). Pure.

  Two patterns are sensed (`faults/1`):

  - **an id that contradicts its nesting**: a P1–P4's id doesn't extend
    its nearest provision ancestor's id, ignoring version marks (`n1`)
    — CLP's `article-50-2-a` inside Art. 52(1). Sensed only: rows are
    named from the nesting and printed numbers, never from ids.
  - **a level skipped**: a P3 directly under a P1 that has P2s, or a P4
    directly under a P2 that has P3s.

  One repair (`adoptions/1`): a loose element whose number continues the
  last item of the sibling just before it belongs in that sibling — HSWA
  s.28: (3) closes after (e) and the next element is a loose (f), so it is
  s.28(3)(f). A loose element that continues nothing stays where it is
  (HSWA s.50(a)–(c) after (1AA), which has no paragraphs).

  Other laws' text (amendment blocks) and schedules are not searched.
  """

  alias SertantaiLegal.Scraper.LatParser.{Ids, Items, Xml}

  @type fault :: %{
          kind: :id_contradicts_nesting | :level_skipped,
          xml_id: String.t() | nil,
          parent_id: String.t() | nil,
          adopted: boolean()
        }

  @provisions ~w(P1 P2 P3 P4)
  # a provision's own level below, and the level that skips it
  @levels %{"P1" => {"P2", "P3", :sub}, "P2" => {"P3", "P4", :paragraph}}

  @doc "The structure faults of a document, in document order."
  @spec faults(tuple()) :: [fault()]
  def faults(doc), do: doc |> scan(nil) |> List.flatten()

  defp scan(node, parent) do
    for child <- Xml.children(node), not skipped?(child) do
      if Xml.element_name(child) in @provisions do
        [id_fault(child, parent), skipped_faults(child), scan(child, child)]
      else
        scan(child, parent)
      end
    end
  end

  defp skipped?(node) do
    name = Xml.element_name(node)

    name in Xml.skip_elements() or name in Xml.quoted_elements() or
      name in Xml.schedule_elements()
  end

  defp id_fault(_node, nil), do: []

  defp id_fault(node, parent) do
    with id when is_binary(id) <- Xml.xml_id(node),
         parent_id when is_binary(parent_id) <- Xml.xml_id(parent),
         false <- String.starts_with?(unversioned(id), unversioned(parent_id) <> "-") do
      [%{kind: :id_contradicts_nesting, xml_id: id, parent_id: parent_id, adopted: false}]
    else
      _ -> []
    end
  end

  # legislation.gov.uk's version marks: section-28n1-3, section-70A-1n1
  defp unversioned(id), do: String.replace(id, ~r/n\d+(?=-|$)/, "")

  defp skipped_faults(node) do
    adopted = adoptions(node)

    for loose <- loose(node) do
      %{
        kind: :level_skipped,
        xml_id: Xml.xml_id(loose),
        parent_id: Xml.xml_id(node),
        adopted: Map.has_key?(adopted, Items.key(loose))
      }
    end
  end

  @doc """
  The loose elements of a P1 or P2 that continue the sibling before them,
  by key (`Items.key/1`), with the level and number they take:
  `{:sub, "3"}` (s.28(f) → s.28(3)(f)), `{:paragraph, "a"}`.
  """
  @spec adoptions(tuple()) :: %{Items.key() => {:sub | :paragraph, String.t()}}
  def adoptions(node) do
    case Map.fetch(@levels, Xml.element_name(node)) do
      {:ok, {mid, low, field}} -> adopt(own(node), mid, low, field)
      :error -> %{}
    end
  end

  defp adopt(own, mid, low, field) do
    {adopted, _last} =
      Enum.reduce(own, {%{}, nil}, fn el, {acc, last} ->
        case {Xml.element_name(el), last} do
          {^mid, _} ->
            items = el |> own() |> Enum.filter(&(Xml.element_name(&1) == low))
            {acc, {Ids.pnumber(el), items |> List.last() |> pnumber()}}

          {^low, {mid_number, prev}} ->
            number = Ids.pnumber(el)

            if continues?(prev, number),
              do: {Map.put(acc, Items.key(el), {field, mid_number}), {mid_number, number}},
              else: {acc, last}

          _ ->
            {acc, last}
        end
      end)

    adopted
  end

  # a P1's loose P3s (a P2's loose P4s) beside its own P2s (P3s)
  defp loose(node) do
    case Map.fetch(@levels, Xml.element_name(node)) do
      {:ok, {mid, low, _field}} ->
        own = own(node)

        if Enum.any?(own, &(Xml.element_name(&1) == mid)),
          do: Enum.filter(own, &(Xml.element_name(&1) == low)),
          else: []

      :error ->
        []
    end
  end

  # the provisions directly under a node, in document order
  defp own(node) do
    Enum.flat_map(Xml.children(node), fn child ->
      cond do
        skipped?(child) -> []
        Xml.element_name(child) in @provisions -> [child]
        true -> own(child)
      end
    end)
  end

  defp pnumber(nil), do: nil
  defp pnumber(node), do: Ids.pnumber(node)

  @sequences ~w(alpha roman arabic)

  # n is the item after prev in a lettered, Roman or numbered sequence
  defp continues?(prev, n) when is_binary(prev) and is_binary(n) do
    {prev, n} = {String.downcase(prev), String.downcase(n)}

    Enum.any?(@sequences, fn type ->
      seq = Enum.map(1..60, &Items.list_number(&1, type))

      case Enum.find_index(seq, &(&1 == prev)) do
        nil -> false
        i -> Enum.at(seq, i + 1) == n
      end
    end)
  end

  defp continues?(_prev, _n), do: false
end
