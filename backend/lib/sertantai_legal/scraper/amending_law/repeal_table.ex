defmodule SertantaiLegal.Scraper.AmendingLaw.RepealTable do
  @moduledoc """
  A Schedule of repeals (lat-refactor LR-08): a table of Chapter / Short
  title / Extent of repeal, the usual pre-2002 form. A row matches when the
  Chapter ("1989 c. 29.") or Short title names the row's law and the
  Extent names its provision: "Section 36." / "Sections 41 to 43." (the
  provision repealed) or "In section 40, the words …" (words repealed, on
  the section's own row). Anything else is no match. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RowRef}

  @doc "The row a repeals table targets, with its effect type; `:not_a_table` when the element has none."
  @spec match(Doc.t(), String.t(), RowRef.t()) ::
          {:ok, String.t(), String.t()} | :no_match | :not_a_table
  def match(doc, id, %RowRef{} = row) do
    case rows(Doc.element(doc, id)) do
      nil -> :not_a_table
      rows -> rows |> Enum.filter(&law?(&1, row)) |> Enum.find_value(:no_match, &extent(&1, row))
    end
  end

  @doc "The provision giving effect to the Schedule (its Reference, \"Section 108.\" → section-108)."
  @spec reference(Doc.t(), String.t()) :: String.t() | nil
  def reference(doc, id) do
    with el when el != nil <- Doc.element(doc, id),
         [_, n] <-
           Regex.run(
             ~r/Section (\d+[A-Z]*)/,
             el |> xpath(~x"./Reference//text()"ls) |> Enum.join()
           ) do
      "section-#{n}"
    else
      _ -> nil
    end
  end

  defp rows(nil), do: nil

  # header in <th> or in the first row's cells (modern tables use <td> +
  # Emphasis); 3 columns (Chapter, Short title, Extent) or 2 (Reference,
  # Extent): {the law's cells joined, the extent's lines}
  defp rows(el) do
    trs = xpath(el, ~x".//*[local-name()='tr']"l)
    cells = Enum.map(trs, &xpath(&1, ~x"./*[local-name()='td' or local-name()='th']"l))
    header = cells |> List.first([]) |> Enum.map_join(" ", &Doc.text/1)

    if header =~ ~r/Extent of (?:repeal|revocation)/i do
      for row <- tl(cells), length(row) in [2, 3] do
        {law_cells, [extent]} = Enum.split(row, -1)
        {Enum.map_join(law_cells, " ", &Doc.text/1), Doc.lines(extent)}
      end
    end
  end

  # the row's law: its chapter ("1989 c. 29", "1949 (c. 88)" after its
  # title) or its title and year
  defp law?({law, _}, row) do
    law =~ ~r/\b#{row.year} \(?c\. #{row.number}\b/ or
      (is_binary(row.title) and String.contains?(norm(law), norm("#{row.title} #{row.year}")))
  end

  defp norm(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, " ") |> String.trim()

  # an extent line naming the row: "Section 36." / "Sections 41 to 43." /
  # "Section 28(5) and (5A)." / "In section 11A(1), paragraphs (a) and (b)."
  # (provisions repealed) or "In section 57(1), the words …" (words, on
  # the row the words are in)
  defp extent({_, lines}, %RowRef{kind: :section} = row),
    do: Enum.find_value(lines, &line(&1, row))

  defp extent(_entry, _row), do: nil

  defp line(line, row) do
    case Regex.run(
           ~r/^(?:In )?[Ss]ections? (\d+[A-Z]*)((?:\([^)]*\))*)(?: to (\d+[A-Z]*))?(.*)$/,
           line
         ) do
      [_, n, subs, to, rest] -> named(row, n, brackets(subs), to, rest)
      _ -> nil
    end
  end

  defp named(row, n, subs, to, rest) do
    cond do
      to != "" ->
        if row.subs == [] and in_range?(row.number_ref, n, to),
          do: {:ok, row.section_id, "repealed"}

      n != row.number_ref ->
        nil

      rest =~ ~r/\bwords?\b/ ->
        if row.subs == subs, do: {:ok, row.section_id, "words repealed"}

      true ->
        whole(row, subs ++ brackets(rest))
    end
  end

  defp whole(row, []), do: if(row.subs == [], do: {:ok, row.section_id, "repealed"})

  defp whole(row, named),
    do:
      if(row.subs != [] and Enum.all?(row.subs, &(&1 in named)),
        do: {:ok, row.section_id, "repealed"}
      )

  defp brackets(s),
    do: for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, s, capture: :all_but_first), do: b)

  defp in_range?(n, a, b) do
    with {n, ""} <- Integer.parse(n), {a, ""} <- Integer.parse(a), {b, ""} <- Integer.parse(b) do
      n >= a and n <= b
    else
      _ -> false
    end
  end
end
