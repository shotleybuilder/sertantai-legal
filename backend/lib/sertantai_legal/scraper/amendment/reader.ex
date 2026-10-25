defmodule SertantaiLegal.Scraper.Amendment.Reader do
  @moduledoc """
  An amending provision read once into amendment rules (amendment-rules
  AR-03), for the laws its notes point to (`laws`: one hop from our rows) —
  the row-driven matchers (LR-08 `Target` / `RepealTable`, deleted at AR-04)
  turned round: the targets they would accept, expanded at read time.

  - **The law:** the nearest text naming any law decides — the instruction,
    its context nearest first, the container's title, then the text before
    (its Part's earlier provisions, the Part's headings, earlier Parts)
    (LR-41); it must name the law (title and year, chapter, or a defined term
    meaning it).
  - **Quoted provisions:** an insertion or substitution reaches the paths its
    quote numbers — a provision's ([11A], [11A, 1]), the named brackets then
    the path ((2) + [ca]), or paths numbered from the substituted subsection
    ("for subsection (3) substitute— (3)(a)": LR-43). The operation is the
    quoting clause's (`Operation.of_quoted/1`).
  - **Named provisions:** a provision named with no brackets is the whole
    provision; with brackets, every combination of the brackets named
    ("subsection (5), paragraphs (b) and (c)"). An insertion reaches only
    what it quotes or names as inserted ("In subsection (1) … insert" is
    where, not what). A quote's own provision is never reached as a named one.
  - **Repeals tables:** a line naming a section, a range, its brackets, or
    words in it ("In section 40, the words …").
  - **Level:** words-level when the instruction quotes or names words,
    definitions or entries; else whole provisions.

  The note is a pointer (which provisions to read); the date is the
  commencement ruleset's. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.Amendment.Reader.{Brackets, Clauses, LawNamed, Targets}
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Operation, Text}

  @type law_ref :: %{
          law_name: String.t(),
          title: String.t() | nil,
          year: String.t(),
          number: String.t(),
          kind: :section | :regulation | :article | :rule
        }

  # "shall have effect as if … were omitted", "be read as if": a
  # modification, not an amendment (SI 1974/2013 Sch. 2 para. 15)
  @modification ~r/\b(?:have effect|be read|be construed) as if\b/i

  # "The provisions set out in Part I of Schedule 4 shall be substituted for
  # Part VIII of …" (EReA 1999 s.7), "The section set out in Part I of
  # Schedule 1 to this Act shall be inserted after section 35 of …" (1982
  # c.53): the quote is the amending law's own Schedule (AR-05); "is amended
  # as set out in Schedule 1" points to the Schedule's instructions instead
  @set_out ~r/\bset out in (?:Part ([IVXLC\d]+[A-Z]?) of )?Schedule ([\dA-Z]+)\b(?: to th(?:is|ese) \w+)?,? (?:shall be|is|are) (?:substituted for|inserted (?:after|before)) (?:the )?(?:Part|Chapter|sections?|regulations?|articles?|rules?)\b/i

  # a bracket is a number, a letter or two, or a roman numeral — never a
  # word ("(interpretation)": a one-word caption, AR-07)

  @prefix %{section: "s", regulation: "reg", article: "art", rule: "rule"}

  @doc "The law ref of a law name and its title (`kind` from its LAT prefix: \"s\", \"reg\", …)."
  @spec law_ref(String.t(), String.t() | nil, String.t()) :: law_ref()
  def law_ref(law_name, title, prefix) do
    [_, _type, year, number] = String.split(law_name, "_", parts: 4)
    kind = %{"s" => :section, "reg" => :regulation, "art" => :article, "rule" => :rule}[prefix]
    %{law_name: law_name, title: title, year: year, number: number, kind: kind || :section}
  end

  @doc """
  The rules an amending provision (`id` in `doc`, its defined `terms`)
  states for `laws`: a repeals table's lines, else a single provision's
  instruction — never a whole Schedule or Part read as one.
  """
  @spec read(Doc.t(), String.t(), map(), [law_ref()]) :: [Rule.t()]
  def read(doc, id, terms, laws) do
    cond do
      repeal_table?(doc, id) -> repeal_table(doc, id, laws)
      provision?(id) -> instruction(doc, id, terms, laws)
      true -> []
    end
  end

  defp provision?(id),
    do: Regex.match?(~r/^(?:section|regulation|article|rule)-|^schedule-[^-]+-paragraph-/, id)

  @doc """
  Each Schedule's introducing section, by the Schedule's id
  (`"schedule-7" => "section-111"`): the Schedule's own reference
  (`reference/2`, where the schedules are held), else the section saying it
  has effect ("111 Schedule 7, which supplements section 110 …, has
  effect", where only the body is held). The one reader of this fact: the
  repeals tables' sources (`Collect`) and an Act's extent
  (`AmendingLaw.Extent`) use it.
  """
  @spec references(Doc.t()) :: %{String.t() => String.t()}
  def references(doc) do
    referenced =
      for id <- doc.ids,
          String.match?(id, ~r/^schedule-[^-]+$/),
          ref = reference(doc, id),
          ref != nil,
          into: %{},
          do: {id, ref}

    Map.merge(has_effect(doc), referenced)
  end

  # "111 Schedule 7 … has effect": in a section's own words (not a
  # subsection's, which says it of a Schedule it amends)
  defp has_effect(doc) do
    for id <- doc.ids,
        String.match?(id, ~r/^section-\d+[A-Z]*$/),
        text = doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" "),
        [_, n] <-
          Regex.scan(
            ~r/\bSchedule\s+(\d+[A-Z]*)\b[^.]{0,300}?\b(?:has|shall have) effect\b/u,
            text
          ),
        into: %{},
        do: {"schedule-#{n}", id}
  end

  @doc """
  Each Schedule paragraph's Part, by the paragraph's id
  (`schedule-4-paragraph-10` → `schedule-4-part-III`): an order may date a
  Part ("Section 9 and Part III of Schedule 4": SI 1999/2830, AR-12), and a
  paragraph's id doesn't carry it.
  """
  @spec parts(Doc.t()) :: %{String.t() => String.t()}
  def parts(doc) do
    doc.ids
    |> Enum.reduce({%{}, nil}, fn id, {acc, part} ->
      cond do
        id =~ ~r/^schedule-[^-]+$/ ->
          {acc, nil}

        id =~ ~r/^schedule-[^-]+-part-[^-]+$/ ->
          {acc, id}

        part != nil and String.starts_with?(id, schedule_of(part) <> "-paragraph-") ->
          {Map.put(acc, id, part), part}

        true ->
          {acc, part}
      end
    end)
    |> elem(0)
  end

  defp schedule_of(part), do: part |> String.split("-part-") |> hd()

  @doc "The provision giving effect to a Schedule (its Reference, \"Section 108.\" → section-108)."
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

  @doc "The rules an instruction (`id` in `doc`) states for `laws`."
  @spec instruction(Doc.t(), String.t(), map(), [law_ref()]) :: [Rule.t()]
  def instruction(doc, id, terms, laws) do
    case Text.of(doc, id) do
      %Text{} = text ->
        text
        |> set_out(doc)
        |> of_text(Doc.title(doc, id), terms, articles_only(laws, doc, id), %{
          law: doc.law_name,
          ref: id,
          text: text.instruction
        })

      _ ->
        []
    end
  end

  # an instruction under a heading amending an EU law's Annexes or
  # Appendices numbers that Annex's paragraphs, never its Articles ("8.1.1.1",
  # "4" in "Amendment of the Annexes and Appendices to the REACH
  # Regulation": SI 2019/758 Sch. 3): no Article rules until Annex targets
  # are read (run time, 2026-10-25)
  defp articles_only(laws, doc, id) do
    if Enum.any?(Doc.headings(doc, id), &(&1 =~ ~r/\b(?:Annex(?:es)?|Appendi(?:x|ces))\b/)),
      do: Enum.reject(laws, &(&1.kind == :article)),
      else: laws
  end

  # an instruction quoting nothing, whose block is set out in its own
  # Schedule: the provisions that Schedule (or its Part) quotes, gathered
  # from the elements under it (each quote sits in a wrapper with its own id)
  defp set_out(%Text{inserted: [], instruction: i} = text, doc) do
    case Regex.run(@set_out, i) do
      [_, part, schedule] ->
        block =
          if part == "", do: "schedule-#{schedule}", else: "schedule-#{schedule}-part-#{part}"

        paths =
          for id <- doc.ids,
              id == block or String.starts_with?(id, block <> "-"),
              %Text{inserted: ins} <- [Text.of(doc, id)],
              path <- ins,
              uniq: true,
              do: path

        %{text | inserted: paths}

      nil ->
        text
    end
  end

  defp set_out(text, _doc), do: text

  @doc "The rules an instruction's `text` (its containers' titles, nearest first, or one title) states for `laws`, with `source` on each."
  @spec of_text(Text.t(), String.t() | [String.t()] | nil, map(), [law_ref()], map()) :: [
          Rule.t()
        ]
  def of_text(%Text{} = text, title, terms, laws, source) do
    case if(text.instruction =~ @modification, do: nil, else: Clauses.operation(text)) do
      {_, _} ->
        texts =
          Enum.map([text.instruction | Enum.reverse(text.context)], &Clauses.unquote_words/1)

        before = Stream.map(text.before, &Clauses.unquote_words/1)

        # the laws named, found once for every law offered (run time,
        # 2026-10-25: found per law, 24× over for ukpga 1995/25)
        named = LawNamed.named(Stream.concat(texts ++ List.wrap(title), before), terms)

        for law <- laws,
            Enum.any?(named, &LawNamed.law_named?(&1, law)),
            rule <- rules(text, texts, law, source, terms),
            do: rule

      nil ->
        []
    end
  end

  # one rule per operation (AR-08): each clause of a mixed instruction
  # ("omit “either”; and at the end insert—") its own level, brackets and
  # numbers; the quote is the clause's that introduces it
  defp rules(text, texts, law, source, terms) do
    p = @prefix[law.kind]
    tops = text.inserted |> Enum.map(&hd/1) |> Enum.uniq()
    clauses = text |> Clauses.clauses() |> LawNamed.scoped(texts, law, terms)
    quoting = Targets.quoting_clause(clauses)

    quoted =
      case quoting do
        nil ->
          nil

        c ->
          Targets.rule(
            law,
            Targets.quoted_targets(c, p),
            Operation.of_quoted(Clauses.captionless(c.text)),
            source
          )
      end

    named =
      for c <- clauses,
          op = Clauses.operation(c.text),
          op != nil,
          # an insertion reaches only what it quotes or names as inserted
          targets =
            for(
              n <- c.numbers,
              n not in tops,
              t <- Targets.named_refs(c.text, op, p, n, c.named),
              uniq: true,
              do: t
            ),
          do: Targets.rule(law, targets, op, source)

    Enum.reject([quoted | named], &is_nil/1)
  end

  # ── repeals tables ──────────────────────────────────────────────────

  @doc "The rules a repeals table (`id` in `doc`: a Schedule of repeals) states for `laws`; [] when not a table."
  @spec repeal_table(Doc.t(), String.t(), [law_ref()]) :: [Rule.t()]
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
