defmodule SertantaiLegal.Scraper.Amendment.Reader do
  @moduledoc """
  An amending provision read once into amendment rules (amendment-rules
  AR-03), for the laws its notes point to (`laws`: one hop from our rows) —
  the row-driven matchers (LR-08 `Target` / `RepealTable`, deleted at AR-04)
  turned round: the targets they would accept, expanded at read time.

  - **The law:** the nearest text naming any law decides — the instruction,
    its context nearest first, the container's title, then the text before
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

  # "the following paragraph", "a new subsection": the insertion is a provision
  @provision_named ~r/\b(?:following|new)\s+(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|provisions?|schedules?|parts?|chapters?)\b/i

  @kind_words %{
    section: "sections?",
    regulation: "regulations?",
    article: "articles?",
    rule: "rules?"
  }
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

  @doc "Each repeals table's introducing section (`reference/2`), by the table's id."
  @spec references(Doc.t()) :: %{String.t() => String.t()}
  def references(doc) do
    for id <- doc.ids,
        String.match?(id, ~r/^schedule-[^-]+$/),
        ref = reference(doc, id),
        ref != nil,
        into: %{},
        do: {id, ref}
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
        |> of_text(Doc.title(doc, id), terms, laws, %{
          law: doc.law_name,
          ref: id,
          text: text.instruction
        })

      _ ->
        []
    end
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

  @doc "The rules an instruction's `text` (its container's `title`) states for `laws`, with `source` on each."
  @spec of_text(Text.t(), String.t() | nil, map(), [law_ref()], map()) :: [Rule.t()]
  def of_text(%Text{} = text, title, terms, laws, source) do
    case if(text.instruction =~ @modification, do: nil, else: operation(text)) do
      {_, _} = op ->
        texts = Enum.map([text.instruction | Enum.reverse(text.context)], &unquote_words/1)
        before = Stream.map(text.before, &unquote_words/1)

        for law <- laws,
            law?(Stream.concat(texts ++ List.wrap(title), before), terms, law),
            rule <- rules(text, texts, op, law, source),
            do: rule

      nil ->
        []
    end
  end

  defp rules(text, texts, op, law, source) do
    p = @prefix[law.kind]
    quoting? = text.instruction =~ ~r/insert|substitut/i
    tops = if quoting?, do: text.inserted |> Enum.map(&hd/1) |> Enum.uniq(), else: []
    named = brackets(text)

    numbers =
      case numbers(texts, law.kind) do
        {:ok, ns} -> ns
        :none -> []
      end

    quoted =
      if quoting? do
        for path <- text.inserted,
            # "In section 7(1) … for paragraph (b) substitute— (b) … (c) …":
            # numbered from the provision holding the replaced bracket
            t <-
              [ref(p, path)] ++
                for(n <- numbers, do: ref(p, [n | named ++ path])) ++
                for(n <- numbers, named != [], hd(path) in named, do: ref(p, [n | path])) ++
                for(
                  n <- numbers,
                  length(named) > 1,
                  do: ref(p, [n | Enum.drop(named, -1) ++ path])
                ),
            do: t
      else
        []
      end

    # a quote's own provision is never reached as a named one; an insertion
    # reaches only what it quotes or names as inserted
    named_targets =
      for n <- numbers, n not in tops, t <- named_refs(text, op, p, n, named), do: t

    [
      rule(law, Enum.uniq(quoted), Operation.of_quoted(captionless(text)), source),
      rule(law, Enum.uniq(named_targets), op, source)
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp named_refs(text, {"inserted", "inserted"}, p, n, _named) do
    case {text.inserted, inserted_named(text)} do
      {[], [_ | _] = ins} -> for c <- combos(ins), do: ref(p, [n | c])
      _ -> []
    end
  end

  defp named_refs(_text, _op, p, n, []), do: [ref(p, [n])]
  defp named_refs(_text, _op, p, n, named), do: for(c <- combos(named), do: ref(p, [n | c]))

  defp rule(_law, [], _op, _source), do: nil

  defp rule(law, targets, {operation, type}, source),
    do:
      Rule.new(
        amends: law.law_name,
        targets: targets,
        operation: Rule.operation(operation),
        level: if(String.starts_with?(type, "words"), do: :words, else: :provision),
        source: source,
        treatment: :instruction
      )

  # "s" + ["25", "5A"] → "s.25(5A)"
  # a range "22..25" → "s.22..s.25" (whole provisions; with brackets, as
  # before ranges were read: its first number)
  defp ref(p, [n | subs]) do
    case {String.split(n, ".."), subs} do
      {[a, b], []} -> "#{p}.#{a}..#{p}.#{b}"
      {[a | _], _} -> "#{p}.#{a}" <> Enum.map_join(subs, &"(#{&1})")
    end
  end

  # the paths the brackets named make, by level — subsection (5), (5A);
  # paragraph (a), (ca); sub-paragraph (i), (iv); (A) — each level taken or
  # skipped, in that order (rows whose brackets are all named, as the
  # row-driven matcher's set semantics: "subsection (5), paragraphs (b) and
  # (c)" → (5), (5)(b), (5)(c), (b) …; "In paragraph (a) of section 7(2)"
  # → (2)(a)); a letter that is also a roman numeral is tried at both
  defp combos(named) do
    named = Enum.uniq(named)
    digits = Enum.filter(named, &(&1 =~ ~r/^\d/))
    letters = Enum.filter(named, &(&1 =~ ~r/^[a-z]+$/))
    romans = Enum.filter(letters, &(&1 =~ ~r/^(?:i{1,3}|iv|v|vi{1,3}|ix|x|xi{1,3})$/))
    capitals = Enum.filter(named, &(&1 =~ ~r/^[A-Z]+$/))

    [digits, letters, romans, capitals]
    |> Enum.reduce([[]], fn level, acc ->
      acc ++ for(path <- acc, b <- level, b not in path, do: path ++ [b])
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.uniq()
  end

  # words the instruction doesn't spell out: an emptied quote ("“”": the
  # quote held only markup — 1991 c.39 s.1(2)) or "each of the following is
  # omitted—" with no kind of provision named (a list of words: 2004 c.5)
  defp words_unnamed?(i),
    do:
      i =~ ~r/[“"]\s*[”"]/u or
        (i =~ ~r/\bthe following (?:is|are|shall be) (?:omitted|repealed|revoked)\b/i and
           not (i =~ @provision_named))

  # the instruction's operation, its captions aside; an insertion quoting
  # no provision "at the end" / "at the appropriate place" — and naming no
  # kind of provision as inserted — puts words into the provision named (2014 c.6 s.128(2)(e): a definition into s.235(1))
  defp operation(text) do
    case Operation.of(captionless(text)) do
      {verb, verb} = op when verb != "inserted" ->
        if words_unnamed?(text.instruction), do: {verb, "words #{verb}"}, else: op

      {"inserted", "inserted"} = op ->
        if text.inserted == [] and
             text.instruction =~ ~r/\bat the (?:end|beginning|appropriate places?)\b/i and
             not (text.instruction =~ @provision_named),
           do: {"inserted", "words inserted"},
           else: op

      op ->
        op
    end
  end

  # the instruction without its bracketed captions ("In section 118 (… of
  # revoked or suspended licences), after subsection (4) insert—": the verb
  # is "insert", not the caption's "revoked" — SI 1998/1420; "(“the 1984
  # Act”)" names a term, not words changed); quoted words keep their brackets
  defp captionless(%Text{instruction: i} = text),
    do: %{text | instruction: strip_captions(i)}

  # a bracketed caption: a parenthetical with a space, quotes inside allowed,
  # never starting inside a quote
  defp strip_captions(s) do
    ~r/[“"][^”"]*[”"]|\((?:[^()“”"]|[“"][^”"]*[”"])*\)/u
    |> Regex.replace(s, fn m -> if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: "" end)
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
        {Enum.map_join(law_cells, " ", &Doc.text/1), Doc.lines(extent)}
      end
    end
  end

  defp table_law?(cells, law) do
    cells =~ ~r/\b#{law.year} \(?c\. #{law.number}\b/ or
      (is_binary(law.title) and String.contains?(norm(cells), norm("#{law.title} #{law.year}")))
  end

  # "Section 36." / "Sections 41 to 43." / "Section 28(5) and (5A)." /
  # "In section 11A(1), paragraphs (a) and (b)." / "In section 57(1), the words …"
  defp line_targets(line) do
    case Regex.run(
           ~r/^(?:In )?[Ss]ections? (\d+[A-Z]*)((?:\([^)]*\))*)(?: to (\d+[A-Z]*))?(.*)$/,
           line
         ) do
      [_, n, subs, to, rest] ->
        subs = plain_brackets(subs)

        cond do
          to != "" -> {["s.#{n}..s.#{to}"], :provision}
          words_line?(rest) -> {[ref("s", [n | subs ++ located(rest)])], :words}
          true -> whole_targets(n, subs ++ plain_brackets(rest))
        end

      _ ->
        nil
    end
  end

  # "in subsection (1)", "in paragraph (b)": where the words are, not a
  # provision repealed — its brackets narrow the words' row (AR-06)
  @located ~r/\bin\s+(?:sub-?)?(?:section|subsection|paragraph|sub-?paragraph)\s+((?:\([0-9A-Za-z]+\))+)/i

  defp located(rest) do
    for [_, bs] <- Regex.scan(@located, unquote_words(rest)), b <- plain_brackets(bs), do: b
  end

  # words in the provision: "the words …", a quote ("In section 53(1)(a)
  # “114”."), a definition or entry — unless a provision is named beside the
  # quote ("sub-paragraph (ii) and the preceding “and”") (AR-06)
  defp words_line?(rest) do
    unquoted = rest |> unquote_words() |> String.replace(@located, "")

    unquoted =~ ~r/\b(?:words?|definitions?|entr(?:y|ies))\b/ or
      (rest =~ ~r/[“"][^”"]+[”"]/u and
         not (unquoted =~
                ~r/\b(?:sub-?)?(?:sections?|subsections?|paragraphs?|sub-?paragraphs?)\b/i))
  end

  defp whole_targets(n, []), do: {["s.#{n}"], :provision}
  defp whole_targets(n, named), do: {for(c <- combos(named), do: ref("s", [n | c])), :provision}

  defp plain_brackets(s),
    do: for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, s, capture: :all_but_first), do: b)

  # ── the law named (LR-41) ──────────────────────────────────────────

  defp law?(texts, terms, law) do
    texts
    |> Enum.find_value({:named, false}, fn t ->
      case laws(t, terms) do
        [] -> nil
        refs -> {:named, Enum.any?(refs, &law_named?(&1, law))}
      end
    end)
    |> elem(1)
  end

  defp unquote_words(t), do: String.replace(t, ~r/[“"][^”"]*[”"]/u, "")

  defp laws(t, terms) do
    lower = String.downcase(t)

    defined =
      for {term, law} <- terms,
          law.law != nil or law.title != nil,
          Regex.match?(~r/(?<![\w])#{Regex.escape(term)}(?![\w])/u, lower),
          do: law

    titled =
      for [x] <-
            Regex.scan(
              ~r/([A-Z][\w,'’()\- ]*? (?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4})/u,
              t,
              capture: :all_but_first
            ),
          do: %{law: nil, title: x}

    chapters =
      for [y, n] <- Regex.scan(~r/\b(\d{4}) c\. (\d+)/, t, capture: :all_but_first),
          do: %{law: nil, chapter: {y, n}}

    defined ++ titled ++ chapters
  end

  defp law_named?(%{law: name}, law) when is_binary(name), do: name == law.law_name
  defp law_named?(%{chapter: {y, n}}, law), do: y == law.year and n == law.number

  defp law_named?(%{title: t}, law) when is_binary(t) and is_binary(law.title),
    do: String.ends_with?(norm(t), norm("#{law.title} #{law.year}"))

  defp law_named?(_ref, _law), do: false

  defp norm(t),
    do:
      t
      |> String.downcase()
      |> String.replace(~r/^the /, "")
      |> String.replace(~r/[^a-z0-9]+/, " ")
      |> String.trim()

  # ── provisions named ───────────────────────────────────────────────

  # the provision numbers named; "22 to 25" a range ("22..25")
  defp numbers(texts, kind) do
    re = ~r/\b(?i:#{@kind_words[kind]}) (\d+[A-Z]*)(?:(?:,| and| or| to) (\d+[A-Z]*))*/u

    Enum.find_value(texts, :none, fn t ->
      case Regex.scan(re, t, capture: :first) do
        [] ->
          nil

        found ->
          {:ok,
           found
           |> List.flatten()
           |> Enum.flat_map(fn m ->
             m
             |> String.replace(~r/(\d+[A-Z]*) to (\d+[A-Z]*)/, "\\1..\\2")
             |> then(&Regex.scan(~r/\d+[A-Z]*(?:\.\.\d+[A-Z]*)?/, &1))
           end)
           |> List.flatten()}
      end
    end)
  end

  defp inserted_named(%Text{instruction: i} = text),
    do:
      brackets(%{
        text
        | instruction:
            String.replace(
              i,
              ~r/\bIn (?:sub)?(?:section|paragraph|regulation|article) \([^)]*\)/i,
              ""
            )
      })

  defp brackets(%Text{instruction: i}) do
    i
    |> String.replace(~r/[“"][^”"]*[”"]/u, "")
    |> String.replace(~r/\b(?:after|before) (?:sub)?(?:section|paragraph) \([^)]*\)/i, "")
    |> String.replace(~r/\(which becomes [^()]*\([^)]*\)\)/i, "")
    |> then(&for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, &1, capture: :all_but_first), do: b))
  end
end
