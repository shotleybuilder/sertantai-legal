defmodule SertantaiLegal.Scraper.LawStart.ThatDay do
  @moduledoc """
  A list item counting from "that day": the day the item before it names —
  "(a) sections 150 … which come into force on the day on which this Act
  is passed; (b) sections 151 and 177, which come into force at the end of
  the period of 2 months beginning with that day" (2014 c.12 s.185(2)).
  `resolve/2` gives the item's row with the day written out, so the clause
  reader counts from it. A list's head does the same, and the day may be
  an item or more back, each between saying "on that day": "(1) … comes
  into force … on the day on which this Act is passed. (2) The following
  provisions of this Act come into force on that day— (3) The following
  provisions of this Act come into force at the end of the period of 2
  months beginning with that day—" (2011 c.19 s.38). Only a day of passing
  or making is carried: any other day stays as written. Pure.
  """

  @that ~r/\b(beginning\s+with|after|following|from|on)\s+that\s+(?:day|date)\b/i
  @day ~r/\bon\s+(the\s+(?:day|date)\s+(?:on\s+which\s+)?(?:this\s+Act|it|they|these\s+Regulations|this\s+Order)\s+(?:is|are)\s+(?:passed|made)|the\s+(?:day|date)\s+of\s+Royal\s+Assent|the\s+(?:day|date)\s+on\s+which\s+(?:this\s+Act|it)\s+receives\s+Royal\s+Assent)/i

  @doc "`row` with \"that day\" written out as the day the item before it (in `rows`) names."
  @spec resolve(map(), [map()]) :: map()
  def resolve(%{text: text} = row, rows) when is_binary(text) do
    with true <- Regex.match?(@that, text),
         day when is_binary(day) <- named_day(row, rows) do
      %{row | text: Regex.replace(@that, text, "\\1 #{day}")}
    else
      _ -> row
    end
  end

  def resolve(row, _rows), do: row

  # the day the nearest item before names; an item itself on "that day"
  # passes the search back, any other item ends it
  defp named_day(row, rows),
    do: row |> previous(rows) |> Enum.reduce_while(nil, fn text, _ -> day_or_back(text) end)

  defp day_or_back(text) do
    case Regex.run(@day, text) do
      [_, day] -> {:halt, day}
      nil -> if Regex.match?(@that, text), do: {:cont, nil}, else: {:halt, nil}
    end
  end

  # the items before this one under the same provision, nearest first
  defp previous(%{section_id: id}, rows) do
    parent = parent(id)

    rows
    |> Enum.take_while(&(&1.section_id != id))
    |> Enum.reverse()
    |> Enum.filter(&(&1.section_id != parent and parent(&1.section_id) == parent))
    |> Enum.map(&(Map.get(&1, :text) || ""))
  end

  defp parent(id), do: String.replace(id, ~r/\([^()]*\)$/, "")
end
