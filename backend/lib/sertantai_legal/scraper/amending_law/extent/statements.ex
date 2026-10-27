defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Statements do
  @moduledoc """
  A sentence and the statements inside it (CV-S05 round 4; moved from
  `Extent.Units`, round 13): each lettered item under a lead-in, each
  clause of a compound, and each item's own compound. Pure.
  """

  # (a Chapter, and "the amendments made by …": items of "In Part 3— (i)
  # Chapter 1 extends to …", "— (a) the amendments made by paragraph 9(3)
  # of Schedule 12 extend to …", CV-S05 round 6)
  # (also "(b) an amendment or repeal made by Chapters 2 to 6 …", "(a) any
  # amendment made by virtue of …": ukpga 2023/55 s.254(3), 2004/33
  # s.262(6), round 8)
  @provision_word "(?:(?:sections?|paragraphs?|Schedules?|Parts?|Chapters?|regulations?|articles?|rules?)\\s+[\\dIVXL]|(?:the|an?|any)\\s+(?:amendments?|repeals?|revocations?)(?:\\s*(?:,|or|and)\\s*(?:amendments?|repeals?|revocations?))*\\s+(?:made\\s+by|in)\\s)"

  @item Regex.compile!(
          "[—–;]\\s*(?:and\\s*)?\\(?(?:[a-z]{1,2}|[ivx]{3,4})\\)?\\s+(?=(?:in\\s+Part\\s+[\\dIVXL]+[A-Z]*\\s*,\\s*)?#{@provision_word})",
          "u"
        )
  @item_comma Regex.compile!(
                "(?:[—–;]\\s*(?:and\\s*)?|,\\s*(?:and\\s*)?(?!(?:or|as|in|to|of|at|by|on|an|so)\\s))\\(?(?:[a-z]{1,2}|[ivx]{3,4})\\)?\\s+(?=#{@provision_word})",
                "u"
              )

  @doc """
  A sentence and the statements inside it (CV-S05 round 4): each lettered
  item under a lead-in ("In Part 5— (a) sections 220 to 224 extend to
  England and Wales only; (b) …", "Part 5 extends as follows— (a) …"), and
  each clause of a compound (items run in after a comma too: "In Part 6— a
  … extend to England and Wales and Scotland,b section 40 … extend to …,
  andc …", ukpga 2015/7 s.56, CV-S05 round 11), and each clause of a compound ("Paragraphs 34 and 35 … extend to England and
  Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland
  only", "that Schedule" named). The sentence itself first.
  """
  @spec statements(String.t()) :: [String.t()]
  def statements(s) do
    items =
      if s =~ ~r/[—–]/u do
        # (items run in after a comma too, where each states its own
        # extent: never "(a) sections 1 to 3, … and (b) Schedules 1 and 2
        # …, shall extend to Northern Ireland only", 1975/59 s.14)
        with_commas = s |> String.split(@item_comma) |> tl()

        if with_commas != [] and
             Enum.all?(with_commas, &(&1 =~ ~r/\b(?:extends?|extend|same\s+extent)\b/iu)),
           do: with_commas,
           else: s |> String.split(@item) |> tl()
      else
        []
      end

    # (also "; and this section extends also to Scotland", 1998/31 s.145;
    # "… do not extend to Scotland and sections 34 and 35 extend to Scotland
    # only", 1969/10 s.38: each half with its own verb, round 13 S5, S6)
    clauses =
      case String.split(
             s,
             Regex.compile!(
               "(?:[,;]\\s*|\\s+)and\\s+(?=(?:#{@provision_word}|this\\s+(?:section|regulation|article|Part|Chapter)\\b)(?:[^,;]*?\\b(?:extends?|extend)\\b|[^;]*?\\bha(?:s|ve)\\s+the\\s+same\\s+extent\\b))",
               "iu"
             ),
             parts: 2
           ) do
        [first, second] when first != s ->
          if first =~ ~r/\b(?:extends?|extend)\b/iu, do: compound(first, second), else: []

        _ ->
          []
      end

    # (each item's own compound too: "a in Part IV, sections 42 and 43 extend
    # to England and Wales only and section 44 extends to Scotland only",
    # its locator lead out: ukpga 1987/27 s.50, round 13 S6)
    items =
      Enum.flat_map(items, fn item ->
        item = Regex.replace(~r/^\s*in\s+Part\s+[\dIVXL]+[A-Z]*\s*,\s*/iu, item, "")
        [item | item_clauses(item)]
      end)

    for part <- [s | items ++ clauses],
        # (repealed words in a number list: "Sections ... 4, 5, . . . of this
        # Act do not extend to Scotland", 1976/55 s.27; round 13 S10)
        part = Regex.replace(~r/\s*(?:\.\s*){3,}/u, part, " "),
        part = part |> String.trim() |> String.trim_trailing(";") |> String.trim(),
        part != "",
        uniq: true,
        do: part
  end

  defp item_clauses(item) do
    case String.split(
           item,
           Regex.compile!(
             "\\s+and\\s+(?=#{@provision_word}[^,;]*?\\b(?:extends?|extend)\\b)",
             "iu"
           ),
           parts: 2
         ) do
      [first, second] -> if first =~ ~r/\b(?:extends?|extend)\b/iu, do: [first, second], else: []
      _ -> []
    end
  end

  # the second clause of a compound, "that Schedule" named
  defp compound(first, second) do
    case Regex.run(~r/\bSchedule\s+(\d+[A-Z]*)\b/u, first, capture: :all_but_first) do
      [n] -> [first, String.replace(second, ~r/\bof\s+that\s+Schedule\b/u, "of Schedule #{n}")]
      nil -> [first, second]
    end
  end
end
