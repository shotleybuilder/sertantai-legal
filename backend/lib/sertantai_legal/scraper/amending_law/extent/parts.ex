defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Parts do
  @moduledoc """
  The Parts an extent clause names, as their sections (CV-S05; decomposed
  from `AmendingLaw.Extent`, run time 2026-10-25): "Parts I and II", "Part
  1" where the document's ids are roman ("part-I") and the reverse, "Parts
  1 to 5", "this Part"; never a Schedule's or a Chapter's Part. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.Order

  @chapter_list "[\\dIVXLC]+[A-Z]*(?:\\s*(?:,|and|to)\\s*[\\dIVXLC]+[A-Z]*)*"
  @chapters Regex.compile!(
              "\\bChapters?\\s+(#{@chapter_list})\\s+of\\s+(?:Part\\s+([\\dIVXLC]+[A-Z]*)|(this)\\s+Part)\\b",
              "u"
            )

  @doc """
  The sections of the Parts and Chapters named in `text` ("Part III",
  "Parts I and II", "Chapter 3 of Part 1", "Chapters 1 and 2 of Part 2";
  "this Part": the one holding the clause `clause_ref`), from the
  document. A bare Chapter names nothing here: `qualify_chapters/1` first.
  """
  @spec parts(String.t(), Doc.t(), String.t() | nil) :: [String.t()]
  def parts(text, doc, clause_ref) do
    Enum.uniq(part_sections(text, doc, clause_ref) ++ chapters(text, doc, clause_ref))
  end

  @doc """
  Each bare Chapter given the Part named last before it, and "that Part"
  that Part ("… in Part 2— (i) Chapter 1 …, (ii) Chapter 2 …" → "Chapter 1
  of Part 2"; "(h) Chapter 1 of Part 3; (i) Chapter 2 of that Part" →
  "… of Part 3": Energy Act 2013 s.155(2)(b), CJA 2009 s.181(3), CV-S05
  NEW-A) — before a list is split into items. A Schedule's Part never.
  """
  @spec qualify_chapters(String.t()) :: String.t()
  def qualify_chapters(text) do
    ~r/\bPart\s+([\dIVXLC]+[A-Z]*)\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)|\bChapters?\s+#{@chapter_list}\b(?!\s+of\b)|\bthat\s+Part\b/u
    |> Regex.split(text, include_captures: true)
    |> Enum.map_reduce(nil, fn piece, part ->
      cond do
        m = Regex.run(~r/^Part\s+([\dIVXLC]+[A-Z]*)$/u, piece) -> {piece, Enum.at(m, 1)}
        piece =~ ~r/^Chapters?\s/u and part != nil -> {"#{piece} of Part #{part}", part}
        piece =~ ~r/^that\s+Part$/u and part != nil -> {"Part #{part}", part}
        true -> {piece, part}
      end
    end)
    |> elem(0)
    |> Enum.join()
  end

  # the sections inside each Chapter named ("part-2-chapter-1": the Part's
  # id in either numeral), up to the next Chapter or Part
  defp chapters(text, doc, clause_ref) do
    text = Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, text, "")

    for [_, list, part | this] <- Regex.scan(@chapters, text),
        p <- chapter_parts(part, this, doc, clause_ref),
        n <- part_numbers(list),
        id <- ["#{p}-chapter-#{n}", "#{p}-chapter-#{other_numeral(n)}"],
        Map.has_key?(doc.pos, id),
        sid <- chapter_ids(doc, id),
        uniq: true,
        do: Order.ref(sid)
  end

  defp chapter_parts("", ["this"], doc, clause_ref) when is_binary(clause_ref),
    do: Enum.filter(doc.ids, &(&1 =~ ~r/^part-[^-]+$/ and holds?(doc, &1, clause_ref)))

  defp chapter_parts(n, _this, _doc, _clause_ref) when n != "",
    do: Enum.uniq(["part-#{n}", "part-#{other_numeral(n)}"])

  defp chapter_parts(_, _, _, _), do: []

  defp chapter_ids(doc, chapter) do
    start = Map.fetch!(doc.pos, chapter)

    doc.ids
    |> Enum.drop(start + 1)
    |> Enum.take_while(&(not (&1 =~ ~r/^part-[^-]+(?:-chapter-[^-]+)?$/)))
    |> Enum.filter(&(&1 =~ ~r/^(?:section|regulation|article|rule)-\d+[A-Z]*$/))
  end

  defp part_sections(text, doc, clause_ref) do
    # (never a Schedule's Part: "Part 2 of Schedule 10", "Parts 4 and 5 of
    # Schedule 13" — the list matched whole, CV-S05)
    # (nor a Chapter's Part: "Chapter 3 of Part 1", 2004/20; nor a
    # bracketed description: "paragraphs 53 and 59 of Schedule 15 (Part 7:
    # consequential provision etc.)", HSCA 2012 s.308(3)(f) — CV-S05)
    text = Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, text, "")

    # (a Chapter's Part is the Chapter's: `chapters/3`)
    text =
      Regex.replace(
        ~r/\bChapters?\s+[\dIVXLC]+[A-Z]*(?:\s*(?:,|and|to)\s*[\dIVXLC]+[A-Z]*)*\s+of\s+(?:Part\s+[\dIVXLC]+[A-Z]*|th(?:is|at)\s+Part)/u,
        text,
        ""
      )

    # every Part named ("Part 3 and Part 4": SI 2022/1037 reg.2, CV-S05;
    # "Part 2, 3, or 4", never "Part 1, 8 … or 19 of Schedule 18": round 13
    # S3, ukpga 2007/28)
    named =
      for [_, list] <-
            Regex.scan(
              ~r/(?<![Ii]n\s)\bParts?\s+((?>[IVXLC\d]+[A-Z]*(?:(?:\s*,\s*(?:and|or)?|\s+and|\s+to|\s+or)\s*[IVXLC\d]+[A-Z]*)*))\b(?!\s+(?:of|to)\s+(?:that\s+|the\s+)?Schedule)/u,
              text
            ),
          # "Part 1" where the document's ids are "part-I", and the reverse
          # (CPA 1987 s.49(1): CV-S05 N15)
          n <- part_numbers(list),
          id <- ["part-#{n}", "part-#{other_numeral(n)}"],
          Doc.element(doc, id) != nil,
          uniq: true,
          do: id

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
    |> String.split(~r/\s*(?:,|\band\b|\bor\b)\s*/u, trim: true)
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
