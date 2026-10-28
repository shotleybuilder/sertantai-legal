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
    rule: "rules?"
  }
  @doc """
  The targets of a clause's quoted provisions (`text.inserted`) under its
  brackets (`named`) and provision numbers.
  """
  @spec quoted_targets(clause(), String.t()) :: [String.t()]
  def quoted_targets(%{text: text, named: named, numbers: numbers}, p) do
    if sections_quoted?(text) do
      # "For section 99 substitute— 99 …", "After section 47B insert— 47C":
      # the quote's numbers are sections, never nested in one (AR-07)
      for path <- text.inserted, provision_path?(path), uniq: true, do: Brackets.ref(p, path)
    else
      for path <- text.inserted,
          t <- quoted_paths(path, named, numbers, p),
          uniq: true,
          do: t
    end
  end

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
  too (RTA 1991 s.18(1), AR-10)
  """
  @spec quoting_clause([clause()]) :: clause() | nil
  def quoting_clause(clauses) do
    quoting = Enum.filter(clauses, &(&1.text.instruction =~ ~r/insert|substitut|\badded\b/i))

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
