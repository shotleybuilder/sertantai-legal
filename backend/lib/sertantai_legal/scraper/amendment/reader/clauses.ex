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

  # words quoted as inline amendments leave an empty slot in the
  # instruction's own words ("omit <quote>," → "omit ,"; "after <quote>
  # insert <quote>." → "after insert ."): the quote is words, unless a
  # provision named is what goes ("omit sub-paragraph (d) and the <quote>
  # preceding it") (SSI 2026/55, SSI 2025/165, NISR 2025/126;
  # Environmental Protection, Decision 2)
  @quote_slot ~r/\b(?:omit|after|before|for)\s*(?:[,;.]|$|(?=(?:insert|substitute)\b))/iu
  @provision_object ~r/\b(?:omit|repeal|revoke|for)\s+(?:the\s+)?(?:sub-?)?(?:sections?|paragraphs?|regulations?|articles?|rules?|heads?)\s*\d*[A-Z]*\(/iu
  defp inline_words?(%Text{quoted: q, inserted: [], instruction: i}) when q != "",
    do: i =~ @quote_slot and not (i =~ @provision_object)

  defp inline_words?(_text), do: false

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
        if words_unnamed?(text.instruction) or words_listed?(text) or inline_words?(text),
          do: {verb, "words #{verb}"},
          else: op

      {"inserted", "inserted"} = op ->
        if words_inserted?(text), do: {"inserted", "words inserted"}, else: op

      op ->
        op
    end
  end

  # an insertion quoting no provision at a place in the provision named
  # ("in the appropriate place insert— <definition>": WSI 2013/755,
  # Environmental Protection, Decision 2) or of inline-quoted words
  defp words_inserted?(%Text{inserted: [], instruction: i} = text),
    do:
      (i =~ ~r/\b(?:at|in) the (?:end|beginning|appropriate places?)\b/i or inline_words?(text)) and
        not (i =~ @provision_named)

  defp words_inserted?(_text), do: false

  @doc """
  An item whose verb is its parent's noun ("Section 5 … shall be amended by
  the insertion— … (b) after subsection (4), of the following
  subsections—": EPA 1990 Sch. 15 para. 14, CV-06 S7) with the verb before
  its words ("insert after subsection (4), …"); any other text as it is.
  """
  @parent_noun ~r/\bby\s+the\s+(insertion|substitution|omission)\b[^—–]*[—–]\s*$/iu
  @noun_verb %{"insertion" => "insert", "substitution" => "substitute", "omission" => "omit"}

  @spec with_parent_verb(Text.t()) :: Text.t()
  def with_parent_verb(%Text{parents: [parent | _], instruction: i} = text) do
    with nil <- Operation.of(text),
         [_, noun] <- Regex.run(@parent_noun, parent) do
      %{text | instruction: @noun_verb[String.downcase(noun)] <> " " <> i}
    else
      _ -> text
    end
  end

  def with_parent_verb(text), do: text

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

  @schedule_entry ~r/,?\s*(?:and\s+)?the\s+entr(?:y|ies)\s+in\s+Schedule\s+[0-9A-Z]+\s+relating\s+to\s+.*?(?=\s+(?:are|is|shall|be)\b|[;:]|$)/u

  @doc """
  The text without an entry in the amended law's Schedule repealed beside
  its sections ("sections 7, 8(2) and the entry in Schedule 2 relating to
  section 124(2) of the 1961 Act are hereby repealed": SI 1974/1941
  reg.5(1)): a Schedule's (not parsed, v0.1), and the section it names is
  another law's — neither a target nor words in one
  """
  @spec no_schedule_entries(String.t()) :: String.t()
  def no_schedule_entries(s), do: Regex.replace(@schedule_entry, s, "")

  @entry_ref "\\d+[A-Z]*(?:\\s*\\([0-9A-Za-z]+\\))*"
  @entry_named Regex.compile!(
                 "\\b(the\\s+entr(?:y|ies)\\s+)(?:relating\\s+to|for)\\s+(?:sections?|regulations?|articles?|rules?|paragraphs?)\\s+" <>
                   @entry_ref <>
                   "(?:\\s*(?:,|and|or|to)\\s*(?:" <> @entry_ref <> "|\\([0-9A-Za-z]+\\)))*",
                 "iu"
               )

  @doc """
  The text with a table's entry named by the provision it lists left as
  "the entry" ("In section 160A, after the entry relating to section
  45AA(10) insert—": s.160A's table, never s.45AA(10), asp 2024/13 s.15(3);
  "in the second column of the entry for section 34CA, in paragraph (e)
  omit": 2023 c.28 Sch.3 para 1(a); Environmental Protection F5, 2026-11-10)
  """
  @spec no_entry_names(String.t()) :: String.t()
  def no_entry_names(s), do: Regex.replace(@entry_named, s, "\\1")

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
  # "regulation 2(1) (interpretation)", "paragraph 14 of Schedule 7A (…)",
  # "paragraph 15(b) and (f) (in the quoted text modifying section 155 of
  # the Data Protection Act 2018)" (SI 2026/386 Sch. 3 para 6(4)(j)(iv): a
  # sibling's aside had named the law for para 6(5), CV-S05)
  @captioned ~r/(\b(?:sections?|subsections?|regulations?|articles?|rules?|paragraphs?|sub-paragraphs?|Schedules?|Parts?|Chapters?)\s+[0-9]+[A-Z]*(?:\s*\([0-9A-Za-z]+\))*(?:\s*(?:,|and|or|to)\s*\([0-9A-Za-z]+\)(?:\s*\([0-9A-Za-z]+\))*)*)\s*\((?:[^()“”"]|[“"][^”"]*[”"]|\([^()]*\))*\)/u

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
  2010”": SI 2024/1268, whose definition's title had named a law), and
  words up to a closing quote left with no opener or after an opening
  quote left with no closer.
  """
  @spec unquote_words(String.t()) :: String.t()
  def unquote_words(t),
    do:
      t
      |> unnest()
      |> String.replace(~r/[“"][^”"]*[”"]/u, "")
      # a closing quote left with no opener ends quoted words that run back
      # to the instruction's dash ("insert—“” means Commission Implementing
      # Regulation (EU) 2017/1354 …;”": a term lost in the flattening; SI
      # 2019/696 Sch. 29 para 2, whose inserted words had named EU laws)
      |> String.replace(~r/([—–])[^“”—–]*”/u, "\\1")
      # and an opening quote left with no closer, quoted words to the end
      # ("for substitute “Schedule 2 to the Supply of Machinery (Safety)
      # Regulations 2008/1597; and": SI 2019/696 Sch. 22, which had named
      # the Machinery Regulations for the Lifts Regulations' paragraphs)
      |> String.replace(~r/“[^”]*$/u, "")

  defp unnest(t) do
    case String.replace(t, ~r/“[^“”]*”(?=[^“]*”)/u, "") do
      ^t -> t
      fewer -> unnest(fewer)
    end
  end

  @doc """
  A text set in capitals, each word capitalised ("MODIFICATIONS—THE FACTORIES
  ACT 1961" → "Modifications—The Factories Act 1961"), so a title in it reads
  as one; any other text as it is.
  """
  @spec uncapped(String.t()) :: String.t()
  def uncapped(t) do
    if t =~ ~r/\p{Lu}{2}/u and not (t =~ ~r/\p{Ll}/u),
      do: Regex.replace(~r/\p{L}+/u, t, &String.capitalize/1),
      else: t
  end
end
