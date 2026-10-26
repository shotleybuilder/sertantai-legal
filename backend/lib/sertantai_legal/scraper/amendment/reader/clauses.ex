defmodule SertantaiLegal.Scraper.Amendment.Reader.Clauses do
  @moduledoc """
  An amending instruction's clauses and operation (AR-03, AR-08;
  decomposed from `Amendment.Reader`, run time 2026-10-25): the clauses
  one per operation, the verb with captions aside, captions and quoted
  words stripped, where a clause is (its located brackets). Pure; calls
  `Reader.Brackets` only.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Operation, Text}
  alias SertantaiLegal.Scraper.Amendment.Reader.Brackets

  # "the following paragraph", "a new subsection": the insertion is a provision
  @provision_named ~r/\b(?:following|new)\s+(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|provisions?|schedules?|parts?|chapters?)\b/i
  # "in subsection (1)", "In section 7(1)(a)": where the clause is
  @place ~r/\bin\s+(?:sub-?)?(?:sections?|paragraphs?|sub-?paragraphs?|regulations?|articles?|rules?)\s+(?:\d+[A-Z]*\s*)?((?:\([0-9A-Za-z]+\))+)/i
  @doc """
  The text without its captions, a title's own brackets kept ("Planning
  (Listed Buildings and Conservation Areas) Act 1990")
  """
  @spec asides(String.t()) :: String.t()
  def asides(s) do
    ~r/[“"][^”"]*[”"]|\((?:[^()“”"]|[“"][^”"]*[”"])*\)(?!\s*(?:Act|Regulations|Order|Rules|\d{4})\b)/u
    |> Regex.replace(s, fn m -> if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: "" end)
  end

  @doc """
  The brackets of where the clause is ("in subsection (1)", "In section
  7(1)(a)" → ["1", "a"]).
  """
  @spec located_brackets(String.t()) :: [String.t()]
  def located_brackets(i) do
    i
    |> strip_captions()
    |> unquote_words()
    |> then(&Regex.scan(@place, &1, capture: :all_but_first))
    |> Enum.flat_map(&Brackets.plain_brackets(hd(&1)))
    |> Enum.filter(&Brackets.bracket?/1)
  end

  @doc """
  The instruction's clauses, one per operation: split at "and" or ";"
  outside quotes and captions, a piece with no verb joined to the next
  ("Sections 4 and 5 are repealed") or, last, to the one before
  """
  @spec clauses(Text.t()) :: [Text.t()]
  def clauses(%Text{instruction: i} = text) do
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

  @doc """
  Words the instruction doesn't spell out: an emptied quote ("“”": the
  quote held only markup — 1991 c.39 s.1(2)) or "each of the following is
  omitted—" with no kind of provision named (a list of words: 2004 c.5)
  """
  @spec words_unnamed?(String.t()) :: boolean()
  def words_unnamed?(i),
    do:
      i =~ ~r/[“"]\s*[”"]/u or
        (i =~ ~r/\bthe following (?:is|are|shall be) (?:omitted|repealed|revoked)\b/i and
           not (i =~ @provision_named))

  # "in paragraph (c)(ii) of that subsection—shall be omitted; (i) the
  # words “…”, and (ii) the word “…”": what is omitted is its list items,
  # all words (1995/25 Sch. 22 para 30(6)(b), run time 2026-10-26)
  defp words_listed?(%Text{instruction: i, items: [_ | _] = items}),
    do:
      i =~ ~r/[—–]\s*(?:shall\s+be|are|is|be)\s+(?:omitted|repealed|revoked)\b/iu and
        Enum.all?(items, &(&1 =~ ~r/^\s*the\s+words?\b/i))

  defp words_listed?(_text), do: false

  @doc """
  The instruction's operation, its captions aside; an insertion quoting no
  provision "at the end" / "at the appropriate place" — and naming no kind
  of provision as inserted — puts words into the provision named (2014 c.6
  s.128(2)(e): a definition into s.235(1))
  """
  @spec operation(Text.t()) :: {String.t(), String.t()} | nil
  def operation(text) do
    case Operation.of(captionless(text)) do
      {verb, verb} = op when verb != "inserted" ->
        if words_unnamed?(text.instruction) or words_listed?(text),
          do: {verb, "words #{verb}"},
          else: op

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

  @doc """
  The instruction without its bracketed captions ("In section 118 (… of
  revoked or suspended licences), after subsection (4) insert—": the verb
  is "insert", not the caption's "revoked" — SI 1998/1420; "(“the 1984
  Act”)" names a term, not words changed); quoted words keep their
  brackets
  """
  @spec captionless(Text.t()) :: Text.t()
  def captionless(%Text{instruction: i} = text),
    do: %{text | instruction: strip_captions(i)}

  @doc """
  A bracketed caption: a parenthetical with a space, quotes inside
  allowed, never starting inside a quote
  """
  @spec strip_captions(String.t()) :: String.t()
  def strip_captions(s) do
    ~r/[“"][^”"]*[”"]|\((?:[^()“”"]|[“"][^”"]*[”"])*\)/u
    |> Regex.replace(s, fn m -> if m =~ ~r/^[“"]/u or not (m =~ ~r/\s/u), do: m, else: "" end)
  end

  @doc """
  The text without its captions, brackets inside them too ("… 1990
  (provisions to which subsections (1) to (4) are subject)—": no place;
  1995/25 Sch. 10 para 32(1)); a bracket with no space is kept ("(5)",
  "(Scotland)").
  """
  @spec no_captions(String.t()) :: String.t()
  def no_captions(s) do
    Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, s, fn m ->
      if m =~ ~r/\s/u, do: "", else: m
    end)
  end

  # a provision reference, then its caption: "section 1 (application of …)",
  # "regulation 2(1) (interpretation)", "paragraph 14 of Schedule 7A (…)"
  @captioned ~r/(\b(?:sections?|subsections?|regulations?|articles?|rules?|paragraphs?|sub-paragraphs?|Schedules?|Parts?|Chapters?)\s+[0-9]+[A-Z]*(?:\s*\([0-9A-Za-z]+\))*)\s*\((?:[^()“”"]|[“"][^”"]*[”"]|\([^()]*\))*\)/u

  @doc """
  The text without the captions that follow a provision reference ("In
  section 1 (application of Part I of Health and Safety at Work etc. Act
  1974 …)": a caption describes the provision, never names the law amended
  — Petroleum Act 1998 Sch. 4 para 33). Titles keep every bracket of their
  own ("The Environmental Protection (Disposal of …) (England and Wales)
  Regulations 2000"), unlike `asides/1`.
  """
  @spec uncaptioned(String.t()) :: String.t()
  def uncaptioned(s), do: Regex.replace(@captioned, s, "\\1")

  @doc """
  The text without its quoted words — nested quotes too, innermost first
  ("omit ““x” means the Building (Approved Inspectors etc.) Regulations
  2010”": SI 2024/1268, whose definition's title had named a law).
  """
  @spec unquote_words(String.t()) :: String.t()
  def unquote_words(t), do: t |> unnest() |> String.replace(~r/[“"][^”"]*[”"]/u, "")

  defp unnest(t) do
    case String.replace(t, ~r/“[^“”]*”(?=[^“]*”)/u, "") do
      ^t -> t
      fewer -> unnest(fewer)
    end
  end
end
