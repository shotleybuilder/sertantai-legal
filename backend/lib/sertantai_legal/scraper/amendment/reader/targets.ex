defmodule SertantaiLegal.Scraper.Amendment.Reader.Targets do
  @moduledoc """
  An amending clause's targets (AR-03, AR-07; decomposed from
  `Amendment.Reader`, run time 2026-10-25): the provision numbers and
  brackets it names, the provisions its quote inserts or substitutes, and
  the rule they make. Pure; calls `Reader.Brackets` and `Reader.Clauses`
  only.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.Amendment.Reader.{Brackets, Clauses}

  @typedoc "A clause as the reader scopes it (`Reader.LawNamed.scoped/4`): its text, brackets, numbers, and more."
  @type clause :: %{
          required(:text) => Text.t(),
          optional(:named) => [String.t()],
          optional(:numbers) => [String.t()],
          optional(atom()) => term()
        }

  @kind_words %{
    section: "sections?",
    regulation: "regulations?",
    article: "articles?",
    order: "articles?",
    rule: "rules?"
  }
  @doc """
  The targets of a clause's quoted provisions (`text.inserted`) under its
  brackets (`named`) and provision numbers.
  """
  @spec quoted_targets(clause(), String.t()) :: [String.t()]
  def quoted_targets(%{text: text, named: named, numbers: numbers}, p) do
    cond do
      # "For regulation 10 there shall be substituted— (1) … (2)(a) …": the
      # quote is the one provision named, from its paragraphs (SI 2000/1335
      # reg.16, read as regs.1–8: Maritime Safety 2026-11-06)
      body?(text, numbers) ->
        for path <- text.inserted, uniq: true, do: Brackets.ref(p, [hd(numbers) | path])

      # "For section 99 substitute— 99 …", "After section 47B insert— 47C":
      # the quote's numbers are sections, never nested in one (AR-07)
      sections_quoted?(text) ->
        for path <- text.inserted, provision_path?(path), uniq: true, do: Brackets.ref(p, path)

      true ->
        quoted_targets(text, named, numbers, p)
    end
  end

  defp quoted_targets(text, named, numbers, p) do
    for path <- text.inserted,
        t <- quoted_paths(path, named, numbers, p),
        uniq: true,
        do: t
  end

  # a substitution of one whole provision whose quote numbers none of its
  # tops as it, nor grown from it
  defp body?(%Text{inserted: [_ | _] = paths} = text, [n]) do
    not String.contains?(n, "..") and
      Clauses.captionless(text).instruction =~
        ~r/\bfor\s+(?:the\s+)?(?:section|regulation|article|rule)\s+\d+[A-Z]*\b(?!\s*\()/i and
      Enum.all?(paths, fn [top | _] -> top != n and not own_number?(top, [n]) end)
  end

  defp body?(_text, _numbers), do: false

  @doc """
  A quoted path's targets: - a provision of its own when no provision is
  named to hold it, or its   number grows from one named ("After that
  section insert— 52A": s.52A;   "In section 142, after subsection (1)
  insert— (1A)": never s.1A) - else under the brackets named at levels
  above its own ("In section   7(1) for paragraph (b) substitute— (b)
  (c)": s.7(1)(c); "for   subsection (5) substitute— (4A) (5)": s.52(4A),
  never s.52(5)(4A)) - a quoted "(i)" may be a sub-paragraph under the
  last bracket's parent   ("In section 7(5)(b) for sub-paragraph (i)
  substitute— (i)":   s.7(5)(b)(i)) — a letter or a numeral
  """
  @spec quoted_paths([String.t()], [String.t()], [String.t()], String.t()) :: [String.t()]
  def quoted_paths(path, named, numbers, p) do
    own? = provision_path?(path) and (numbers == [] or own_number?(hd(path), numbers))

    if own? do
      [Brackets.ref(p, path)]
    else
      # a lone "i", "v" or "x" is a letter or a numeral: as a numeral, under
      # the last bracket named ("in paragraph (c), for “…” substitute— (i)
      # … (ii) …": s.51A(2)(c)(i), not only s.51A(2)(i) — CV-S06 seed 33)
      for(
        n <- numbers,
        pre <- prefixes(Brackets.above(named, [hd(path)])),
        do: Brackets.ref(p, [n | pre ++ path])
      ) ++
        for(
          n <- numbers,
          length(named) > 1,
          hd(path) =~ ~r/^[ivx]+[a-z]?$/,
          do: Brackets.ref(p, [n | Enum.drop(named, -1) ++ path])
        ) ++
        for(
          n <- numbers,
          named != [],
          hd(path) in ~w(i v x),
          # (under a letter: "(c)", never a numeral already — "(i)(i)")
          List.last(named) =~ ~r/^[a-z]{1,2}$/ and not (List.last(named) =~ ~r/^[ivx]+$/),
          do: Brackets.ref(p, [n | named ++ path])
        )
    end
  end

  # the brackets above a quoted path, one of each level per path ("in
  # subsections (2) and (5)— after paragraph (z) insert— (za)": (2)(za) and
  # (5)(za), never (2)(5)(za); run time 2026-10-26)
  defp prefixes(brackets) do
    brackets
    |> Enum.uniq()
    |> Enum.group_by(&Brackets.bracket_level/1)
    |> Enum.sort()
    |> Enum.reduce([[]], fn {_, level}, acc -> for a <- acc, b <- level, do: a ++ [b] end)
  end

  @doc """
  The clause whose quote follows ("… and after that subsection insert—"),
  else the first quoting one; "at the end there shall be added—" quotes
  too (RTA 1991 s.18(1), AR-10), and "after subsection (6) add the
  following subsections:" (SI 1988/1655 reg.23(c), CV-06 S7)
  """
  @spec quoting_clause([clause()]) :: clause() | nil
  def quoting_clause(clauses) do
    quoting = Enum.filter(clauses, &(&1.text.instruction =~ ~r/insert|substitut|\badd(?:ed)?\b/i))

    Enum.find(quoting, List.first(quoting), fn c ->
      Clauses.captionless(c.text).instruction =~ ~r/[—–:]\s*[;.,]?\s*$/u
    end)
  end

  @doc """
  The targets a clause names: its brackets' paths under provision `n` (an
  insertion only what it names as inserted).
  """
  @spec named_refs(Text.t(), {String.t(), String.t()}, String.t(), String.t(), [String.t()]) :: [
          String.t()
        ]
  def named_refs(text, {"inserted", "inserted"}, p, n, _named) do
    case {text.inserted, inserted_named(text)} do
      {[], [_ | _] = ins} -> for c <- Brackets.combos(ins), do: Brackets.ref(p, [n | c])
      _ -> []
    end
  end

  def named_refs(_text, _op, p, n, []), do: [Brackets.ref(p, [n])]

  def named_refs(_text, _op, p, n, named),
    do: for(c <- Brackets.combos(named), do: Brackets.ref(p, [n | c]))

  @doc """
  A clause's named targets under each provision number it names, the
  quote's own tops aside; a written list of places each carrying its own
  brackets (`listed_places/1`) is read item by item.
  """
  @spec clause_targets(map(), {String.t(), String.t()}, String.t(), [String.t()]) :: [String.t()]
  def clause_targets(c, op, p, tops) do
    case op != {"inserted", "inserted"} && listed_places(c.text.instruction, p) do
      [_ | _] = items ->
        listed_targets(items, c, p, tops)

      _ ->
        for n <- c.numbers,
            n not in tops,
            t <- named_refs(c.text, op, p, n, named_for(c, n)),
            uniq: true,
            do: t
    end
  end

  # each item its own place: its number (else the clause's), its brackets
  # and the clause's brackets outside the list ("In regulations 6(6), 8(9),
  # 12(2) and 15(1), in paragraph (a)": reg.8(9)(a), never reg.6(9) — SI
  # 2005/1434 reg.2(3); "In subsections (1)(e), (5) and (9)(a)": never
  # s.128(1)(a) — 2006 c.8 s.2(3); Maritime Safety 2026-11-06)
  defp listed_targets(items, c, p, tops) do
    rest = c.named -- Enum.flat_map(items, &elem(&1, 1))

    for {n, brackets} <- items,
        n <- if(n, do: [n], else: c.numbers),
        n not in tops,
        path <- [[] | Brackets.combos(brackets ++ rest)],
        path != [] or brackets == [],
        uniq: true,
        do: Brackets.ref(p, [n | path])
  end

  @item "(?:\\d+[A-Z]*(?:\\s+to\\s+\\d+[A-Z]*)?(?:\\([0-9A-Za-z]+\\))*|(?:\\([0-9A-Za-z]+\\))+)"
  @place_list Regex.compile!(
                "\\b((?i:(?:sub-?)?(?:sections?|regulations?|paragraphs?|articles?|rules?)))\\s+(" <>
                  @item <> "(?:\\s*(?:,|\\band\\b|\\bor\\b|\\bto\\b)\\s*" <> @item <> ")*)",
                "u"
              )

  # the law's own provisions, by its prefix: a numbered list of any other
  # ("in paragraphs 49(3)(b) and 73(2)(c)": the Insolvency Act 1986's
  # Schedule B1, never ss.49, 73 — SI 2008/948 Sch.1 para 100(a)) is not
  # its provisions
  @own_word %{
    "s" => ~r/^sections?$/i,
    "reg" => ~r/^regulations?$/i,
    "art" => ~r/^articles?$/i,
    "rule" => ~r/^rules?$/i
  }

  @doc """
  A written list of places whose items carry brackets of their own
  ("regulations 6(6), 8(9), 12(2) and 15(1)", "subsections (1)(e), (5) and
  (9)(a)"), quoted words and captions aside: each item's number (nil for a
  bracket alone, which takes the one before's, else the clause's) and
  brackets; [] for any other place (a plain "(5) and (6)" or "7, 8"
  reads the same as before), and where numbered items are not the law's
  own provisions (`p`, its prefix).
  """
  @spec listed_places(String.t(), String.t()) :: [{String.t() | nil, [String.t()]}]
  def listed_places(instruction, p) do
    plain = instruction |> Clauses.unquote_words() |> Clauses.no_captions()

    # every list the clause writes ("section 84(1)(b), (2)(a) …; section
    # 85(1) and (4) …": SI 1999/1820 Sch.2 para 116(4)), as the numbers it
    # names are read; never a place alone ("In section 21(1), paragraph
    # (a)(i), (iii)"; "Section 7 of the Gas Act 1986 and section 68(1) and
    # (2) of the principal Act": another law's)
    lists =
      for [_, word, list] <- Regex.scan(@place_list, plain),
          items = list_items(list),
          do: %{own?: word =~ @own_word[p], items: items}

    lists = Enum.filter(lists, &(length(&1.items) > 1))
    items = Enum.flat_map(lists, & &1.items)

    ours? = Enum.all?(lists, &(&1.own? or Enum.all?(&1.items, fn {n, _} -> n == nil end)))

    if lists != [] and ours? and length(items) > 1 and own_brackets?(items),
      do: items,
      else: []
  end

  # a range of bare numbers stays one ("Sections 28 to 34, 41 …": asp
  # 2004/6 Sch.7 para 4); a bracket alone is the item before's place at the
  # levels above its own ("paragraph (a)(i), (iii) and (iv)": (a)(iii);
  # "(1)(e), (5)": (5))
  defp list_items(list) do
    list = Regex.replace(~r/\b(\d+[A-Z]*)\s+to\s+(\d+[A-Z]*)\b(?!\s*\()/u, list, "\\1..\\2")

    ~r/(\d+[A-Z]*(?:\.\.\d+[A-Z]*)?)?((?:\([0-9A-Za-z]+\))*)/u
    |> Regex.scan(list, capture: :all_but_first)
    |> Enum.reject(&(&1 in [["", ""], [""]]))
    |> Enum.map_reduce({nil, []}, fn
      [n, b], _prev when n != "" -> item(n, Brackets.plain_brackets(b))
      [_, b], {n, before} -> item(n, inherit(before, Brackets.plain_brackets(b)))
      [n], _prev -> item(n, [])
    end)
    |> elem(0)
  end

  defp item(n, brackets), do: {{n, brackets}, {n, brackets}}

  defp inherit(before, own) do
    top = own |> hd() |> Brackets.bracket_level()

    before
    |> Enum.zip(levels(before))
    |> Enum.take_while(fn {_, level} -> level < top end)
    |> Enum.map(&elem(&1, 0))
    |> Kernel.++(own)
  end

  # a path's levels by position: a numeral after a letter is a
  # sub-paragraph ("(a)(i)": (i) at level 2, never a letter)
  defp levels(path) do
    path
    |> Enum.map_reduce(nil, fn b, prev ->
      level =
        if prev == 1 and b =~ ~r/^[ivx]+$/, do: 2, else: Brackets.bracket_level(b)

      {level, level}
    end)
    |> elem(0)
  end

  # an item placed deeper than one bracket, or numbered items one at least
  # with brackets (else the clause reads as before)
  defp own_brackets?(items) do
    Enum.any?(items, fn {_, b} -> length(b) > 1 end) or
      (Enum.all?(items, &elem(&1, 0)) and Enum.any?(items, fn {_, b} -> b != [] end) and
         items |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length() > 1)
  end

  @listed ~r/\b(?i:sections?|regulations?|articles?|rules?)\s+(\d+[A-Z]*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|or)\s*\d+[A-Z]*(?:\([0-9A-Za-z]+\))*)+)/u

  @doc """
  The brackets for provision `n` of a clause naming several: a bare number
  listed beside numbers carrying brackets of their own is whole ("sections
  7, 8(2) … are hereby repealed": s.7, never s.7(2); SI 1974/1941
  reg.5(1)); else the clause's brackets (`named`), whose readings the rows
  held decide.
  """
  @spec named_for(map(), String.t()) :: [String.t()]
  def named_for(%{text: text, named: named}, n) do
    if n in bare_listed(text.instruction), do: [], else: named
  end

  # a written list mixing bare numbers and numbers with brackets ("sections
  # 7, 8(2)"): its bare numbers, outside quoted words and captions
  defp bare_listed(instruction) do
    for [list] <-
          Regex.scan(@listed, instruction |> Clauses.unquote_words() |> Clauses.no_captions(),
            capture: :all_but_first
          ),
        items = Regex.scan(~r/(\d+[A-Z]*)((?:\([0-9A-Za-z]+\))*)/u, list, capture: :all_but_first),
        Enum.any?(items, &match?([_, ""], &1)) and Enum.any?(items, &(not match?([_, ""], &1))),
        [m, ""] <- items,
        do: m
  end

  @doc """
  A rule for `law` (nil when the clause reaches no target).
  """
  @spec rule(map(), [String.t()], {String.t(), String.t()}, map()) :: Rule.t() | nil
  def rule(_law, [], _op, _source), do: nil

  def rule(law, targets, {operation, type}, source),
    do:
      Rule.new(
        amends: law.law_name,
        targets: targets,
        operation: Rule.operation(operation),
        level: if(String.starts_with?(type, "words"), do: :words, else: :provision),
        source: source,
        treatment: :instruction
      )

  @doc """
  The provision numbers named; "22 to 25" a range ("22..25")
  """
  @spec numbers([String.t()], atom()) :: {:ok, [String.t()]} | :none
  def numbers(texts, kind) do
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

  @doc """
  The brackets an insertion names as inserted, its location ("In
  subsection (2)") left out.
  """
  @spec inserted_named(Text.t()) :: [String.t()]
  def inserted_named(%Text{instruction: i} = text),
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

  @doc """
  The whole section is the thing substituted or inserted ("For section 7",
  "after section 47B", "substituted for section 18"; not "for section
  7(2)", not "for subsection (2)")
  """
  @spec sections_quoted?(Text.t()) :: boolean()
  def sections_quoted?(%Text{} = text),
    do:
      Clauses.captionless(text).instruction =~
        ~r/\b(?:for|after|before)\s+(?:the\s+)?(?:sections?|regulations?|articles?|rules?)\s+\d+[A-Z]*\b(?!\s*\((?:\d+[A-Z]*|[a-z]{1,3})\))/i

  @doc """
  Whether a quoted path is a provision's own (it starts with a number).
  """
  @spec provision_path?([String.t()]) :: boolean()
  def provision_path?([top | _]), do: top =~ ~r/^\d/

  @doc """
  A number grown from a provision named ("52A" from section 52, "2C" from
  regulation 2B)
  """
  @spec own_number?(String.t(), [String.t()]) :: boolean()
  def own_number?(top, numbers) do
    case Regex.run(~r/^(\d+)[A-Z]+$/, top) do
      [_, stem] -> Enum.any?(numbers, &(&1 =~ ~r/^#{stem}(?:[A-Z]+)?$/))
      nil -> false
    end
  end

  @doc """
  The brackets a clause names: quoted words left out; "after paragraph
  (2)(b)" gives its parent; "(which becomes …)" left out.
  """
  @spec brackets(Text.t()) :: [String.t()]
  def brackets(%Text{instruction: i}) do
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
    |> Enum.filter(&Brackets.bracket?/1)
  end
end
