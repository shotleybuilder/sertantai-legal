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

  alias SertantaiLegal.Scraper.Amendment.Rule

  alias SertantaiLegal.Scraper.Amendment.Reader.{
    Clauses,
    LawNamed,
    RepealTable,
    Scope,
    Targets
  }

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Operation, ScheduleRefs, Text}

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

  @doc "Each Schedule's introducing section (`AmendingLaw.ScheduleRefs.references/1`)."
  @spec references(Doc.t()) :: %{String.t() => String.t()}
  defdelegate references(doc), to: ScheduleRefs

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

  @doc "The provision giving effect to a Schedule (`AmendingLaw.ScheduleRefs.reference/2`)."
  @spec reference(Doc.t(), String.t()) :: String.t() | nil
  defdelegate reference(doc, id), to: ScheduleRefs

  @doc "The rules an instruction (`id` in `doc`) states for `laws`."
  @spec instruction(Doc.t(), String.t(), map(), [law_ref()]) :: [Rule.t()]
  def instruction(doc, id, terms, laws) do
    case Text.of(doc, id) do
      %Text{} = text ->
        text
        |> set_out(doc)
        |> of_text(Doc.title(doc, id), terms, Scope.laws(doc, id, text, terms, laws), %{
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
        set_out_beside(text, doc)
    end
  end

  defp set_out(text, _doc), do: text

  # "after subsection (2) insert the subsection set out in sub-paragraph
  # (2)": the block is in that sub-paragraph of the same provision (2005
  # c.14 Sch.3 para 3(1)(b); "(2)" had read as the subsection inserted —
  # CV-S06 B4)
  defp set_out_beside(%Text{id: id, instruction: i} = text, doc) when is_binary(id) do
    with [phrase, n] <-
           Regex.run(~r/\bset\s+out\s+in\s+(?:sub-?paragraph|subsection)\s+\((\w+)\)/iu, i),
         [_, top] <-
           Regex.run(
             ~r/^(schedule-[^-]+-paragraph-[^-]+|(?:section|regulation|article|rule)-[^-]+)/,
             id
           ),
         %Text{inserted: [_ | _] = paths} <- Text.of(doc, "#{top}-#{n}") do
      %{text | inserted: paths, instruction: String.replace(i, phrase, "set out")}
    else
      _ -> text
    end
  end

  defp set_out_beside(text, _doc), do: text

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
        # 2026-10-25: found per law, 24× over for ukpga 1995/25); a caption
        # describes a provision, never names the law amended ("In section 1
        # (application of Part I of Health and Safety at Work etc. Act 1974
        # …)" under "The Offshore Safety Act 1992 shall be amended":
        # Petroleum Act 1998 Sch. 4 para 33)
        uncaptioned = Enum.map(texts, &Clauses.uncaptioned/1)
        named = LawNamed.named(Stream.concat(uncaptioned ++ List.wrap(title), before), terms)

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

        # the provisions a quote makes are one tree, its top the change
        # (`:quoted`); a named provision's brackets are readings of one
        # place (CV-S06 B5)
        c ->
          case Targets.rule(
                 law,
                 Targets.quoted_targets(c, p),
                 Operation.of_quoted(Clauses.captionless(c.text)),
                 source
               ) do
            nil ->
              nil

            # a quote numbering provisions makes them whole ("for “.”
            # substitute— (m) …; (n) …": CV-S06 B7) — not a definition's
            # own lettered paragraphs, which are words in the provision
            # defining ("after the definition of “x” insert— “y” means (a) …")
            r ->
              whole? = c.text.inserted != [] and not (c.text.instruction =~ ~r/\bdefinitions?\b/i)
              %{r | treatment: :quoted, level: if(whole?, do: :provision, else: r.level)}
          end
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

  # ── repeals tables (Reader.RepealTable) ─────────────────────────────

  @doc "The rules a repeals table (`id` in `doc`: a Schedule of repeals) states for `laws`; [] when not a table."
  defdelegate repeal_table(doc, id, laws), to: RepealTable

  @doc "True when the element is a repeals table."
  defdelegate repeal_table?(doc, id), to: RepealTable
end
