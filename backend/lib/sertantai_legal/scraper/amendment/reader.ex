defmodule SertantaiLegal.Scraper.Amendment.Reader do
  @moduledoc """
  An amending provision read once into amendment rules (amendment-rules
  AR-03), for the laws its notes point to (`laws`: one hop from our rows) —
  the row-driven `AmendingLaw.Target` / `RepealTable` turned round: the
  targets they would accept, expanded at read time.

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
  commencement ruleset's. `AmendingLaw.Target` / `RepealTable` are deleted
  at the switch-over (AR-04): this module copies the matching it needs
  (they're LabelVersion inputs). Pure.
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

  @doc "The rules an instruction (`id` in `doc`) states for `laws`."
  @spec instruction(Doc.t(), String.t(), map(), [law_ref()]) :: [Rule.t()]
  def instruction(doc, id, terms, laws) do
    with %Text{} = text <- Text.of(doc, id),
         {_, _} = op <- Operation.of(text) do
      title = Doc.title(doc, id)
      texts = Enum.map([text.instruction | Enum.reverse(text.context)], &unquote_words/1)
      before = Stream.map(text.before, &unquote_words/1)
      source = %{law: doc.law_name, ref: id, text: text.instruction}

      for law <- laws,
          law?(Stream.concat(texts ++ List.wrap(title), before), terms, law),
          rule <- rules(text, texts, op, law, source),
          do: rule
    else
      _ -> []
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
      rule(law, Enum.uniq(quoted), Operation.of_quoted(text), source),
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
  defp ref(p, [n | subs]), do: "#{p}.#{n}" <> Enum.map_join(subs, &"(#{&1})")

  # every in-order combination of the brackets named (rows whose brackets
  # are all named: "subsection (5), paragraphs (b) and (c)" → (5), (5)(b),
  # (5)(c), (b), …); at most six brackets
  defp combos(named) do
    named
    |> Enum.take(6)
    |> Enum.reduce([[]], fn b, acc -> acc ++ Enum.map(acc, &(&1 ++ [b])) end)
    |> Enum.reject(&(&1 == []))
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
          rest =~ ~r/\bwords?\b/ -> {[ref("s", [n | subs])], :words}
          true -> whole_targets(n, subs ++ plain_brackets(rest))
        end

      _ ->
        nil
    end
  end

  defp whole_targets(n, []), do: {["s.#{n}"], :provision}
  defp whole_targets(n, named), do: {for(c <- combos(named), do: ref("s", [n | c])), :provision}

  defp plain_brackets(s),
    do: for([b] <- Regex.scan(~r/\(([0-9A-Za-z]+)\)/, s, capture: :all_but_first), do: b)

  # ── the law named (as `AmendingLaw.Target`, LR-41) ─────────────────

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

  # ── provisions named (as `AmendingLaw.Target`) ────────────────────

  defp numbers(texts, kind) do
    re = ~r/\b#{@kind_words[kind]} (\d+[A-Z]*)(?:(?:,| and| or| to) (\d+[A-Z]*))*/u

    Enum.find_value(texts, :none, fn t ->
      case Regex.scan(re, t) do
        [] ->
          nil

        found ->
          {:ok,
           found
           |> List.flatten()
           |> Enum.flat_map(&Regex.scan(~r/\d+[A-Z]*/, &1))
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
