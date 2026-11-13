defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting do
  @moduledoc """
  The amending provisions a changes-feed effect names (its
  `affecting_provisions` text) as refs, named as our provisions are named
  (`Commencement.Order.ref`): "s. 29(4)" → "s.29(4)", "Sch. 7 para. 27(2)"
  → "sch.7.para.27(2)", and an article "art. 18" → "reg.18" (an Order's
  articles are `reg.` rows; CV-S05 round 7 NEW-6: SI 2022/1174 art. 18 was
  never found in its extent list). A range ("regs 11-14") is every
  provision from its start to its end. Pure.
  """

  # (an unnumbered Schedule's paragraph, "Sch. para. 3(1)(b)": CV-S07 round 3;
  # a range, "regs 11-14", "art. 11(1)-(3)", "Sch. 2 para. 3-5", with the
  # kind named in the plural: Fire and OH&S, Feed reader)
  @number ~S"\d+[A-Z]*(?:\([^)]+\))*"
  @upto ~S"(?:\([^)]+\))+"
  # a kind named in the plural is read only as a range's ("regs 11-14";
  # a plural list, "regs. 3 5", is not read)
  @ranged "(?=\\.?\\s*#{@number}\\s*-)"
  @refs Regex.compile!(
          "\\b(?:Sch(?:\\.|s#{@ranged}\\.?)\\s*(?<sch>\\d+[A-Z]*)?(?:\\s*-\\s*(?<sch_to>\\d+[A-Z]*))?" <>
            ~S"(?:\s*Pt\.\s*(?<pt>\d+[A-Z]*|[IVXLC]+))?" <>
            "(?:\\s*para(?:\\.|s#{@ranged}\\.?)\\s*(?<para>#{@number})" <>
            "(?:\\s*-\\s*(?<para_to>#{@number}|#{@upto}))?)?" <>
            "|(?<kind>(?:s|reg|art)(?=\\.)|(?:ss|regs|arts)#{@ranged})\\.?\\s*(?<n>#{@number})" <>
            "(?:\\s*-\\s*(?<n_to>#{@number}|#{@upto}))?)",
          "u"
        )

  # "(adding 1949 c. 30 s. 3A(1)-(3))", "(addingto1986 c 53 Sch. 15A)": the
  # provisions the affecting provision adds to another law, never its own
  # (Fire and OH&S: Feed reader); the tail runs to the end, unbalanced
  @adding ~r/\(\s*adding.*$/su

  # the most a range is counted out to; a longer one gives its two ends
  @longest 100

  @doc ~S"""
  Every provision named: "Sch. 7 para. 27(2) Sch. 17 Pt. 2" →
  ["sch.7.para.27(2)", "sch.17.pt.2"]; "s. 111, Sch. 7" → ["s.111", "sch.7"].

  A range names every provision from its start to its end, by number or
  letter: "regs 11-14" → ["reg.11", "reg.12", "reg.13", "reg.14"];
  "art. 11(1)-(3)" → ["reg.11(1)", "reg.11(2)", "reg.11(3)"]. Ends that
  cannot be counted between (lettered numbers "2A-2D", roman numerals,
  ends at different depths) give the two ends.
  """
  @spec refs(String.t() | nil) :: [String.t()]
  def refs(nil), do: []

  def refs(text) do
    @refs
    |> Regex.scan(String.replace(text, @adding, ""), capture: :all_names)
    |> Enum.flat_map(&named/1)
  end

  # the captures by name, in name order: kind, n, n_to, para, para_to, pt,
  # sch, sch_to
  defp named([kind, n, to, "", "", "", "", ""]) when kind != "",
    do: span("#{prefix(kind)}.", n, to)

  defp named([_, _, _, "", _, _, "", _]), do: []
  defp named([_, _, _, para, to, _pt, "", _]), do: span("sch.para.", para, to)
  defp named([_, _, _, "", _, "", sch, to]), do: span("sch.", sch, to)
  defp named([_, _, _, "", _, pt, sch, _]), do: ["sch.#{sch}.pt.#{pt}"]
  defp named([_, _, _, para, to, _pt, sch, _]), do: span("sch.#{sch}.para.", para, to)

  # "11" to "14" → 11, 12, 13, 14; "11(1)" to "(3)" → 11(1), 11(2), 11(3)
  defp span(prefix, from, ""), do: [prefix <> from]

  defp span(prefix, from, to) do
    {stem, first} = last_part(from)

    case between(first, to) do
      nil -> [prefix <> from | far_end(prefix, stem, first, to)]
      parts -> Enum.map(parts, &(prefix <> stem <> &1))
    end
  end

  # "11(1)" → {"11", "(1)"}; "11" → {"", "11"}
  defp last_part(from) do
    case Regex.run(~r/^(.*)(\([^)]+\))$/u, from) do
      [_, stem, last] -> {stem, last}
      nil -> {"", from}
    end
  end

  # the end's own ref, when it stands at the start's depth
  defp far_end(prefix, stem, first, to) do
    if String.starts_with?(first, "(") == String.starts_with?(to, "("),
      do: [prefix <> stem <> to],
      else: []
  end

  defp between("(" <> _ = from, "(" <> _ = to) do
    with [_, a] <- Regex.run(~r/^\(([^()]+)\)$/u, from),
         [_, b] <- Regex.run(~r/^\(([^()]+)\)$/u, to),
         [_ | _] = parts <- counted(a, b) do
      Enum.map(parts, &"(#{&1})")
    else
      _ -> nil
    end
  end

  defp between(from, to), do: numbers(from, to)

  defp counted(a, b), do: numbers(a, b) || letters(a, b)

  defp numbers(a, b) do
    with {x, ""} <- Integer.parse(a),
         {y, ""} <- Integer.parse(b),
         true <- x < y and y - x <= @longest do
      Enum.map(x..y, &Integer.to_string/1)
    else
      _ -> nil
    end
  end

  # "(c)" to "(e)"; never letters that may be roman numerals ("(i)" to "(v)")
  defp letters(<<a>>, <<b>>) when a in ?a..?z and b in ?a..?z and a < b do
    if roman?(a) and roman?(b), do: nil, else: Enum.map(a..b, &<<&1>>)
  end

  defp letters(_, _), do: nil

  defp roman?(char), do: char in ~c"ivxlc"

  @doc ~S"""
  The one provision named ("s. 47(1)" → "s.47(1)"; "Sch. 5 para. 3" →
  "sch.5.para.3"), nil for any other form.
  """
  @spec ref(String.t() | nil) :: String.t() | nil
  def ref(nil), do: nil

  def ref(text) do
    cond do
      m = Regex.run(~r/^\s*(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, kind, rest] = m
        "#{prefix(kind)}.#{rest}"

      m = Regex.run(~r/^\s*Sch\.\s*(\d+[A-Z]*)\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, sch, para] = m
        "sch.#{sch}.para.#{para}"

      true ->
        nil
    end
  end

  defp prefix("art" <> _), do: "reg"
  defp prefix("reg" <> _), do: "reg"
  defp prefix(_), do: "s"
end
