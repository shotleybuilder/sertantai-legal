defmodule SertantaiLegal.Scraper.LawStart.ThatDay do
  @moduledoc """
  A list item counting from "that day": the day the item before it names —
  "(a) sections 150 … which come into force on the day on which this Act
  is passed; (b) sections 151 and 177, which come into force at the end of
  the period of 2 months beginning with that day" (2014 c.12 s.185(2)).
  `resolve/2` gives the item's row with the day written out, so the clause
  reader counts from it. Only a day of passing or making is carried: any
  other day stays as written. Pure.
  """

  @that ~r/\b(beginning\s+with|after|following|from)\s+that\s+(?:day|date)\b/i
  @day ~r/\bon\s+(the\s+(?:day|date)\s+(?:on\s+which\s+)?(?:this\s+Act|it|they|these\s+Regulations|this\s+Order)\s+(?:is|are)\s+(?:passed|made)|the\s+(?:day|date)\s+of\s+Royal\s+Assent|the\s+(?:day|date)\s+on\s+which\s+this\s+Act\s+receives\s+Royal\s+Assent)/i

  @doc "`row` with \"that day\" written out as the day the item before it (in `rows`) names."
  @spec resolve(map(), [map()]) :: map()
  def resolve(%{text: text} = row, rows) when is_binary(text) do
    with true <- Regex.match?(@that, text),
         %{text: before} when is_binary(before) <- previous(row, rows),
         [_, day] <- Regex.run(@day, before) do
      %{row | text: Regex.replace(@that, text, "\\1 #{day}")}
    else
      _ -> row
    end
  end

  def resolve(row, _rows), do: row

  # the item before this one under the same provision
  defp previous(%{section_id: id}, rows) do
    parent = parent(id)

    rows
    |> Enum.take_while(&(&1.section_id != id))
    |> Enum.reverse()
    |> Enum.find(&(&1.section_id != parent and parent(&1.section_id) == parent))
  end

  defp parent(id), do: String.replace(id, ~r/\([^()]*\)$/, "")
end
