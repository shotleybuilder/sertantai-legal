defmodule SertantaiLegal.Scraper.AmendingLaw.RefList do
  @moduledoc """
  A list of provisions as a law's own text writes it, as LAT refs — the one
  reader of such lists for the change vocabulary (an Act's extent clause:
  `AmendingLaw.Extent`; its sunset exceptions: `Readers.Expiry`).

  "sections 1 to 54 and 56 to 58, 107(1) and (4) and 108, section 123,
  Schedules 1, 3, 5 and 15, Part 2 of Schedule 10, this section" →
  `["s.1..s.54", "s.56..s.58", "s.107(1)", "s.107(4)", "s.108", "s.123",
  "sch.1", "sch.3", "sch.5", "sch.15", "sch.10.pt.2", <this section>]`.
  A range is "s.a..s.b"; `covers?/2` tests a ref against an item. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.SubPath

  @doc "The refs a list names; `self` is \"this section\"'s (\"this article\", …) ref."
  @spec parse(String.t(), String.t() | nil) :: [String.t()]
  def parse(text, self \\ nil) do
    text
    |> unnumbered_schedule()
    |> companions_last()
    |> owned()
    |> own_relative(self)
    # a qualified aside names nothing whole ("Schedule 2 (and article 26 so
    # far as relating to it)": CV-S05 N14)
    |> String.replace(
      ~r/\([^()]*\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b[^()]*\)/iu,
      " "
    )
    |> String.split(
      ~r/(?:^|[,;]|\s)\s*(?:and\s+)?(?=\b(?:this\s+(?:section|article|regulation|rule)\b|(?<!this\s)(?:sections?|regulations?|articles?|rules?)|(?<!of\s)Schedules?|(?<!of\s)Parts?\s+[\dIVXL]+[A-Z]*(?:\s*(?:,|and|or)\s*(?:or\s+)?[\dIVXL]+[A-Z]*)*\s+of\s+Schedule|paragraphs?\s+[^;]*?\bof\s+Schedule)\b)/iu,
      trim: true
    )
    |> Enum.flat_map(&items(&1, self))
    |> Enum.reject(&is_nil/1)
    |> Enum.map(&String.replace(&1, ~r/^sch\.0(?=\.|$)/, "sch"))
    |> Enum.uniq()
  end

  @doc """
  Subdivisions named before their provision, joined to it (CV-S05 round
  13, S13: found by the CV-S05d census): "subsections (1) to (6) of section
  11" → "section 11(1) to (6)" (never all of section 11, 1995/45 s.18);
  "Paragraphs (28), (29)(b) … of regulation 5" → "regulation 5(28), (29)(b)
  …" (SI 2007/1843); "sub-paragraph (2) of paragraph 3 of Schedule 1" →
  "paragraph 3(2) of Schedule 1". Or named after it as a locator: "in
  section 47, subsection (1)" → "section 47(1)" (ukpga 1993/9 s.48); "in
  regulation 16, paragraphs (4) and (5)" → "regulation 16(4) and (5)" (SI
  2020/818 reg.1A, round 13 S11).
  """
  @spec owned(String.t()) :: String.t()
  def owned(text) do
    text
    # ("in Schedule 2, Part II and paragraph 11" → "Part II of Schedule 2
    # and paragraph 11 of Schedule 2": ukpga 1977/38 s.32, round 13 S13)
    |> then(
      &Regex.replace(
        ~r/\bin\s+Schedule\s+(\d+[A-Z]*)\s*,\s*((?:Parts?|paragraphs?)\s+[^;]*?)(?=;|,\s*(?:and\s+)?in\s+Schedule\b|$)/iu,
        &1,
        fn _, sch, rest ->
          Regex.replace(
            ~r/\b((?:Parts?|paragraphs?)\s+[\dIVXL]+[A-Z]*(?:\([^)]*\))*(?:\s*(?:,|and|to)\s*[\dIVXL]+[A-Z]*(?:\([^)]*\))*)*)/iu,
            rest,
            "\\1 of Schedule #{sch}"
          )
        end
      )
    )
    |> String.replace(
      ~r/\bin\s+(section|regulation|article|rule)\s+(\d+[A-Z]*)\s*,\s*(?:sub-?section|paragraph)s?\s+(?=\()/iu,
      "\\1 \\2"
    )
    |> String.replace(
      ~r/\b(?:sub-?sections?|paragraphs?|sub-?paragraphs?)\s+((?:\([\w]+\)(?:\s*(?:,|and|or|to)\s*)?)+?)\s*(?:above\s+|below\s+)?of\s+(section|regulation|article|rule)\s+(\d+[A-Z]*)\b(?!\s*\()/iu,
      "\\2 \\3\\1"
    )
    |> String.replace(
      ~r/\bsub-?paragraphs?\s+((?:\([\w]+\)(?:\s*(?:,|and|or|to)\s*)?)+?)\s*of\s+paragraph\s+(\d+[A-Z]*)\b(?!\s*\()/iu,
      "paragraph \\2\\1"
    )
  end

  # the provision's own subdivisions named bare or "of this section":
  # "subsections (1), (3) and (6) to (10) of this section" (1977/45
  # s.65(10)), "subsections (4) and (5) above" (1977/38 s.32), "paragraphs
  # (2) and (3)" in an SI's regulation (round 13 S4, S5); never a lettered
  # "paragraph (a)" of an Act (the sentence's own items), nor a reference
  # ("subject to subsection (8)", "one falling within subsection (3)")
  defp own_relative(text, "s." <> n) do
    num = n |> String.split("(") |> hd()

    Regex.replace(
      ~r/(?<!subject\sto\s)(?<!of\s)(?<!within\s)(?<!under\s)(?<!by\s)(?<!in\s)(?<!see\s)(?<!with\s)\bsub-?sections?\s+((?>(?:\([\dA-Z]+\)(?:\s*(?:,|and|or|to)\s*(?=\())?)+))\s*(?:above\s+|below\s+)?(?:of\s+this\s+section\b)?(?!\s*of\b)/iu,
      text,
      "section #{num}\\1 "
    )
  end

  defp own_relative(text, "reg." <> n) do
    num = n |> String.split("(") |> hd()

    Regex.replace(
      ~r/(?<!subject\sto\s)(?<!of\s)(?<!within\s)(?<!under\s)(?<!by\s)(?<!in\s)(?<!see\s)(?<!with\s)\bparagraphs?\s+((?>(?:\(\d+[A-Z]*\)(?:\([a-z]+\))*(?:\s*(?:,|and|or|to)\s*(?=\())?)+))\s*(?:above\s+|below\s+)?(?:of\s+this\s+regulation\b)?(?!\s*of\b)/iu,
      text,
      "regulation #{num}\\1 "
    )
  end

  defp own_relative(text, _self), do: text

  # the law's own unnumbered Schedule ("Part I of the Schedule",
  # "paragraphs 1 and 14 of the Schedule", "the Schedule to this Act") as a
  # Schedule numbered 0, named `sch` after (`Order.ref`; CV-S05 round 13,
  # agent seed 18): only a Part or paragraph of it, never another law's
  # ("the Schedule to the X Act") nor a place in it ("the Notes at the end of
  # the Schedule")
  defp unnumbered_schedule(text),
    do:
      Regex.replace(
        ~r/(\b(?:Parts?|paragraphs?|sub-paragraphs?)\s+[\dIVXL][^,;]*?)\s+of\s+the\s+Schedule\b(?:\s+to\s+th(?:is|ese)\s+(?:Act|Order|Regulations))?(?!\s+to\s+the\b)/u,
        text,
        "\\1 of Schedule 0"
      )

  # a bracketed companion moved after the list, so the numbers after it stay
  # the list's: "sections 228, 229 (and Schedule 22), 230, 233 to 236" →
  # "sections 228, 229, 230, 233 to 236, and Schedule 22" (ukpga 2023/55
  # s.254(12), round 13 S15)
  defp companions_last(text) do
    case Regex.scan(
           ~r/\s*\((?:and|with|including)\s+((?:Schedules?|Parts?)\s+[^()]*?)\)(?=\s*,\s*\d)/iu,
           text
         ) do
      [] ->
        text

      found ->
        rest =
          Enum.reduce(found, text, fn [whole, _], acc ->
            String.replace(acc, whole, "", global: false)
          end)

        rest <> Enum.map_join(found, fn [_, inner] -> ", and " <> inner end)
    end
  end

  defp items(chunk, self) do
    cond do
      # (an Order's "this article", "This Regulation": SI 2010/708, 1999/1925)
      chunk =~ ~r/^\s*this\s+(?:section|article|regulation|rule)\b/i ->
        [self]

      # "Parts 4 and 5 of Schedule 13" (CV-S05 N12); "Part 1, 8 … or 19 of
      # Schedule 18" (round 13 S3)
      m =
          Regex.run(
            ~r/^\s*Parts?\s+([\dIVXL]+[A-Z]*(?:\s*(?:,|and|or)\s*(?:or\s+)?[\dIVXL]+[A-Z]*)*)\s+of\s+Schedule\s+(\d+[A-Z]*)/i,
            chunk
          ) ->
        [_, parts, sch] = m
        for [p] <- Regex.scan(~r/[\dIVXL]+[A-Z]*/, parts), do: "sch.#{sch}.pt.#{p}"

      # "paragraphs 11, 12, 18 and 19 of Part I of Schedule 25": the triple
      # (Jason 2026-10-27)
      m =
          Regex.run(
            ~r/^\s*paragraphs?\s+(.*?)\s+of\s+Part\s+([\dIVXL]+[A-Z]*)\s+of\s+Schedule\s+(\d+[A-Z]*)/i,
            chunk
          ) ->
        [_, list, part, sch] = m
        numbered(list, "sch.#{sch}.pt.#{part}.para.")

      # "paragraphs 5, 35 and 41 to 43 of Schedule 23" (CV-S05 N12)
      m = Regex.run(~r/^\s*paragraphs?\s+(.*?)\s+of\s+Schedule\s+(\d+[A-Z]*)/i, chunk) ->
        [_, list, sch] = m
        numbered(list, "sch.#{sch}.para.")

      # (never another law's: "the Schedule to the Health Act 2006")
      chunk =~ ~r/^\s*Schedules?\s+to\s+the\b/i ->
        []

      chunk =~ ~r/^\s*Schedules?\b/i ->
        # the item ends at its full stop or a bracket ("Schedules 1, 3, 5
        # and 15.", "Schedule 2 (and article 26 …)": CV-S05 N14)
        item = chunk |> String.split(~r/\.(?:\s|$)|\(/u, parts: 2) |> hd()

        case Regex.run(~r/^\s*Schedule\s+(\d+[A-Z]*)\s*,\s*((?:paragraphs?|Parts?)\s+.*)$/i, item) do
          # "Schedule 14, paragraph 5"; "in Schedule 2, Part II and paragraph
          # 11" (ukpga 1977/38 s.32, round 13 S13: never all of Schedule 2)
          [_, sch, rest] -> schedule_parts(sch, rest)
          # "Schedules 2 to 9, 11 and 12": each between (CV-S05)
          nil -> schedule_numbers(item)
        end

      m = Regex.run(~r/^\s*(sections?|regulations?|articles?|rules?)\b/i, chunk) ->
        prefix = if m |> Enum.at(1) |> String.downcase() =~ ~r/^section/, do: "s", else: "reg"
        numbered(String.replace(chunk, ~r/^\s*\w+\s*/u, ""), prefix <> ".")

      true ->
        []
    end
  end

  defp schedule_parts(sch, rest) do
    rest
    |> String.split(~r/\s*(?:,|\band\b)\s*(?=(?:paragraphs?|Parts?)\b)/iu, trim: true)
    |> Enum.flat_map(fn piece ->
      case Regex.run(~r/^\s*(paragraphs?|Parts?)\s+(.*)$/iu, piece) do
        [_, "P" <> _, list] ->
          for [p] <- Regex.scan(~r/[\dIVXL]+[A-Z]*/, list), do: "sch.#{sch}.pt.#{p}"

        [_, _para, list] ->
          numbered(list, "sch.#{sch}.para.")

        nil ->
          []
      end
    end)
  end

  defp schedule_numbers(item) do
    item
    |> String.replace(~r/^\s*Schedules?\s*/iu, "")
    |> String.split(~r/\s*(?:,|\band\b|\bor\b)\s*/u, trim: true)
    |> Enum.flat_map(fn piece ->
      case Regex.run(~r/^(\d+)\s+to\s+(\d+)$/, String.trim(piece)) do
        [_, a, b] -> for i <- String.to_integer(a)..String.to_integer(b)//1, do: "sch.#{i}"
        nil -> for [_, n] <- Regex.scan(~r/\b(\d+[A-Z]*)\b/, piece), do: "sch.#{n}"
      end
    end)
  end

  # "60 to 68, 70, 107(1) and (4), 26(7) to (10)": ranges as "x.60..x.68",
  # subsections on the number before them, continuing its path at their own
  # level ("2(1)(a) and (b)", "36(1), (2)(a), (b) and (d)", "(w)(i) and
  # (ii)": `SubPath`, CV-S05 round 13 S2), a subsection range spelt out
  defp numbered(list, prefix) do
    list
    |> String.split(~r/\s*(?:,|\band\b|\bor\b)\s*/u, trim: true)
    |> Enum.reduce({[], nil}, fn piece, {acc, last} ->
      cond do
        # "26(7) to (10)" → each subsection (CV-S05 N12); "8(2)(b) to (d)"
        # → each lettered item (SI 2014/469 art.3(2)(b): CV-S05 round 6)
        m =
            Regex.run(
              ~r/^(\d+[A-Z]*)((?:\([^)]+\))+)\s+to\s+((?:\([^)]+\))+)\s*(?:[.;]|\(.*)?\s*$/,
              piece
            ) ->
          [_, n, a, b] = m
          paths = SubPath.paths(a <> " to " <> b)
          {acc ++ Enum.map(paths, &ref(prefix, n, &1)), {n, List.last(paths)}}

        m = Regex.run(~r/^(\d+[A-Z]*)(\([^)]+\))*\s+to\s+(\d+[A-Z]*)/, piece) ->
          [_, a | rest] = m
          {acc ++ ["#{prefix}#{a}..#{prefix}#{List.last(rest)}"], {a, []}}

        # (a short label after a space is the number's: "34 (f)", SI
        # 2013/1506 reg.3(2); never a describing bracket)
        m =
            Regex.run(
              ~r/^(\d+[A-Z]*)(?:((?:\([^)]+\))+)|\s((?:\((?:[a-z]{1,4}|\d+[A-Z]*)\))+))?/,
              piece
            ) ->
          [n | subs] = tl(m)
          path = SubPath.labels(Enum.join(subs))
          {acc ++ [ref(prefix, n, path)], {n, path}}

        last && Regex.match?(~r/^\(/, piece) ->
          {n, path} = last
          paths = SubPath.paths(piece, path)
          {acc ++ Enum.map(paths, &ref(prefix, n, &1)), {n, List.last(paths, path)}}

        true ->
          {acc, last}
      end
    end)
    |> elem(0)
  end

  defp ref(prefix, n, path), do: prefix <> n <> Enum.map_join(path, &"(#{&1})")

  @doc """
  Whether a list item (a ref or a range "s.a..s.b") names `ref` or contains
  it. A Schedule paragraph cited without its Part names the same paragraph
  as its triple, and the reverse ("sch.4.para.3" ≡ "sch.4.pt.2.para.3":
  legislation.gov.uk's ids hold the Part only where the Schedule numbers
  each Part apart; the text seldom cites it).
  """
  @spec covers?(String.t(), String.t()) :: boolean()
  def covers?(item, ref) do
    covers_exactly?(item, ref) or
      (paragraph?(ref) and part_less?(item, ref) and
         covers_exactly?(no_parts(item), no_parts(ref)))
  end

  defp paragraph?(ref), do: ref =~ ~r/^sch(?:\.[^.]+)*\.para\./

  # one side names no Part of the paragraph's Schedule
  defp part_less?(item, ref),
    do: not (item =~ ~r/\.pt\.[^.]+\.para\./) or not (ref =~ ~r/\.pt\.[^.]+\.para\./)

  defp no_parts(ref), do: String.replace(ref, ~r/\.pt\.[^.]+(?=\.)/, "")

  defp covers_exactly?(item, ref) do
    case String.split(item, "..") do
      # a range of any kind: "s.60..s.68", "reg.3..reg.9",
      # "sch.22.para.1..sch.22.para.5"
      [lo, hi] ->
        with [_, prefix, a] <- Regex.run(~r/^(.*?)(\d+)[A-Z]*$/, lo),
             [_, ^prefix, b] <- Regex.run(~r/^(.*?)(\d+)[A-Z]*$/, hi),
             [_, n] <- Regex.run(~r/^#{Regex.escape(prefix)}(\d+)/, ref) do
          number(a) <= String.to_integer(n) and String.to_integer(n) <= number(b)
        else
          _ -> false
        end

      [single] ->
        ref == single or String.starts_with?(ref, single <> "(") or
          String.starts_with?(ref, single <> ".")
    end
  end

  defp number(s), do: s |> Integer.parse() |> elem(0)
end
