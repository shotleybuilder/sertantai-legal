defmodule SertantaiLegal.Scraper.Amendment.Reader.RepealTable do
  @moduledoc """
  A repeals table read into rules (AR-03, AR-06, AR-08, AR-13; decomposed
  from `Amendment.Reader`, run time 2026-10-25): each line naming a law in
  the table's law column, each entry a target — words or whole provisions,
  a piece each where a line mixes them. Pure; calls `Reader.Brackets` and
  `Reader.LawNamed` (titles compared). `Amendment.Reader` delegates
  `repeal_table/3` and `repeal_table?/2` here.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}
  alias SertantaiLegal.Scraper.Amendment.Reader.{Brackets, Clauses, LawNamed}

  @doc "The rules a repeals table (`id` in `doc`: a Schedule of repeals) states for `laws`; [] when not a table."
  @spec repeal_table(Doc.t(), String.t(), [Reader.law_ref()]) :: [Rule.t()]
  def repeal_table(doc, id, laws) do
    case table_rows(Doc.element(doc, id)) do
      nil ->
        []

      rows ->
        for {law_cells, lines} <- rows,
            law <- laws,
            law.kind == :section,
            table_law?(law_cells, law),
            line <- lines,
            {targets, level} <- List.wrap(line_targets(line)),
            do:
              Rule.new(
                amends: law.law_name,
                targets: targets,
                operation: :repealed,
                level: level,
                source: %{law: doc.law_name, ref: id, text: line},
                treatment: :repeal_table
              )
    end
  end

  @doc "True when the element is a repeals table."
  @spec repeal_table?(Doc.t(), String.t()) :: boolean()
  def repeal_table?(doc, id), do: table_rows(Doc.element(doc, id)) != nil

  defp table_rows(nil), do: nil

  defp table_rows(el) do
    trs = xpath(el, ~x".//*[local-name()='tr']"l)
    cells = Enum.map(trs, &xpath(&1, ~x"./*[local-name()='td' or local-name()='th']"l))
    header = cells |> List.first([]) |> Enum.map_join(" ", &Doc.text/1)

    if header =~ ~r/Extent of (?:repeal|revocation)/i do
      for row <- tl(cells), length(row) in [2, 3] do
        {law_cells, [extent]} = Enum.split(row, -1)

        {Enum.map_join(law_cells, " ", &Doc.text/1),
         extent |> Doc.lines() |> Enum.flat_map(&entries/1)}
      end
    end
  end

  # a new entry after a full stop ("Sections 75 to 84.Section 103.In section
  # 109(3), …": run together in the source, AR-13), never inside quoted words
  @entry ~r/\.\s*(?=(?:In\s+)?(?:[Ss]ections?|Schedules?)\s+\d|In\s+Schedule\b)/

  defp entries(line) do
    masked = Regex.replace(~r/[“"][^”"]*[”"]/u, line, &String.duplicate("x", byte_size(&1)))

    cuts = for [{pos, len}] <- Regex.scan(@entry, masked, return: :index), do: pos + len

    [0 | cuts]
    |> Enum.zip(cuts ++ [byte_size(line)])
    |> Enum.map(fn {a, b} -> line |> binary_part(a, b - a) |> String.trim() end)
    |> Enum.reject(&(&1 == ""))
  end

  defp table_law?(cells, law) do
    cells =~ ~r/\b#{law.year} \(?c\. #{law.number}\b/ or
      (is_binary(law.title) and
         String.contains?(LawNamed.norm(cells), LawNamed.norm("#{law.title} #{law.year}")))
  end

  # "Section 36." / "Sections 41 to 43." / "Section 28(5) and (5A)." /
  # "In section 11A(1), paragraphs (a) and (b)." / "In section 57(1), the words …"
  defp line_targets(line) do
    case Regex.run(
           ~r/^(?:In )?[Ss]ections? (\d+[A-Z]*)((?:\([^)]*\))*)(?: to (\d+[A-Z]*))?(.*)$/,
           line
         ) do
      [_, n, subs, to, rest] ->
        subs = Brackets.plain_brackets(subs)
        {siblings, after_siblings} = siblings(subs, rest)

        cond do
          to != "" ->
            {["s.#{n}..s.#{to}"], :provision}

          # "In section 117(2) and (3), the words …": the words in each (AR-13)
          siblings != [] and words_line?(after_siblings) ->
            {Enum.flat_map(siblings, &words_targets(n, &1, located(after_siblings))), :words}

          mixed = mixed_line(n, subs, rest) ->
            mixed

          words_line?(rest) ->
            {words_targets(n, subs, located(rest)), :words}

          true ->
            whole_targets(n, subs ++ Brackets.plain_brackets(rest))
        end

      _ ->
        nil
    end
  end

  # brackets listed after the section's own ("117(2) and (3), the words"):
  # each sibling's path and the rest after them; [] when none
  defp siblings([_ | _] = subs, rest) do
    case Regex.run(~r/^\s*,?\s*and\s+((?:\([0-9A-Za-z]+\))+)(.*)$/s, rest) do
      [_, bs, after_siblings] ->
        {[subs, Enum.drop(subs, -1) ++ Brackets.plain_brackets(bs)], after_siblings}

      nil ->
        {[], rest}
    end
  end

  defp siblings([], rest), do: {[], rest}

  # "in subsection (1)", "in paragraph (b)": where the words are, not a
  # provision repealed — its brackets narrow the words' row (AR-06)
  @located ~r/\bin\s+(?:sub-?)?(?:section|subsection|paragraph|sub-?paragraph)\s+((?:\([0-9A-Za-z]+\))+)/i

  # each place a path of its own ("in subsection (1) … and, in subsection
  # (2), …" → (1) and (2), never (1)(2))
  defp located(rest),
    do:
      for(
        [_, bs] <- Regex.scan(@located, Clauses.unquote_words(rest)),
        do: Brackets.plain_brackets(bs)
      )

  # a line repealing words and provisions ("in subsection (1) the
  # definitions of …; and subsection (2)"): read piece by piece — "in
  # subsection (5)" the place, a piece with words a words target there, a
  # provision named ("paragraph (b)", "(6)") a provision under it (AR-08);
  # nil unless both
  # a paragraph of a definition is words in the provision ("paragraph (b)
  # of the definition of …", "in the definition of “…”, paragraph (c)")
  @of_definition ~r/(?:sub-?)?paragraphs?\s+(?:\([0-9A-Za-z]+\)\s*)+of\s+(?:the\s+)?definitions?\b|\bdefinitions?\s+of\s*x*\s*,?\s*(?:sub-?)?paragraphs?\s+(?:\([0-9A-Za-z]+\)\s*)+/i

  @located_end ~r/\bin\s+(?:sub-?)?(?:section|subsection|paragraph|sub-?paragraph)\s+(?:\([0-9A-Za-z]+\))+[\s.]*$/i
  @glued ~r/\.\s*(?:In\s+)?(?:[Ss]ections?\s+\d|Schedules?\s+\d|In\s+Schedule\b)/

  @named_provision ~r/^(?:(?:sub-?)?(?:sections?|subsections?|paragraphs?|sub-?paragraphs?)\s*)?((?:\([0-9A-Za-z]+\))+)(?:\s+to\s+(\([0-9A-Za-z]+\)))?$/i

  defp mixed_line(_n, _subs, rest) when not is_binary(rest), do: nil

  defp mixed_line(n, subs, rest) do
    # entries run together ("…(i).Sections 193 and 194.Schedule 1.") are
    # AR-13's: never read as pieces of one line
    if rest =~ @glued, do: nil, else: mixed_pieces(n, subs, rest)
  end

  defp mixed_pieces(n, subs, rest) do
    masked =
      ~r/[“"][^”"]*[”"]/u
      |> Regex.replace(rest, &String.duplicate("x", byte_size(&1)))
      |> then(
        &Regex.replace(@of_definition, &1, fn m ->
          String.pad_trailing("definition", byte_size(m))
        end)
      )

    cuts =
      for [{pos, len}] <- Regex.scan(~r/[;,]|\band\b/, masked, return: :index),
          do: {pos, pos + len}

    pieces =
      [{0, 0} | cuts]
      |> Enum.zip(cuts ++ [{byte_size(rest), byte_size(rest)}])
      |> Enum.map(fn {{_, a}, {b, _}} ->
        {binary_part(rest, a, b - a), binary_part(masked, a, b - a)}
      end)

    {targets, _} =
      Enum.flat_map_reduce(pieces, {[], nil}, fn {piece, m}, {place, trailing} ->
        place =
          case Regex.run(@located, m, capture: :all_but_first) do
            [bs] -> bs |> Brackets.plain_brackets() |> then(&(Brackets.above(place, &1) ++ &1))
            nil -> place
          end

        bare = m |> String.replace(@located, "") |> String.replace(~r/^[\s.]+|[\s.]+$/, "")

        cond do
          bare =~ ~r/\bwords?\b|\bdefinitions?\b|\bentr(?:y|ies)\b|\bonwards\b|\bto the end\b/i or
              piece =~ ~r/[“"][^”"]*[”"]/u ->
            # "the words “…” in paragraph (b) and paragraph (c)": (c) is
            # another place for the words, not a provision repealed (a
            # provision of another level is: "… and subsection (12)")
            {[{Brackets.ref("s", [n | subs ++ place]), :words}],
             {place, if(m =~ @located_end, do: place |> List.last() |> Brackets.bracket_level())}}

          named = Regex.run(@named_provision, bare, capture: :all_but_first) ->
            {for(
               bs <- provisions(named),
               level =
                 if(Brackets.bracket_level(hd(bs)) == trailing, do: :words, else: :provision),
               do: {Brackets.ref("s", [n | subs ++ Brackets.above(place, bs) ++ bs]), level}
             ), {place, trailing}}

          true ->
            {[], {place, nil}}
        end
      end)

    by_level = Enum.group_by(targets, &elem(&1, 1), &elem(&1, 0))

    if Map.has_key?(by_level, :words) and Map.has_key?(by_level, :provision),
      do: for(l <- [:words, :provision], do: {Enum.uniq(by_level[l]), l})
  end

  # "(4)(b)" → [["4", "b"]]; "(7)" to "(10)" → (7), (8), (9), (10)
  defp provisions([g, ""]), do: [Brackets.plain_brackets(g)]
  defp provisions([g]), do: [Brackets.plain_brackets(g)]

  defp provisions([g, to]) do
    case {Brackets.plain_brackets(g), Brackets.plain_brackets(to)} do
      {[a], [b]} ->
        if a =~ ~r/^\d+$/ and b =~ ~r/^\d+$/ and String.to_integer(a) < String.to_integer(b),
          do: for(k <- String.to_integer(a)..String.to_integer(b), do: ["#{k}"]),
          else: [[a], [b]]

      {as, bs} ->
        [as, bs]
    end
  end

  defp words_targets(n, subs, []), do: [Brackets.ref("s", [n | subs])]

  defp words_targets(n, subs, places),
    do: for(p <- places, do: Brackets.ref("s", [n | subs ++ p]))

  # words in the provision: "the words …", a quote ("In section 53(1)(a)
  # “114”."), a definition or entry — unless a provision is named beside the
  # quote ("sub-paragraph (ii) and the preceding “and”") (AR-06)
  defp words_line?(rest) do
    unquoted =
      rest
      |> String.replace(~r/[“"][^”"]*[”"]/u, "x")
      |> String.replace(@of_definition, "definition")
      |> String.replace(@located, "")

    named? =
      unquoted =~ ~r/\b(?:sub-?)?(?:sections?|subsections?|paragraphs?|sub-?paragraphs?)\b/i

    unquoted =~ ~r/\bwords?\b/ or
      (not named? and
         (rest =~ ~r/[“"][^”"]+[”"]/u or unquoted =~ ~r/\b(?:definitions?|entr(?:y|ies))\b/))
  end

  defp whole_targets(n, []), do: {["s.#{n}"], :provision}

  defp whole_targets(n, named),
    do: {for(c <- Brackets.combos(named), do: Brackets.ref("s", [n | c])), :provision}
end
