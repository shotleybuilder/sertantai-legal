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
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Clause

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i
  @remaining ~r/\b(?:remaining provisions|remainder|other provisions|all (?:other )?(?:provisions|regulations|articles|sections|rules)|provisions of this \w+(?: \([^)]*\))?,? except|preceding (?:provisions|Parts)|^\s*(?:\(\w+\)\s*)?otherwise\b|^\s*(?:\(\w+\)\s*)?(?:Subject to [^,]+,\s*)?the provisions of this)/i
  @except ~r/,?\s*\b(?:except|other than|with the exception of)\b/i
  @noun ~r/\b(sections?|regulations?|articles?|rules?)\s+((?:(?:\s*(?:,|and|to|–|-)\s*)?(?:\d+[A-Z]*(?:\([^)]+\))*|\([^)]+\)(?:\([^)]+\))*))+)/i
  @part ~r/\bParts?\s+((?:(?:\s*(?:,|and)\s*)?[0-9]+[A-Z]?|(?:\s*(?:,|and)\s*)?[IVXL]+[A-Z]?)+)\b/
  @this ~r/\bthis\s+(?:section|article|regulation|rule)\b/i
  @this_part ~r/\bthis\s+Part\b/i
  @chapter_of_part ~r/\bChapters?\s+(\w+)\s+of\s+Part\s+(\w+)\b/
  @other_law ~r/\bof\s+(?:the|that)\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,12}(?:Act|Order|Regulations|Measure)\b/

  @doc """
  The provision-level sentences of a law's commencement clause as groups,
  their references unexpanded (commencement-rules CR-03: a rule's scope):
  `kind` (`:named` | `:remaining` | `:unread`), `refs` (provisions as
  section_id prefixes; Parts and Chapters as the law's own ids, "UK_x:pt.II",
  "UK_x:pt.6.ch.1"), `excluded`, `treatment`, `date`, `qualified_date` (a
  qualified sentence's date: a partial rule's, CR-03),
  `evidence`, `text`. None for a law commenced wholly by order (its
  law-level rule covers it).
  """
  @spec groups([map()], Date.t() | nil, LawStart.t()) :: [map()]
  def groups(rows, made, %LawStart{treatment: treatment, evidence: evidence})
      when treatment != :by_order and is_binary(evidence) do
    if String.contains?(evidence, ":"),
      do:
        for(
          g <- clause_groups(rows, made, evidence),
          do: %{g | refs: Enum.map(g.refs, &elem(&1, 0))}
        ),
      else: []
  end

  def groups(_rows, _made, _law), do: []

  defp clause_groups(rows, made, evidence) do
    base = provision(evidence)
    held = rows |> Enum.filter(&(provision(&1.section_id) == base))

    for row <- held,
        s <- sentences(row),
        Regex.match?(@cif, s),
        not Clause.general?(s),
        g <- groups(s, row, rows, made, base),
        do: g
  end

  # one sentence → its groups: kind (:named | :remaining | :unread), refs,
  # excluded refs, treatment and date. A list ("The following provisions
  # come into force on …— (a) section 1; (b) section 105 in so far as …")
  # is read item by item: qualified items are their own (D2) group.
  defp groups(sentence, row, rows, made, base) do
    [subject, tail] = Regex.split(@cif, sentence, parts: 2)

    # an inline list follows "namely—" or a dash; else the rows under this one
    [tail, inline] =
      case Regex.split(~r/(?:,?\s*namely\s*)?(?:[—–]|:(?=\s))\s*/, String.trim(tail), parts: 2) do
        [t, list] -> [t, list]
        [t] -> [t, ""]
      end

    {treatment, date} = tail_treatment(tail, made)

    g = %{
      kind: :named,
      refs: [],
      excluded: [],
      treatment: treatment,
      date: date,
      qualified_date: nil,
      evidence: row.section_id,
      text: sentence
    }

    if subject =~ ~r/\bthe following\b/i do
      items =
        [inline | Enum.map(children(row, rows), &(&1.text || ""))]
        |> Enum.join("; ")
        |> String.split(~r/;\s*/, trim: true)

      {qualified, plain} = Enum.split_with(items, &Regex.match?(@qualified, &1))

      # each item's own "except …" ("Part 7 …, except regulation 73")
      {refs, excluded} =
        Enum.reduce(plain, {[], []}, fn item, {rs, ex} ->
          {inside, outside} = split_except(item)
          named = weighted_refs(inside, rows, base)

          {rs ++ named,
           ex ++
             refs(outside, rows, relative_base(named, base))}
        end)

      named = %{g | refs: refs, excluded: excluded}

      listed = %{
        g
        | refs: Enum.flat_map(qualified, &weighted_refs(&1, rows, base)),
          treatment: :provision_qualified,
          date: nil,
          qualified_date: date
      }

      # a list whose items are all qualified is only the qualified group
      [classify(named, subject <> " " <> tail), listed]
      |> Enum.reject(&(&1.treatment == :provision_qualified and &1.refs == []))
      |> Enum.reject(&(&1.kind == :unread and plain == [] and qualified != []))
    else
      {subject_in, subject_out} = split_except(subject)
      refs = weighted_refs(subject_in, rows, base)

      # "Regulation 26, with the exception of paragraph (4)": relative to
      # what the subject names
      excluded =
        refs(subject_out, rows, relative_base(refs, base))

      [classify(%{g | refs: refs, excluded: excluded}, sentence, subject)]
    end
  end

  defp classify(g, qualifiable, subject \\ "") do
    cond do
      Regex.match?(@qualified, qualifiable) ->
        %{g | treatment: :provision_qualified, date: nil, qualified_date: g.date}

      Regex.match?(@remaining, subject) and g.treatment != :provision_unread ->
        %{g | kind: :remaining}

      g.refs == [] or g.treatment == :provision_unread ->
        %{g | kind: :unread, treatment: :provision_unread, date: nil}

      true ->
        g
    end
  end

  defp tail_treatment(tail, made) do
    # "in relation to Wales on 1st October 2020": the date after the place
    # (such a sentence is qualified: a partial rule, CR-03)
    tail =
      String.replace(
        tail,
        ~r/^(?:in relation to|in|as respects)\s+(?:England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\s+(?=on\b|from\b)/i,
        ""
      )

    case Clause.tail_date(tail, made) do
      {_, %Date{} = d} ->
        {:provision_dated, d}

      _ ->
        if Clause.by_order?(tail), do: {:provision_by_order, nil}, else: {:provision_unread, nil}
    end
  end

  # what an "except …" is relative to: the first provision named, else the
  # clause's own (a Part's or Chapter's id isn't a provision: "Part 7 …,
  # except regulation 73")
  defp relative_base(named, base) do
    case named |> Enum.map(&elem(&1, 0)) |> Enum.reject(&String.contains?(&1, ":pt.")) do
      [first | _] -> first
      [] -> base
    end
  end

  defp split_except(subject) do
    case Regex.split(@except, subject, parts: 2) do
      [inside, outside] -> {inside, outside}
      [inside] -> {inside, ""}
    end
  end

  # the references a subject names, as section_id prefixes or containers
  defp refs(subject, rows, base),
    do: subject |> weighted_refs(rows, base) |> Enum.map(&elem(&1, 0))

  # each reference with its specificity: a named provision's is its length;
  # a Part's or Chapter's rows weigh 0, so a provision another sentence
  # names wins over its Part ("Part 7 …" vs "Regulation 73 … 2030")
  defp weighted_refs(subject, rows, base) do
    # another law's provisions ("section 3 of the 2022 Act") are never this
    # law's rows
    if subject =~ @other_law, do: [], else: own_refs(subject, rows, base)
  end

  # Parts and Chapters as the law's own ids ("UK_x:pt.II", "UK_x:pt.6.ch.1")
  defp own_refs(subject, rows, base) do
    law = base |> String.split(":", parts: 2) |> hd()
    prefix = base |> provision() |> String.split(".", parts: 2) |> hd()
    held = MapSet.new(rows, & &1.section_id)

    this = if Regex.match?(@this, subject), do: [provision(base)], else: []

    # "This Part": the clause's own Part
    this_part =
      with true <- Regex.match?(@this_part, subject),
           %{part: part} when is_binary(part) <-
             Enum.find(rows, &(provision(&1.section_id) == provision(base))) do
        ["#{law}:pt.#{part}"]
      else
        _ -> []
      end

    nouns =
      for [_, _noun, list] <- Regex.scan(@noun, subject),
          ref <- list_refs(list, prefix, rows),
          do: ref

    # "Chapter 1 of Part 6": that Chapter only; else a Part
    chapters =
      for [_, c, p] <- Regex.scan(@chapter_of_part, subject),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          same_part?(Map.get(r, :chapter), c),
          do: "#{law}:pt.#{r.part}.ch.#{r.chapter}"

    parts =
      for [_, list] <- Regex.scan(@part, Regex.replace(@chapter_of_part, subject, "")),
          p <- String.split(list, ~r/\s*(?:,|and)\s*/, trim: true),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          do: "#{law}:pt.#{r.part}"

    # "paragraph (4)" / "subsection (6)" alone: within the clause's provision
    relative =
      for [_, b] <-
            Regex.scan(~r/\b(?:paragraph|subsection)s?\s+(\([^)]+\)(?:\([^)]+\))*)/i, subject),
          not Regex.match?(@noun, subject),
          do: base <> b

    # a container's ids exist by construction (its rows, or theirs)
    provisions =
      (this ++ nouns ++ relative)
      |> Enum.filter(fn ref -> Enum.any?(held, &covers?(ref, &1)) end)
      |> Enum.map(&{&1, String.length(&1)})

    Enum.uniq_by(provisions ++ Enum.map(this_part ++ chapters ++ parts, &{&1, 0}), &elem(&1, 0))
  end

  # "45(4)(d) and (5)(a) and 48", "17 to 21", "3, 4, 17, 21 and 23"
  defp list_refs(list, prefix, rows) do
    tokens =
      Regex.scan(~r/(to|–|-(?=\s*\d))|(\d+[A-Z]*)((?:\([^)]+\))*)|((?:\([^)]+\))+)/, list)

    {refs, _, _} =
      Enum.reduce(tokens, {[], nil, false}, fn
        [_, range | _], {acc, last, _} when range != "" ->
          {acc, last, true}

        [_, "", n, brackets], {acc, _last, range?} ->
          ref = "#{prefix}.#{n}#{brackets}"

          acc =
            if range? and acc != [],
              do: acc ++ range_refs(List.last(acc), ref, rows),
              else: acc ++ [ref]

          {acc, n, false}

        [_, "", "", "", brackets], {acc, last, range?} when is_binary(last) ->
          {acc ++ ["#{prefix}.#{last}#{brackets}"], last, range?}

        _, state ->
          state
      end)

    refs
  end

  # the provisions from `first` to `last` in document order
  defp range_refs(first, last, rows) do
    bases = rows |> Enum.map(&provision(&1.section_id)) |> Enum.uniq()
    from = Enum.find_index(bases, &(&1 == provision(first)))
    to = Enum.find_index(bases, &(&1 == provision(last)))

    if from && to && to >= from, do: Enum.slice(bases, (from + 1)..to//1), else: [last]
  end

  defp same_part?(nil, _p), do: false

  defp same_part?(part, p) do
    up = String.upcase(p)
    part = String.upcase(part)
    part == up or part == roman(up) or roman(part) == up
  end

  @roman ~w(I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX)
  defp roman(s) do
    case Integer.parse(s) do
      {i, ""} when i in 1..20 -> Enum.at(@roman, i - 1)
      _ -> s
    end
  end

  # a reference covers itself and the rows under it
  defp covers?(ref, sid), do: sid == ref or String.starts_with?(sid, ref <> "(")

  defp children(row, rows),
    do:
      Enum.filter(
        rows,
        &(&1.section_id != row.section_id and covers?(row.section_id, &1.section_id))
      )

  defp sentences(row) do
    (Map.get(row, :text) || "")
    |> String.replace(~r/\s+/, " ")
    |> String.split(~r/(?<=\.)\s+(?=[A-Z(])/)
  end

  # "UK_x:reg.1(2)" → "UK_x:reg.1"
  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
