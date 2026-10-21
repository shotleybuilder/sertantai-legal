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

  # a bracket is a number, a letter or two, or a roman numeral — never a
  # word ("(interpretation)": a one-word caption, AR-07)
  @bracket ~r/^(?:\d+[A-Z]*|[a-z]{1,3}|[A-Z]{1,2}|(?:x{0,3})(?:ix|iv|v?i{0,3}))$/

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
      {_, _} ->
        texts = Enum.map([text.instruction | Enum.reverse(text.context)], &unquote_words/1)
        before = Stream.map(text.before, &unquote_words/1)

        for law <- laws,
            law?(Stream.concat(texts ++ List.wrap(title), before), terms, law),
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
    clauses = text |> clauses() |> scoped(texts, law, terms)
    quoting = quoting_clause(clauses)

    quoted =
      case quoting do
        nil -> nil
        c -> rule(law, quoted_targets(c, p), Operation.of_quoted(captionless(c.text)), source)
      end

    named =
      for c <- clauses,
          op = operation(c.text),
          op != nil,
          # an insertion reaches only what it quotes or names as inserted
          targets =
            for(
              n <- c.numbers,
              n not in tops,
              t <- named_refs(c.text, op, p, n, c.named),
              uniq: true,
              do: t
            ),
          do: rule(law, targets, op, source)

    Enum.reject([quoted | named], &is_nil/1)
  end

  defp quoted_targets(%{text: text, named: named, numbers: numbers}, p) do
    if sections_quoted?(text) do
      # "For section 99 substitute— 99 …", "After section 47B insert— 47C":
      # the quote's numbers are sections, never nested in one (AR-07)
      for path <- text.inserted, provision_path?(path), uniq: true, do: ref(p, path)
    else
      for path <- text.inserted,
          t <- quoted_paths(path, named, numbers, p),
          uniq: true,
          do: t
    end
  end

  # a quoted path's targets:
  # - a provision of its own when no provision is named to hold it, or its
  #   number grows from one named ("After that section insert— 52A": s.52A;
  #   "In section 142, after subsection (1) insert— (1A)": never s.1A)
  # - else under the brackets named at levels above its own ("In section
  #   7(1) for paragraph (b) substitute— (b) (c)": s.7(1)(c); "for
  #   subsection (5) substitute— (4A) (5)": s.52(4A), never s.52(5)(4A))
  # - a quoted "(i)" may be a sub-paragraph under the last bracket's parent
  #   ("In section 7(5)(b) for sub-paragraph (i) substitute— (i)":
  #   s.7(5)(b)(i)) — a letter or a numeral
  defp quoted_paths(path, named, numbers, p) do
    own? = provision_path?(path) and (numbers == [] or own_number?(hd(path), numbers))

    if own? do
      [ref(p, path)]
    else
      for(n <- numbers, do: ref(p, [n | above(named, [hd(path)]) ++ path])) ++
        for(
          n <- numbers,
          length(named) > 1,
          hd(path) =~ ~r/^[ivx]+[a-z]?$/,
          do: ref(p, [n | Enum.drop(named, -1) ++ path])
        )
    end
  end

  # the clause whose quote follows ("… and after that subsection insert—"),
  # else the first quoting one; "at the end there shall be added—" quotes
  # too (RTA 1991 s.18(1), AR-10)
  defp quoting_clause(clauses) do
    quoting = Enum.filter(clauses, &(&1.text.instruction =~ ~r/insert|substitut|\badded\b/i))

    Enum.find(quoting, List.first(quoting), fn c ->
      captionless(c.text).instruction =~ ~r/[—–:]\s*[;.,]?\s*$/u
    end)
  end

  # each clause with its brackets and numbers: a clause naming none takes
  # its predecessor's numbers, and the first clause's place ("in subsection
  # (1), paragraph (b) is omitted and in paragraph (c) …" → (1)(c)) at the
  # levels above its own; a clause naming another law is that law's
  defp scoped(clauses, texts, law, terms) do
    [first | _] = clauses
    place = located_brackets(first.instruction)
    context = tl(texts)

    {scoped, _} =
      Enum.map_reduce(clauses, {nil, true}, fn c, {prev, ours?} ->
        # captions and quotes aside: a law named there is not the clause's
        unquoted = c.instruction |> asides() |> unquote_words() |> own_part(law, terms)

        ours? =
          case laws(unquoted, terms) do
            [] -> ours?
            refs -> Enum.any?(refs, &law_named?(&1, law))
          end

        numbers =
          case {numbers([unquoted], law.kind), prev} do
            {{:ok, ns}, _} -> ns
            {:none, nil} -> with({:ok, ns} <- numbers(context, law.kind), do: ns, else: (_ -> []))
            {:none, ns} -> ns
          end

        own =
          brackets(%{c | instruction: own_part(unquote_words(asides(c.instruction)), law, terms)})

        named = if c == first, do: own, else: above(place, own) ++ own
        {%{text: c, named: named, numbers: numbers, ours?: ours?}, {numbers, ours?}}
      end)

    Enum.filter(scoped, & &1.ours?)
  end

  # the text without its captions, a title's own brackets kept ("Planning
  # (Listed Buildings and Conservation Areas) Act 1990")
  defp asides(s) do
    ~r/[“"][^”"]*[”"]|\((?:[^()“”"]|[“"][^”"]*[”"])*\)(?!\s*(?:Act|Regulations|Order|Rules|\d{4})\b)/u
    |> Regex.replace(s, fn m -> if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: "" end)
  end

  # a clause naming two laws ("Section 7 of the PPVA 1981 and section
  # 68(1) and (2) of the RTA 1988 shall cease to have effect"): the law's
  # part is the text up to its name from the name before
  defp own_part(t, law, terms) do
    spans = law_spans(t, terms)
    ours = Enum.map(spans, fn {_, _, r} -> law_named?(r, law) end)

    if Enum.any?(ours) and not Enum.all?(ours) do
      # the last law named has the rest of the text ("… of the RTA 1988
      # (…) shall cease to have effect")
      last = length(spans) - 1

      spans
      |> Enum.with_index()
      |> Enum.reduce({0, []}, fn {{_, b, r}, k}, {from, acc} ->
        stop = if k == last, do: byte_size(t), else: b
        {b, if(law_named?(r, law), do: [binary_part(t, from, stop - from) | acc], else: acc)}
      end)
      |> elem(1)
      |> Enum.reverse()
      |> Enum.join(" ")
    else
      t
    end
  end

  # each law named, with its place in the text
  defp law_spans(t, terms) do
    lower = String.downcase(t)

    defined =
      for {term, law} <- terms,
          law.law != nil or law.title != nil,
          [{a, len}] <-
            Regex.scan(~r/(?<![\w])#{Regex.escape(term)}(?![\w])/u, lower, return: :index),
          do: {a, a + len, law}

    titled =
      for [{a, len}] <-
            Regex.scan(
              ~r/[A-Z][\w,'’()\- ]*? (?:Act|Regulations|Order|Rules)(?: \(Northern Ireland\))? \d{4}/u,
              t,
              return: :index
            ),
          do: {a, a + len, %{law: nil, title: binary_part(t, a, len)}}

    chapters =
      for [{a, len}, {ya, yl}, {na, nl}] <-
            Regex.scan(~r/\b(\d{4}) c\. (\d+)/, t, return: :index),
          do: {a, a + len, %{law: nil, chapter: {binary_part(t, ya, yl), binary_part(t, na, nl)}}}

    # a name inside another ("land" in "Land Compensation Act 1973") is
    # part of it
    (defined ++ titled ++ chapters)
    |> Enum.sort()
    |> Enum.reduce([], fn
      {_, b, _}, [{_, pb, _} | _] = acc when b <= pb -> acc
      span, acc -> [span | acc]
    end)
    |> Enum.reverse()
  end

  # the place's brackets at levels above the clause's own
  defp above(place, []), do: place

  defp above(place, own) do
    top = own |> Enum.map(&bracket_level/1) |> Enum.min()
    Enum.filter(place, &(bracket_level(&1) < top))
  end

  defp bracket_level(b) do
    cond do
      b =~ ~r/^\d/ -> 0
      b =~ ~r/^[A-Z]+$/ -> 3
      b =~ ~r/^(?:ii|iii|iv|vi{1,3}|ix|xi{1,3})$/ -> 2
      true -> 1
    end
  end

  # "in subsection (1)", "In section 7(1)(a)": where the clause is
  @place ~r/\bin\s+(?:sub-?)?(?:sections?|paragraphs?|sub-?paragraphs?|regulations?|articles?|rules?)\s+(?:\d+[A-Z]*\s*)?((?:\([0-9A-Za-z]+\))+)/i

  defp located_brackets(i) do
    i
    |> strip_captions()
    |> unquote_words()
    |> then(&Regex.scan(@place, &1, capture: :all_but_first))
    |> Enum.flat_map(&plain_brackets(hd(&1)))
    |> Enum.filter(&(&1 =~ @bracket))
  end

  # the instruction's clauses, one per operation: split at "and" or ";"
  # outside quotes and captions, a piece with no verb joined to the next
  # ("Sections 4 and 5 are repealed") or, last, to the one before
  defp clauses(%Text{instruction: i} = text) do
    masked =
      Regex.replace(
        ~r/[“"][^”"]*[”"]|\((?:[^()“”"]|[“"][^”"]*[”"])*\)/u,
        i,
        &String.duplicate("x", byte_size(&1))
      )

    cuts =
      for [{pos, len}] <- Regex.scan(~r/;\s*|,?\s+and\s+/, masked, return: :index),
          do: pos + len

    pieces =
      [0 | cuts]
      |> Enum.zip(cuts ++ [byte_size(i)])
      |> Enum.map(fn {a, b} -> {binary_part(i, a, b - a), binary_part(masked, a, b - a)} end)

    pieces
    |> Enum.reduce([], fn {piece, m}, acc ->
      case acc do
        [{open, om, false} | rest] -> [{open <> piece, om <> m, verb?(om <> m)} | rest]
        _ -> [{piece, m, verb?(m)} | acc]
      end
    end)
    |> then(fn
      [{last, _, false}, {prev, pm, _} | rest] -> [{prev <> last, pm, true} | rest]
      acc -> acc
    end)
    |> Enum.reverse()
    |> Enum.map(fn {piece, _, _} -> %{text | instruction: String.trim(piece)} end)
    |> case do
      [_] -> [text]
      cs -> cs
    end
  end

  defp verb?(masked), do: Operation.of(%Text{id: nil, instruction: masked}) != nil

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
            whole_targets(n, subs ++ plain_brackets(rest))
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
        {[subs, Enum.drop(subs, -1) ++ plain_brackets(bs)], after_siblings}

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
    do: for([_, bs] <- Regex.scan(@located, unquote_words(rest)), do: plain_brackets(bs))

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
            [bs] -> bs |> plain_brackets() |> then(&(above(place, &1) ++ &1))
            nil -> place
          end

        bare = m |> String.replace(@located, "") |> String.replace(~r/^[\s.]+|[\s.]+$/, "")

        cond do
          bare =~ ~r/\bwords?\b|\bdefinitions?\b|\bentr(?:y|ies)\b|\bonwards\b|\bto the end\b/i or
              piece =~ ~r/[“"][^”"]*[”"]/u ->
            # "the words “…” in paragraph (b) and paragraph (c)": (c) is
            # another place for the words, not a provision repealed (a
            # provision of another level is: "… and subsection (12)")
            {[{ref("s", [n | subs ++ place]), :words}],
             {place, if(m =~ @located_end, do: place |> List.last() |> bracket_level())}}

          named = Regex.run(@named_provision, bare, capture: :all_but_first) ->
            {for(
               bs <- provisions(named),
               level = if(bracket_level(hd(bs)) == trailing, do: :words, else: :provision),
               do: {ref("s", [n | subs ++ above(place, bs) ++ bs]), level}
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
  defp provisions([g, ""]), do: [plain_brackets(g)]
  defp provisions([g]), do: [plain_brackets(g)]

  defp provisions([g, to]) do
    case {plain_brackets(g), plain_brackets(to)} do
      {[a], [b]} ->
        if a =~ ~r/^\d+$/ and b =~ ~r/^\d+$/ and String.to_integer(a) < String.to_integer(b),
          do: for(k <- String.to_integer(a)..String.to_integer(b), do: ["#{k}"]),
          else: [[a], [b]]

      {as, bs} ->
        [as, bs]
    end
  end

  defp words_targets(n, subs, []), do: [ref("s", [n | subs])]
  defp words_targets(n, subs, places), do: for(p <- places, do: ref("s", [n | subs ++ p]))

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
    # "The Electricity Safety Regulations 2014": a title's year, never
    # regulation 2014 (sections do run past 999: Companies Act 2006 s.1300)
    year = if kind == :section, do: "", else: "(?!\\d{4}\\b)"
    re = ~r/\b(?i:#{@kind_words[kind]}) #{year}(\d+[A-Z]*)(?:(?:,| and| or| to) (\d+[A-Z]*))*/u

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

  # the whole section is the thing substituted or inserted ("For section 7",
  # "after section 47B", "substituted for section 18"; not "for section
  # 7(2)", not "for subsection (2)")
  defp sections_quoted?(%Text{} = text),
    do:
      captionless(text).instruction =~
        ~r/\b(?:for|after|before)\s+(?:the\s+)?(?:sections?|regulations?|articles?|rules?)\s+\d+[A-Z]*\b(?!\s*\((?:\d+[A-Z]*|[a-z]{1,3})\))/i

  defp provision_path?([top | _]), do: top =~ ~r/^\d/

  # a number grown from a provision named ("52A" from section 52, "2C" from
  # regulation 2B)
  defp own_number?(top, numbers) do
    case Regex.run(~r/^(\d+)[A-Z]+$/, top) do
      [_, stem] -> Enum.any?(numbers, &(&1 =~ ~r/^#{stem}(?:[A-Z]+)?$/))
      nil -> false
    end
  end

  defp brackets(%Text{instruction: i}) do
    i
    |> String.replace(~r/[“"][^”"]*[”"]/u, "")
    # "after paragraph (2)(b)": the anchor is a sibling, its parent the place
    |> String.replace(
      ~r/\b(?:after|before) (?:sub-?)?(?:section|paragraph) ((?:\([^)]*\))+)/i,
      fn m ->
        m
        |> then(&Regex.scan(~r/\([^)]*\)/, &1))
        |> List.flatten()
        |> Enum.drop(-1)
        |> Enum.join()
      end
    )
    |> String.replace(~r/\(which becomes [^()]*\([^)]*\)\)/i, "")
    |> then(&for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, &1, capture: :all_but_first), do: b))
    |> Enum.filter(&(&1 =~ @bracket))
  end
end
