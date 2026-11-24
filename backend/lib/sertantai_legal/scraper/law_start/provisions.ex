defmodule SertantaiLegal.Scraper.LawStart.Provisions do
  @moduledoc """
  The sentences of a law's commencement provision that commence less than
  the whole law (lat-refactor LR-34), read as groups for the commencement
  ruleset (commencement-rules CR-03: `Commencement.OwnClause` writes each
  as a rule; CR-06: the evaluator, not this module, decides which rows each
  reaches). Treatments: `LawStart.provision_catalogue/0`.

  | Sentence | Treatment |
  |---|---|
  | "Regulation 12 shall come into operation on 31st May 2015" | `:provision_dated` |
  | "Sections 1 and 2 come into force on such day as … may by order appoint"; "The remaining provisions of this Act come into force on such day as …" | `:provision_by_order` |
  | "… so far as it relates to …", "in relation to Wales", "for the purposes of …" | `:provision_qualified` (a partial rule) |
  | provisions or a date the reader can't resolve | `:provision_unread` |

  "Remaining" / "other" provisions are those no sentence names, never the
  commencement provision itself (it commences with the law). References
  read: "this section", "regulations 17 to 21", "Articles 45(4)(d) and
  (5)(a) and 48", "Part II", "paragraph (4)", with "except …" / "other than
  …" subtracted; a provision noun maps to the law's own prefix (domestic SIs
  number articles as `reg.`). Schedules aren't in LAT. Pure.

  The words are read by: `LawStart.Statements` (several statements in one
  sentence), `LawStart.ListItems` (a list's items, each with its own
  exception and qualifier), `LawStart.Territorial` (a commencement country
  by country) and `LawStart.NumberWords` (numbers written in words).
  """
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{Clause, Completing}

  alias SertantaiLegal.Scraper.LawStart.Provisions.{
    ClauseSentences,
    Exceptions,
    Mentioned,
    Refs,
    Tables,
    Words
  }

  @cif Words.cif()

  # a statement elsewhere names provisions first, never something under them
  # ("… a partial restriction notice served under section 183 above by a
  # notice … which shall come into force": Building Societies Act 1986
  # s.186(1))
  @provisions_subject ~r/^(?:\(\w+\)\s*)?(?:(?:Subject\s+to|Except|Apart\s+from|Other\s+than|Save|In\s+(?:Part|Schedule)\s+\w+)[^,]{0,200},\s*)?(?:the\s+)?(?:sections?|regulations?|articles?|rules?|paragraphs?|sub-?sections?|sub-?paragraphs?|Parts?|Chapters?|Schedules?|this|these|following|remaining|preceding|other|rest|provisions?|repeals?|amendments?)\b/i

  @this_only ~r/^(?:\(\w+\)\s*)?This\s+(?:section|regulation|article|rule)\s+(?:shall\s+)?(?:comes?|came)\s+into/i

  @doc """
  The provision-level sentences of a law's commencement clause as groups,
  their references unexpanded (commencement-rules CR-03: a rule's scope):
  `kind` (`:named` | `:remaining` | `:unread`), `refs` (provisions as
  section_id prefixes; Parts and Chapters as the law's own ids, "UK_x:pt.II",
  "UK_x:pt.6.ch.1"), `excluded`, `treatment`, `date`, `qualified_date` (a
  qualified sentence's date: a partial rule's, CR-03),
  `evidence`, `text`.
  """
  @spec groups([map()], SertantaiLegal.Scraper.LawStart.OwnDays.days(), LawStart.t()) :: [map()]
  def groups(written, made, %LawStart{} = law) do
    clause = if clause?(law), do: Words.provision(law.evidence)
    # read without their completing words ("(so far as not in force by
    # virtue of subsection (2))": `LawStart.Completing`), which limit nothing
    rows = Enum.map(written, &Completing.row/1)
    start = law |> whole_clause() |> Completing.drop()

    # a law left to orders reads its clause's other sentences too ("Subject
    # to subsections (2) and (3), this Act is to come into force on such day
    # as …": LGRA 1997 s.34, CV-S04)
    clause_groups =
      if clause,
        do: ClauseSentences.clause_groups(rows, made, law.evidence, start, law.date),
        else: []

    words = as_written(written)

    for g <- clause_groups ++ elsewhere(rows, made, clause, law.date) do
      %{g | refs: Enum.map(g.refs, &elem(&1, 0)), text: Map.get(words, g.text, g.text)}
    end
  end

  # each sentence read without its completing words, to the words written
  defp as_written(rows) do
    for row <- rows,
        s <- Words.sentences(row),
        read = Completing.drop(s),
        read != s,
        into: %{},
        do: {read, s}
  end

  defp clause?(%LawStart{evidence: e}), do: is_binary(e) and String.contains?(e, ":")

  @doc false
  def first_group(re, text) do
    case Regex.run(re, text) do
      [_, w | _] -> w
      nil -> nil
    end
  end

  # statements in other provisions ("Section 6 and Schedules 2 and 3 shall
  # not come into force until such day as …": Access to Justice Act 1999
  # s.7(3); "Part 1 … comes into force in accordance with provision made by
  # order": NERC Act 2006 s.107(1)), each read in its own provision: never a
  # mention, another law's provisions, a general clause (the law's start is
  # LawStart's) or "this section" alone (OwnClause reads a provision's own
  # words) — CV-S04
  defp elsewhere(rows, made, clause, start) do
    for row <- rows,
        Words.provision(row.section_id) != clause,
        s <- Enum.flat_map(Words.sentences(row), &Exceptions.statements/1),
        Regex.match?(@cif, s),
        not Clause.mention?(s),
        not Clause.general?(s),
        Regex.match?(@provisions_subject, s),
        not Regex.match?(@this_only, s),
        g <-
          ClauseSentences.clause_sentence_groups(
            s,
            row,
            rows,
            made,
            Words.provision(row.section_id),
            start
          ),
        g.kind != :unread,
        do: g
  end

  # the law's start read from one sentence for the whole law (a dated
  # clause, a pronoun or a list item: V1-02) — a staged or own-part clause
  # is also a provision sentence
  defp whole_clause(%LawStart{treatment: t, text: text})
       when t not in [:clause_staged, :clause_unread],
       do: text

  defp whole_clause(_law), do: nil

  @doc """
  Whether `sentence` heads a list of another law's provisions ("The
  following provisions of the 2014 Act come into force on …—": a
  commencement order's, SI 2017/58 art.2), which states nothing of the
  law's own commencement.
  """
  @spec other_law_list?(String.t()) :: boolean()
  defdelegate other_law_list?(sentence), to: Exceptions

  @doc """
  The provisions a general clause leaves out — inline ("This Act, apart
  from sections 7 and 8 and this section, shall come into force …": Police
  (Health and Safety) Act 1997 s.9(2); with brackets inside, "except Parts
  1, 2 and 3 and section 26(2)": nia 2016/13 s.27(1); "(apart from this
  section and paragraph 6(2) and (5) of Schedule 5)": 1999 c.28 s.43(2)) or in a list below it ("This Act,
  except— (a) this section; (b) sections 8(2), 11(1) to (5), 12 and 13; …":
  Gas Act 1995 s.18(2)) — as refs (CV-S04 round 3). [] for none.
  """
  @spec except_refs(LawStart.t(), [map()]) :: [String.t()]
  defdelegate except_refs(law, rows), to: Exceptions

  @doc """
  The provisions a general clause leaves out only so far: those the list
  it points to names with a limit of their own ("… the provisions
  specified in subsection (6) below (which come into force on the passing
  of this Act) …", the list ending "and subsection (8) of section 67 so
  far as it relates to that Part of that Schedule": 1994 c.21 s.68(4),
  (6)(f)) — as refs. [] for none.
  """
  @spec except_partly(LawStart.t(), [map()]) :: [String.t()]
  defdelegate except_partly(law, rows), to: Exceptions

  @doc """
  The groups of a clause commencing by its Schedule's table (V1-02,
  `LawStart.ScheduleTable`): one per table row, its provisions dated in
  full when its purpose is all ("All purposes", "In respect of all
  buildings") and the provision carries no qualifier of its own ("Regulation
  17 (for the purpose of new regulation 25A)"); else partial.
  """
  @spec table_groups([map()], LawStart.t(), map() | nil) :: [map()]
  defdelegate table_groups(rows, law, tables), to: Tables

  @doc """
  The law's own provisions `text` names, bare ("reg.7", "pt.II"), as this
  reader names them over `rows` from the provision `base` — for checks that
  must name refs the same way (`Commencement.Leftovers`).
  """
  @spec refs_in(String.t(), [map()], String.t()) :: [String.t()]
  defdelegate refs_in(text, rows, base), to: Refs

  @doc """
  A Schedule's Part (and paragraph) named after the Schedule written Part
  first: "schedule 7, Part 1, paragraph 6(c)" → "paragraph 6(c) of Part 1
  of Schedule 7" (SI 2013/3113 reg.1(4)), so no reader takes the Part for
  the law's own. Pure.
  """
  @spec schedule_part_first(String.t()) :: String.t()
  defdelegate schedule_part_first(subject), to: Mentioned
end
