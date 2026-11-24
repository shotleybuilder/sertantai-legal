defmodule SertantaiLegal.Scraper.LawStart.Provisions.ClauseSentences do
  @moduledoc """
  The commencement provision's sentences, each split into statements and read as groups (not until, later for a purpose, by country, except which, then the sentence). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, MadeCondition, OwnDays, PurposeStages, ThatDay}

  alias SertantaiLegal.Scraper.LawStart.Provisions.{
    Countries,
    Exceptions,
    Mentioned,
    OpenItems,
    RefLists,
    Refs,
    Rest,
    Sentence,
    Words
  }

  @cif Words.cif()

  # a general clause left open for its list ("… come into force as follows—",
  # "… on the following dates—", "… come into force—")
  @open_clause ~r/into\s+(?:force|operation)\s*(?:as follows|on the following dates?)?\s*[—–:-]?\s*$/iu

  @doc "The groups of the commencement provision's own sentences."
  @spec clause_groups([map()], OwnDays.days(), String.t(), String.t(), Date.t() | nil) :: [map()]
  def clause_groups(rows, made, evidence, clause, start) do
    base = Words.provision(evidence)
    # (a head whose condition on the making day fails states nothing: "If
    # this Order is made on or after 31st December 2024—", SI 2024/1366
    # art.2(3), made on the 18th)
    held =
      rows
      |> Enum.filter(&(Words.provision(&1.section_id) == base))
      |> MadeCondition.holding(made)

    clause = RefLists.squash(clause)

    # never the sentence the law's start was read from ("they come into
    # force …", a list item "come into force …": V1-02) — but its own
    # exception, dated ("…, except regulation 20(4) which shall come into
    # operation on 6th April 2007": CV-S04)
    for row <- held,
        {s, written} <-
          row |> ThatDay.resolve(held) |> Words.sentences() |> Enum.zip(Words.sentences(row)),
        Regex.match?(@cif, s),
        not Clause.mention?(s),
        g <- sentence_statements(s, clause, row, rows, made, base, start),
        # (an item counting from "that day" is read with the day written
        # out, and keeps its words)
        do: if(g.text == s, do: %{g | text: written}, else: g)
  end

  # a sentence of statements run together is read a statement at a time
  # (`LawStart.Statements`); the law's start is still the first's
  defp sentence_statements(s, clause, row, rows, made, base, start) do
    [first | later] = Exceptions.statements(s)

    own =
      if RefLists.squash(s) == clause or RefLists.squash(first) == clause,
        do:
          s
          |> Exceptions.except_which(row, rows, made, base)
          |> Mentioned.with_mentioned_partly(s, rows, base),
        else: clause_sentence_groups(first, row, rows, made, base, start)

    own ++ Enum.flat_map(later, &clause_sentence_groups(&1, row, rows, made, base, start))
  end

  # the general clause commences the whole law; its list items, each with
  # its date ("These Regulations come into force as follows— (a) Parts 1, 2
  # … on 16th April 2005; (b) the remainder, on 16th July 2005"), are read as
  # sentences of their own (V1-02)
  @doc "One statement of the clause read as groups (not until, later for, by country, except which, then the sentence)."
  @spec clause_sentence_groups(
          String.t(),
          map(),
          [map()],
          OwnDays.days(),
          String.t(),
          Date.t() | nil
        ) :: [map()]
  def clause_sentence_groups(s, row, rows, made, base, start),
    do:
      s
      |> sentence_read(row, rows, made, base, start)
      |> Mentioned.with_mentioned_partly(s, rows, base)

  defp clause_sentence_groups(s, row, rows, made, base) do
    cond do
      Rest.whole_law?(s) and Regex.match?(@open_clause, s) ->
        items =
          for item <- Refs.dash_items(row, rows),
              not Regex.match?(@cif, item.text || ""),
              g <- OpenItems.open_item(item, rows, made, base),
              do: g

        PurposeStages.settle(items, &Refs.weighted_refs(&1.text, rows, base))

      # another general sentence in the clause than the law's start: the
      # rest of the law, dated ("Other than those regulations specified in
      # paragraph (3) these Regulations come into force on 31 October 2026"
      # beside "… come into force in accordance with paragraphs (2) and (3)":
      # SSI 2025/417 reg.1(2), CV-S04)
      Clause.general?(s) ->
        Rest.purpose_stages(s, row, rows, made, base) || Rest.general_rest(s, row, made)

      true ->
        Rest.excepted_rest(s, row, rows, made, base) ||
          Sentence.of_sentence(s, row, rows, made, base)
    end
  end

  defp sentence_read(s, row, rows, made, base, start) do
    with nil <- Exceptions.not_until(s, row, rows, made, base, start),
         nil <- Countries.later_for(s, row, made, start),
         nil <- Countries.by_application(s, row, rows, made, base),
         [] <- Exceptions.except_which(s, row, rows, made, base) do
      clause_sentence_groups(s, row, rows, made, base)
    end
  end
end
