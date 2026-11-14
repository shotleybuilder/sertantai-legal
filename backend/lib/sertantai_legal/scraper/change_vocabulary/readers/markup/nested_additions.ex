defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.NestedAdditions do
  @moduledoc """
  The changes that only wrap a later insertion in a provision's number.
  legislation.gov.uk nests a later Addition inside the earlier changes
  around it: HSWA s.11(4AA), inserted by 2015 c.20, sits inside the
  Addition of 2013 c.32 that inserted s.11(4A) (and inside SI 2008/960's
  substitution of ss.11-13). The innermost change in the number inserted
  the provision; a change wrapped round it, with no words of its own in the
  provision, is not a change to that provision or to anything under it.
  Only where the order is sure:

  - the outer change's note cites a law of an earlier year than the inner
    change's (the Local Employment Act 1960 s.32(1)(h)(iii): a 1982 repeal
    marked round a 1973 change; an unknown year is never earlier);
  - the outer change has no words of its own in the provision (the
    Marriage Act 1949 s.5(2): the 1986 Act added it; a 2015 words
    substitution is marked round its number).

  A legacy inner change counts too, as the reader reads a legacy Addition
  round a number as an insertion (TCPA 1990 s.78(4BA): the 2015 Welsh Act's
  `M_F_…` inside 2008 c.29's). Where that legacy Addition was no insertion
  (about 4% of the store: the Countryside (Scotland) Act 1967 s.48A, a
  2000 "ceases to have effect" inside the 1981 insertion), the row loses
  the earlier insertion's claim, its start unchanged: a known limit (Jason
  2026-11-14, Fire and OH&S: Markup reader, Decision 2 a).

  (Fire and OH&S: Markup reader.) Changes are told apart by their effect id
  (`key-<hex>`), else by ChangeId. Pure: the years come from the caller.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @doc """
  `{change_id, row_id}` for each change that wraps another's insertion in
  that row's number; `year_of` gives a note's cited law's year (nil when
  unknown).
  """
  @spec wrappers(tuple(), (String.t() | nil -> integer() | nil)) ::
          MapSet.t({String.t(), String.t()})
  def wrappers(doc, year_of), do: doc |> walk(year_of, []) |> MapSet.new()

  defp walk({:xmlElement, _, _, _, _, _, _, attrs, children, _, _, _} = el, year_of, acc) do
    acc =
      case {attr(attrs, :id), Enum.find(children, &pnumber?/1)} do
        {id, {:xmlElement, _, _, _, _, _, _, _, number, _, _, _}} when id != nil ->
          number |> chain([]) |> outer(id, el, year_of) |> Kernel.++(acc)

        _ ->
          acc
      end

    Enum.reduce(children, acc, &walk(&1, year_of, &2))
  end

  defp walk(_other, _year_of, acc), do: acc

  defp pnumber?({:xmlElement, :Pnumber, _, _, _, _, _, _, _, _, _, _}), do: true
  defp pnumber?(_node), do: false

  # the Additions nested one inside the next from the number down, as
  # `{ChangeId, note}`, outermost first
  defp chain(children, ids) do
    case Enum.find(children, &addition?/1) do
      {:xmlElement, _, _, _, _, _, _, attrs, inner, _, _, _} ->
        chain(inner, [{attr(attrs, :ChangeId), attr(attrs, :CommentaryRef)} | ids])

      nil ->
        Enum.reverse(ids)
    end
  end

  defp addition?({:xmlElement, :Addition, _, _, _, _, _, attrs, _, _, _, _}),
    do: attr(attrs, :ChangeId) != nil

  defp addition?(_node), do: false

  # every ChangeId wrapped round the inner change, citing an earlier law
  # and with no words in the row beyond the inner's
  defp outer([_, _ | _] = chain, row_id, row, year_of) do
    {inner_id, inner_note} = List.last(chain)
    inner = change(inner_id)
    inner_year = year_of.(inner_note)

    if inner_year do
      inner_words = words(row, inner)

      for {id, note} <- chain,
          change(id) != inner,
          earlier?(year_of.(note), inner_year),
          words(row, change(id)) == inner_words,
          do: {id, row_id}
    else
      []
    end
  end

  defp outer(_chain, _row_id, _row, _year_of), do: []

  defp earlier?(nil, _inner_year), do: false
  defp earlier?(year, inner_year), do: year < inner_year

  # the letters of a change's outermost Additions under the row
  defp words(row, change), do: row |> collect(change, []) |> Enum.reverse() |> Enum.join()

  defp collect({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el, change, acc) do
    if name == :Addition and attr(attrs, :ChangeId) != nil and
         change(attr(attrs, :ChangeId)) == change,
       do: [letters(el) | acc],
       else: Enum.reduce(children, acc, &collect(&1, change, &2))
  end

  defp collect(_other, _change, acc), do: acc

  defp letters(el), do: el |> Doc.text() |> String.replace(~r/[^\p{L}\p{N}]/u, "")

  defp change(change_id) do
    case Regex.run(~r/^key-[0-9a-f]{32}/, change_id) do
      [key] -> key
      nil -> change_id
    end
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end
