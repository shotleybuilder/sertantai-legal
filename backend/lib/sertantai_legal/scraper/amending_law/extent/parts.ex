defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Parts do
  @moduledoc """
  The Parts an extent clause names, as their sections (CV-S05; decomposed
  from `AmendingLaw.Extent`, run time 2026-10-25): "Parts I and II", "Part
  1" where the document's ids are roman ("part-I") and the reverse, "Parts
  1 to 5", "this Part"; never a Schedule's or a Chapter's Part. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @doc """
  The sections of the Parts named in `text` ("Part III", "Parts I and II";
  "this Part": the one holding the clause `clause_ref`), from the document.
  """
  @spec parts(String.t(), Doc.t(), String.t() | nil) :: [String.t()]
  def parts(text, doc, clause_ref) do
    # (never a Schedule's Part: "Part 2 of Schedule 10", "Parts 4 and 5 of
    # Schedule 13" — the list matched whole, CV-S05)
    # (nor a Chapter's Part: "Chapter 3 of Part 1", 2004/20; nor a
    # bracketed description: "paragraphs 53 and 59 of Schedule 15 (Part 7:
    # consequential provision etc.)", HSCA 2012 s.308(3)(f) — CV-S05)
    text = Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, text, "")

    text =
      Regex.replace(
        ~r/\bChapters?\s+[\dIVXLC]+[A-Z]*(?:\s*(?:,|and|to)\s*[\dIVXLC]+[A-Z]*)*\s+of\s+Part\s+[\dIVXLC]+[A-Z]*/u,
        text,
        ""
      )

    named =
      case Regex.run(
             ~r/(?<![Ii]n\s)\bParts?\s+((?>[IVXLC\d]+[A-Z]*(?:\s*(?:,|and|to)\s*[IVXLC\d]+[A-Z]*)*))\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)/u,
             text
           ) do
        [_, list] ->
          # "Part 1" where the document's ids are "part-I", and the reverse
          # (CPA 1987 s.49(1): CV-S05 N15)
          for n <- part_numbers(list),
              id <- ["part-#{n}", "part-#{other_numeral(n)}"],
              Doc.element(doc, id) != nil,
              uniq: true,
              do: id

        nil ->
          []
      end

    this =
      if text =~ ~r/\bthis Part\b/i and clause_ref,
        do: Enum.filter(doc.ids, &(&1 =~ ~r/^part-/ and holds?(doc, &1, clause_ref))),
        else: []

    for part <- named ++ this,
        el = Doc.element(doc, part),
        el != nil,
        id <- doc.ids,
        id =~ ~r/^(?:section|regulation|article|rule)-\d+[A-Z]*$/,
        holds_id?(doc, part, id),
        ref = Order.ref(id),
        uniq: true,
        do: ref
  end

  # "I and III", "1 to 5" (each between: CV-S05 N5), "IV to VI"
  defp part_numbers(list) do
    list
    |> String.split(~r/\s*(?:,|\band\b)\s*/u, trim: true)
    |> Enum.flat_map(fn piece ->
      case Regex.run(~r/^([IVXLC\d]+)\s+to\s+([IVXLC\d]+)$/u, String.trim(piece)) do
        [_, a, b] ->
          roman? = a =~ ~r/^[IVXLC]+$/

          {x, y} =
            if roman?,
              do: {arabic(a), arabic(b)},
              else: {String.to_integer(a), String.to_integer(b)}

          for i <- x..y//1, do: if(roman?, do: roman(i), else: Integer.to_string(i))

        nil ->
          List.flatten(Regex.scan(~r/[IVXLC\d]+[A-Z]*/u, piece))
      end
    end)
  end

  # 1 ↔ I, 12 ↔ XII (a letter suffix kept: "2A" ↔ "IIA")
  defp other_numeral(n) do
    case Regex.run(~r/^(\d+)([A-Z]*)$/, n) do
      [_, d, suffix] ->
        roman(String.to_integer(d)) <> suffix

      nil ->
        case Regex.run(~r/^([IVXLC]+)([A-Z]?)$/, n) do
          [_, r, suffix] -> Integer.to_string(arabic(r)) <> suffix
          nil -> n
        end
    end
  end

  @romans [
    {100, "C"},
    {90, "XC"},
    {50, "L"},
    {40, "XL"},
    {10, "X"},
    {9, "IX"},
    {5, "V"},
    {4, "IV"},
    {1, "I"}
  ]

  defp roman(0), do: ""

  defp roman(n),
    do: with({v, r} <- Enum.find(@romans, fn {v, _} -> v <= n end), do: r <> roman(n - v))

  defp arabic(r) do
    r
    |> String.graphemes()
    |> Enum.map(&%{"I" => 1, "V" => 5, "X" => 10, "L" => 50, "C" => 100}[&1])
    |> Enum.chunk_every(2, 1, [0])
    |> Enum.reduce(0, fn [a, b], acc -> if a < b, do: acc - a, else: acc + a end)
  end

  defp holds?(doc, part, ref) do
    Enum.any?(doc.ids, &(Order.ref(&1) == ref and holds_id?(doc, part, &1)))
  end

  # the element `id` lies inside the Part (document order: after it, before
  # the next Part)
  defp holds_id?(doc, part, id) do
    case {Map.get(doc.pos, part), Map.get(doc.pos, id)} do
      {p, i} when is_integer(p) and is_integer(i) and i > p ->
        next = Doc.next_part(doc, p)
        next == nil or i < Map.fetch!(doc.pos, next)

      _ ->
        false
    end
  end
end
