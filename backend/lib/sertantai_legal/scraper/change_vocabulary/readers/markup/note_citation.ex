defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.NoteCitation do
  @moduledoc """
  Which `Citation` of a note is its amending law's.

  The amending law is the first Citation after the note's operative "by"
  (or "by virtue of"): the first "by" outside every bracket. A Citation
  before it, or inside a bracket after it, is another law's:

  - one that dates the change: "substituted (in force at 1.5.1994 … in
    accordance with art. 3 of S.I. 1994/1096) by Environmental Protection
    Act 1990 (c.43, SIF 46:4), s. 162(1), Sch. 15 para. 26" (the Food and
    Environment Protection Act 1985 s.10); "(1.1.2024 immediately after
    S.I. 2023/850 comes into force) by …" (SI 2020/1265 art.34K(b));
  - one that made what is now amended: "Words in s. 26(1) (as substituted
    by … 1990 c. 35) substituted (30.8.1993) by 1993 c. 19" (the Housing
    (Scotland) Act 1988); "repealed (N.I.), except so far as it relates to
    … Act 1927 (c. 41) …, by S.I. 1975/1503 (N.I. 15)" (the Social Security
    Act 1973 s.69);
  - one that amended the amending provision: "inserted (31.12.2020) by
    The Waste (Miscellaneous Amendments) (EU Exit) Regulations 2019 (S.I.
    2019/620), regs. 1(2)(b), 14(2) (as amended by S.I. 2020/1540, …)"
    (Decision 2001/171 Art.A1).

  One bracket names the amending law itself: where the amending provision
  was inserted or substituted by another law, "substituted (31.12.2020)
  by S.I. 2019/74, reg. 5 (as substituted by The … Regulations 2020 (S.I.
  2020/1352), regs. 1, 3(2))" (SI 2012/1715 reg.3(2)), the change is that
  law's: the first Citation in the "(as inserted by", "(as substituted
  by" or "(as added by" bracket after the "by". legislation.gov.uk's feed
  files the effect under it (273 of 282 such notes with a feed effect;
  under the law amended for "as amended by": 1,637 of 1,690).

  The bracket round an instrument's own number ("… Order (S.I.
  2009/1941), art. 2(1)") is the Citation's. A law after a ";" that closes
  another law's pieces is the commencement order of a law cited in words
  only. Where the "by" has
  Citations after it and none is the amending law's, the note gives none
  (the reader falls back to the note's words, for identity only): unknown
  over a guess. A note with no "by" outside brackets, or none with a
  Citation after it, keeps the older reading: its first Citation outside
  the date bracket, else its first. Pure.
  """

  @date_bracket ~r/\(\s*\d{1,2}\.\s*\d{1,2}\.\s*\d{4}[^()]*$/u
  @balanced ~r/\([^()]*\)/u
  @by ~r/\bby\b/iu
  # the bracket naming the law that made the amending provision, open at
  # a Citation: "(as substituted by ", "(as inserted by The … Regulations
  # 2020 (S.I. " (the number bracket as `@number_bracket`)
  @remade ~r/^([^(]*)\(as\s+(?:inserted|substituted|added)\b[^()]*\bby\b[^()]*(?:\(\s*(?:[A-Z][A-Z.\s]{0,10}|c\.|asp|anaw|asc|nia|mwa|No\.)?\s*)?$/u
  # a law and its pieces named in words, closed by ";": "1989 (c.15), s.
  # 141, Sch. 17 para. 4(a); "; a title's own ";" follows no number
  # ("Medicinal Products; Prescription by Nurses etc. Act 1992 (c. 28)":
  # the National Health Service (Scotland) Act 1978 s.27(1)(cc))
  @other_law ~r/\d[^;]*;/u
  # what an instrument's number bracket holds before the linked number:
  # "(", "(S.I. ", "(W.", "(c. ", "(asp ", "(No. "; a bracket of the title
  # left open before it opens with a capital ("(England and Wales
  # (Amendment) Regulations (S.I. 2009/1799)": legislation.gov.uk's slip),
  # a reference's does not ("(as substituted by The … Regulations 2020 (")
  @number_bracket ~r/^(?:[^(;]|\((?=\s*\p{Lu}))*\(\s*(?:[A-Z][A-Z.\s]{0,10}|c\.|asp|anaw|asc|nia|mwa|No\.)?\s*$/u

  @doc "The note's amending law's `Citation` element in a `Commentary`, or nil."
  @spec amending(tuple()) :: tuple() | nil
  def amending(commentary) do
    {text, cited} = read(commentary)

    case governed(cited, operative_by(text)) do
      [] -> first_undated(cited)
      after_by -> settled(after_by)
    end
  end

  @doc """
  The words naming an amending law that is cited in words only: from the
  note's "by" to the first Citation after it (" 1989 (c.15), s. 141, Sch.
  17 para. 4(a) (as amended by "), where none of the Citations after the
  "by" is the amending law's. nil for any other note.
  """
  @spec unlinked(tuple()) :: String.t() | nil
  def unlinked(commentary) do
    {text, cited} = read(commentary)

    case governed(cited, operative_by(text)) do
      [] -> nil
      [{_el, between} | _] = after_by -> if settled(after_by) == nil, do: between
    end
  end

  # of the Citations after the "by": the law that made the amending
  # provision what it is ("(as inserted by Y"), else the first that is the
  # amending law's own
  defp settled(after_by), do: first_remade(after_by) || first_own(after_by)

  # the first Citation in an "(as inserted by" bracket, where the bracket
  # follows the one amending law: after two laws ("by virtue of Criminal
  # Justice Act 1982 (c. 48), s. 46 and Criminal Procedure (Scotland) Act
  # 1975 (c. 21), s. 289G (as inserted by …)": the Control of Pollution
  # Act 1974) it speaks of the second only, and the first stays
  defp first_remade(after_by) do
    case Enum.split_while(after_by, fn {_el, between} -> not remade?(between) end) do
      {before, [{el, _between} | _]} -> if one_law?(before), do: el
      {_all, []} -> nil
    end
  end

  defp one_law?(cited),
    do: cited |> Enum.map(fn {el, _between} -> uri(el) end) |> Enum.uniq() |> length() <= 1

  defp uri({:xmlElement, :Citation, _, _, _, _, _, attrs, _, _, _, _}), do: attr(attrs, :URI)

  defp first_own(after_by),
    do: Enum.find_value(after_by, fn {el, between} -> own?(between) && el end)

  # the words from the "by" to a Citation open the bracket "(as inserted
  # by", "(as substituted (31.12.2020) by The … Regulations 2020 (", after
  # the amending law's own pieces (no other law's list closed by ";")
  defp remade?(between) do
    case Regex.run(@remade, unclosed(between)) do
      [_, lead] -> not String.match?(lead, @other_law)
      nil -> false
    end
  end

  # the note's words, and its linked Citations in document order
  defp read(commentary) do
    {text, cited} = walk(commentary, {"", []})
    {text, Enum.reverse(cited)}
  end

  @doc "A note's linked `Citation`s in document order, each with the note's words before it."
  @spec linked(tuple()) :: [{tuple(), String.t()}]
  def linked(commentary), do: commentary |> read() |> elem(1)

  @doc "Whether a note's words so far end inside its date bracket: \"… (1.1.2024 immediately after \"."
  @spec in_date_bracket?(String.t()) :: boolean()
  def in_date_bracket?(before), do: before |> unclosed() |> String.match?(@date_bracket)

  @doc """
  Where a note's operative "by" ends, in bytes: the first "by" outside
  every bracket; nil for a note with none.
  """
  @spec operative_by(String.t()) :: non_neg_integer() | nil
  def operative_by(text) do
    @by
    |> Regex.scan(text, return: :index)
    |> Enum.find_value(fn [{at, len}] ->
      if outside_brackets?(binary_part(text, 0, at)), do: at + len
    end)
  end

  defp outside_brackets?(before), do: not (before |> unclosed() |> String.contains?("("))

  # the Citations after the "by", each with the note's words between
  defp governed(_cited, nil), do: []

  defp governed(cited, by_end) do
    for {el, before} <- cited,
        byte_size(before) >= by_end,
        do: {el, binary_part(before, by_end, byte_size(before) - by_end)}
  end

  # the words from the "by" to a Citation leave it the amending law's: no
  # other law's list closed by ";" and no bracket open but the
  # instrument's own number bracket
  defp own?(between) do
    open = unclosed(between)

    not String.match?(open, @other_law) and
      (not String.contains?(open, "(") or String.match?(open, @number_bracket))
  end

  # the older reading: the first Citation outside the date bracket, else
  # the first
  defp first_undated(cited) do
    case Enum.find(cited, fn {_el, before} -> not in_date_bracket?(before) end) do
      {el, _before} -> el
      nil -> cited |> List.first() |> then(&(&1 && elem(&1, 0)))
    end
  end

  # the words with every closed bracket taken out
  defp unclosed(text) do
    case Regex.replace(@balanced, text, "") do
      ^text -> text
      shorter -> unclosed(shorter)
    end
  end

  # the note in document order: each linked Citation with the words before it
  defp walk({:xmlElement, :Citation, _, _, _, _, _, attrs, _, _, _, _} = el, {before, cited}) do
    after_it = before <> text(el)
    if attr(attrs, :URI), do: {after_it, [{el, before} | cited]}, else: {after_it, cited}
  end

  defp walk({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}, state),
    do: Enum.reduce(children, state, &walk/2)

  defp walk({:xmlText, _, _, _, value, _}, {before, cited}),
    do: {before <> to_string(value), cited}

  defp walk(_node, state), do: state

  # a Citation's own words (its children's: the Citation itself is `walk`'s)
  defp text({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}),
    do: children |> Enum.reduce({"", []}, &walk/2) |> elem(0)

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end
