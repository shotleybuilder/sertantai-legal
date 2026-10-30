defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.KeptChildren do
  @moduledoc """
  Each provision's children that keep the number they were made with: no
  change markup in their own number (CV-S09 round 5). A change wrapping a
  provision's number replaced it whole only if it reaches every such child
  — NISR 2004/241 reg.3: SR 2007/291's Substitution wraps "3" and all of
  reg.3(1), but reg.3(2) keeps its number and text, so the feed's "reg.
  3(1)" was the change ("The reg. 3 has been included in the
  substitution"). A child inserted later carries its own insertion in its
  number, so it never counts against a whole substitution made before it.
  Pure.
  """

  @changes [:Addition, :Substitution, :Repeal]

  @doc "`%{xml_id => [child xml_id]}`: each element's nearest id-bearing children whose number carries no change."
  @spec read(tuple()) :: %{String.t() => [String.t()]}
  def read(doc) do
    doc
    |> walk(nil, [])
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp walk({:xmlElement, _name, _, _, _, _, _, attrs, children, _, _, _}, parent, acc) do
    id = attr(attrs, :id)

    acc =
      if id && parent && numbered?(children) && not changed_number?(children),
        do: [{parent, id} | acc],
        else: acc

    # a group (Part, Chapter) wraps only its Number and Title when it is
    # changed whole (SI 2009/1348 Pt.4A; asp 2005/5 Ch.8C): provisions only
    holder = if id && numbered?(children), do: id, else: if(id, do: nil, else: parent)
    Enum.reduce(children, acc, &walk(&1, holder, &2))
  end

  defp walk({:xmlDocument, children}, parent, acc),
    do: Enum.reduce(children, acc, &walk(&1, parent, &2))

  defp walk(_node, _parent, acc), do: acc

  defp numbered?(children), do: Enum.any?(children, &pnumber?/1)

  defp changed_number?(children),
    do: children |> Enum.filter(&pnumber?/1) |> Enum.any?(&change_inside?/1)

  defp pnumber?({:xmlElement, :Pnumber, _, _, _, _, _, _, _, _, _, _}), do: true
  defp pnumber?(_node), do: false

  defp change_inside?({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _}),
    do:
      (name in @changes and attr(attrs, :ChangeId) != nil) or
        Enum.any?(children, &change_inside?/1)

  defp change_inside?(_node), do: false

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end
