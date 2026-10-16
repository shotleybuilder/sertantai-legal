defmodule SertantaiLegal.Scraper.LawStart.Provisions do
  @moduledoc """
  Commencement of particular provisions (lat-refactor LR-34): the
  sentences of a law's commencement provision that commence less than the
  whole law, and the rows each one starts. Treatments:
  `LawStart.provision_catalogue/0`.

  | Sentence | Treatment | Rows |
  |---|---|---|
  | "Regulation 12 shall come into operation on 31st May 2015" | `:provision_dated` | the named provisions: they start on that date |
  | "Sections 1 and 2 come into force on such day as … may by order appoint"; "The remaining provisions of this Act come into force on such day as …"; a law commenced wholly by order | `:provision_by_order` | the named (or remaining) provisions: no law start (D1 b) |
  | "… so far as it relates to …", "in relation to Wales", "for the purposes of …" | `:provision_qualified` | listed on the named rows, no effect (D2) |
  | provisions or a date the reader can't resolve | `:provision_unread` | listed for the law, no effect |

  A row named by several sentences takes the most specific reference.
  "Remaining" / "other" provisions are the rows no sentence names, never the
  commencement provision itself (it commences with the law). References
  read: "this section", "regulations 17 to 21", "Articles 45(4)(d) and
  (5)(a) and 48", "Part II", "paragraph (4)", with "except …" / "other than
  …" subtracted; a provision noun maps to the law's own prefix (domestic SIs
  number articles as `reg.`). Schedules aren't in LAT. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Clause

  @enforce_keys [:treatment, :section_ids]
  defstruct [:treatment, :date, :evidence, :text, section_ids: []]

  @type t :: %__MODULE__{
          treatment: LawStart.provision_treatment(),
          section_ids: [String.t()],
          date: Date.t() | nil,
          evidence: String.t() | nil,
          text: String.t() | nil
        }

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:all )?other purposes)\b/i
  @remaining ~r/\b(?:remaining provisions|remainder|other provisions|all (?:other )?(?:provisions|regulations|articles|sections|rules)|provisions of this \w+(?: \([^)]*\))?,? except|preceding (?:provisions|Parts)|^\s*(?:\(\w+\)\s*)?otherwise\b|^\s*(?:\(\w+\)\s*)?(?:Subject to [^,]+,\s*)?the provisions of this)/i
  @except ~r/,?\s*\b(?:except|other than|with the exception of)\b/i
  @noun ~r/\b(sections?|regulations?|articles?|rules?)\s+((?:(?:\s*(?:,|and|to|–|-)\s*)?(?:\d+[A-Z]*(?:\([^)]+\))*|\([^)]+\)(?:\([^)]+\))*))+)/i
  @part ~r/\bParts?\s+((?:(?:\s*(?:,|and)\s*)?[0-9]+[A-Z]?|(?:\s*(?:,|and)\s*)?[IVXL]+[A-Z]?)+)\b/
  @this ~r/\bthis\s+(?:section|article|regulation|rule)\b/i
  @this_part ~r/\bthis\s+Part\b/i
  @chapter_of_part ~r/\bChapters?\s+(\w+)\s+of\s+Part\s+(\w+)\b/
  @other_law ~r/\bof\s+(?:the|that)\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){0,12}(?:Act|Order|Regulations|Measure)\b/

  @doc """
  The provision-level commencements of a law, from its rows (`section_id`,
  `text`, `part`; document order), its made date, and the law's start
  (`LawStart.resolve/1`). A law commenced wholly by order: every row is
  `:provision_by_order`.
  """
  @spec assign([map()], Date.t() | nil, LawStart.t()) :: [t()]
  def assign(rows, _made, %LawStart{treatment: :by_order} = law) do
    [
      %__MODULE__{
        treatment: :provision_by_order,
        section_ids: Enum.map(rows, & &1.section_id),
        evidence: law.evidence,
        text: law.text
      }
    ]
  end

  def assign(rows, made, %LawStart{evidence: evidence}) when is_binary(evidence) do
    if String.contains?(evidence, ":"), do: from_clause(rows, made, evidence), else: []
  end

  def assign(_rows, _made, _law), do: []

  defp from_clause(rows, made, evidence) do
    base = provision(evidence)
    held = rows |> Enum.filter(&(provision(&1.section_id) == base))

    groups =
      for row <- held,
          s <- sentences(row),
          Regex.match?(@cif, s),
          not Clause.general?(s),
          g <- groups(s, row, rows, made, base),
          do: g

    {named, remaining} = Enum.split_with(groups, &(&1.kind != :remaining))
    {qualified, named} = Enum.split_with(named, &(&1.treatment == :provision_qualified))
    assigned = assign_named(named, rows)
    taken = assigned |> Enum.flat_map(& &1.section_ids) |> MapSet.new()

    rest =
      for g <- remaining do
        excluded = MapSet.new(g.excluded)

        ids =
          for r <- rows,
              provision(r.section_id) != base,
              not MapSet.member?(taken, r.section_id),
              not Enum.any?(excluded, &covers?(&1, r.section_id)),
              do: r.section_id

        finish(g, ids)
      end

    # qualified: listed on every row they name, starting none (D2)
    listed =
      for g <- qualified,
          do:
            finish(
              g,
              for(
                r <- rows,
                Enum.any?(g.refs, fn {ref, _} -> covers?(ref, r.section_id) end),
                not Enum.any?(g.excluded, &covers?(&1, r.section_id)),
                do: r.section_id
              )
            )

    unread = for g <- named, g.kind == :unread, do: finish(g, [])

    Enum.reject(assigned ++ rest ++ listed, &(&1.section_ids == [])) ++ unread
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
           ex ++ refs(outside, rows, List.first(Enum.map(named, &elem(&1, 0)), base))}
        end)

      named = %{g | refs: refs, excluded: excluded}

      listed = %{
        g
        | refs: Enum.flat_map(qualified, &weighted_refs(&1, rows, base)),
          treatment: :provision_qualified,
          date: nil
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
      excluded = refs(subject_out, rows, List.first(Enum.map(refs, &elem(&1, 0)), base))
      [classify(%{g | refs: refs, excluded: excluded}, sentence, subject)]
    end
  end

  defp classify(g, qualifiable, subject \\ "") do
    cond do
      Regex.match?(@qualified, qualifiable) ->
        %{g | treatment: :provision_qualified, date: nil}

      Regex.match?(@remaining, subject) and g.treatment != :provision_unread ->
        %{g | kind: :remaining}

      g.refs == [] or g.treatment == :provision_unread ->
        %{g | kind: :unread, treatment: :provision_unread, date: nil}

      true ->
        g
    end
  end

  defp tail_treatment(tail, made) do
    case Clause.tail_date(tail, made) do
      {_, %Date{} = d} ->
        {:provision_dated, d}

      _ ->
        if Clause.by_order?(tail), do: {:provision_by_order, nil}, else: {:provision_unread, nil}
    end
  end

  defp split_except(subject) do
    case Regex.split(@except, subject, parts: 2) do
      [inside, outside] -> {inside, outside}
      [inside] -> {inside, ""}
    end
  end

  # each row to the group naming it most specifically (the longest
  # reference); qualified groups list their rows but start none
  defp assign_named(groups, rows) do
    named = Enum.filter(groups, &(&1.kind == :named))

    winners =
      for r <- rows,
          best =
            named
            |> Enum.flat_map(fn g ->
              for {ref, weight} <- g.refs,
                  covers?(ref, r.section_id),
                  not Enum.any?(g.excluded, &covers?(&1, r.section_id)),
                  do: {weight, g}
            end)
            |> Enum.max_by(&elem(&1, 0), fn -> nil end),
          best != nil,
          reduce: %{} do
        acc -> Map.update(acc, elem(best, 1), [r.section_id], &[r.section_id | &1])
      end

    for g <- named, ids = Map.get(winners, g, []), ids != [], do: finish(g, Enum.reverse(ids))
  end

  defp finish(g, ids),
    do: %__MODULE__{
      treatment: g.treatment,
      date: g.date,
      evidence: g.evidence,
      text: g.text,
      section_ids: Enum.uniq(ids)
    }

  @doc """
  The references a subject names, as section_id prefixes of the law's rows
  ("UK_x:reg.45(4)(d)", "UK_x:reg.48"); a Part gives its rows' ids.
  """
  @spec refs(String.t(), [map()], String.t()) :: [String.t()]
  def refs(subject, rows, base),
    do: subject |> weighted_refs(rows, base) |> Enum.map(&elem(&1, 0))

  # each reference with its specificity: a named provision's is its length;
  # a Part's or Chapter's rows weigh 0, so a provision another sentence
  # names wins over its Part ("Part 7 …" vs "Regulation 73 … 2030")
  defp weighted_refs(subject, rows, base) do
    # another law's provisions ("section 3 of the 2022 Act") are never this
    # law's rows
    if subject =~ @other_law, do: [], else: own_refs(subject, rows, base)
  end

  defp own_refs(subject, rows, base) do
    prefix = base |> provision() |> String.split(".", parts: 2) |> hd()
    held = MapSet.new(rows, & &1.section_id)

    this = if Regex.match?(@this, subject), do: [provision(base)], else: []

    # "This Part": the rows of the clause's own Part
    this_part =
      with true <- Regex.match?(@this_part, subject),
           %{part: part} when is_binary(part) <-
             Enum.find(rows, &(provision(&1.section_id) == provision(base))) do
        for r <- rows, Map.get(r, :part) == part, do: r.section_id
      else
        _ -> []
      end

    nouns =
      for [_, _noun, list] <- Regex.scan(@noun, subject),
          ref <- list_refs(list, prefix, rows),
          do: ref

    # "Chapter 1 of Part 6": that Chapter's rows only; else a Part's rows
    chapters =
      for [_, c, p] <- Regex.scan(@chapter_of_part, subject),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          same_part?(Map.get(r, :chapter), c),
          do: r.section_id

    parts =
      for [_, list] <- Regex.scan(@part, Regex.replace(@chapter_of_part, subject, "")),
          p <- String.split(list, ~r/\s*(?:,|and)\s*/, trim: true),
          r <- rows,
          same_part?(Map.get(r, :part), p),
          do: r.section_id

    # "paragraph (4)" / "subsection (6)" alone: within the clause's provision
    relative =
      for [_, b] <-
            Regex.scan(~r/\b(?:paragraph|subsection)s?\s+(\([^)]+\)(?:\([^)]+\))*)/i, subject),
          not Regex.match?(@noun, subject),
          do: base <> b

    (Enum.map(this ++ nouns ++ relative, &{&1, String.length(&1)}) ++
       Enum.map(this_part ++ chapters ++ parts, &{&1, 0}))
    |> Enum.uniq_by(&elem(&1, 0))
    |> Enum.filter(fn {ref, _} -> Enum.any?(held, &covers?(ref, &1)) end)
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
