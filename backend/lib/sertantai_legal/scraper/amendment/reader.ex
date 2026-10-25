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

  alias SertantaiLegal.Scraper.Amendment.Reader.{
    Clauses,
    LawNamed,
    RepealTable,
    Targets
  }

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

  # ── repeals tables (Reader.RepealTable) ─────────────────────────────

  @doc "The rules a repeals table (`id` in `doc`: a Schedule of repeals) states for `laws`; [] when not a table."
  defdelegate repeal_table(doc, id, laws), to: RepealTable

  @doc "True when the element is a repeals table."
  defdelegate repeal_table?(doc, id), to: RepealTable
end
