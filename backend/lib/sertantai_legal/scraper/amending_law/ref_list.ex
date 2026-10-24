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

  @doc "The refs a list names; `self` is \"this section\"'s ref."
  @spec parse(String.t(), String.t() | nil) :: [String.t()]
  def parse(text, self \\ nil) do
    text
    # a qualified aside names nothing whole ("Schedule 2 (and article 26 so
    # far as relating to it)": CV-S05 N14)
    |> String.replace(
      ~r/\([^()]*\b(?:so\s+far|in\s+so\s+far|insofar|to\s+the\s+extent)\b[^()]*\)/iu,
      " "
    )
    |> String.split(
      ~r/(?:^|[,;]|\s)\s*(?:and\s+)?(?=\b(?:this section|(?<!this\s)(?:sections?|regulations?|articles?|rules?)|(?<!of\s)Schedules?|Parts?\s+[\dIVXL]+[A-Z]*(?:\s*(?:,|and)\s*[\dIVXL]+[A-Z]*)*\s+of\s+Schedule|paragraphs?\s+[^;]*?\bof\s+Schedule)\b)/iu,
      trim: true
    )
    |> Enum.flat_map(&items(&1, self))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp items(chunk, self) do
    cond do
      chunk =~ ~r/^\s*this section/i ->
        [self]

      # "Parts 4 and 5 of Schedule 13" (CV-S05 N12)
      m =
          Regex.run(
            ~r/^\s*Parts?\s+([\dIVXL]+[A-Z]*(?:\s*(?:,|and)\s*[\dIVXL]+[A-Z]*)*)\s+of\s+Schedule\s+(\d+[A-Z]*)/i,
            chunk
          ) ->
        [_, parts, sch] = m
        for [p] <- Regex.scan(~r/[\dIVXL]+[A-Z]*/, parts), do: "sch.#{sch}.pt.#{p}"

      # "paragraphs 5, 35 and 41 to 43 of Schedule 23" (CV-S05 N12)
      m = Regex.run(~r/^\s*paragraphs?\s+(.*?)\s+of\s+Schedule\s+(\d+[A-Z]*)/i, chunk) ->
        [_, list, sch] = m
        numbered(list, "sch.#{sch}.para.")

      chunk =~ ~r/^\s*Schedules?\b/i ->
        # the item ends at its full stop or a bracket ("Schedules 1, 3, 5
        # and 15.", "Schedule 2 (and article 26 …)": CV-S05 N14)
        item = chunk |> String.split(~r/\.(?:\s|$)|\(/u, parts: 2) |> hd()

        case Regex.run(~r/^\s*Schedule\s+(\d+[A-Z]*)\s*,\s*paragraphs?\s+(.*)$/i, item) do
          # "Schedule 14, paragraph 5"
          [_, sch, list] -> numbered(list, "sch.#{sch}.para.")
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

  defp schedule_numbers(item) do
    item
    |> String.replace(~r/^\s*Schedules?\s*/iu, "")
    |> String.split(~r/\s*(?:,|\band\b)\s*/u, trim: true)
    |> Enum.flat_map(fn piece ->
      case Regex.run(~r/^(\d+)\s+to\s+(\d+)$/, String.trim(piece)) do
        [_, a, b] -> for i <- String.to_integer(a)..String.to_integer(b)//1, do: "sch.#{i}"
        nil -> for [_, n] <- Regex.scan(~r/\b(\d+[A-Z]*)\b/, piece), do: "sch.#{n}"
      end
    end)
  end

  # "60 to 68, 70, 107(1) and (4), 26(7) to (10)": ranges as "x.60..x.68",
  # subsections on the number before them, a subsection range spelt out
  defp numbered(list, prefix) do
    list
    |> String.split(~r/\s*(?:,|\band\b)\s*/u, trim: true)
    |> Enum.reduce({[], nil}, fn piece, {acc, last} ->
      cond do
        # "26(7) to (10)" → each subsection (CV-S05 N12)
        m = Regex.run(~r/^(\d+[A-Z]*)\((\d+)\)\s+to\s+\((\d+)\)/, piece) ->
          [_, n, a, b] = m

          {acc ++
             for(i <- String.to_integer(a)..String.to_integer(b)//1, do: "#{prefix}#{n}(#{i})"),
           n}

        m = Regex.run(~r/^(\d+[A-Z]*)(\([^)]+\))*\s+to\s+(\d+[A-Z]*)/, piece) ->
          [_, a | rest] = m
          {acc ++ ["#{prefix}#{a}..#{prefix}#{List.last(rest)}"], a}

        m = Regex.run(~r/^(\d+[A-Z]*)((?:\([^)]+\))*)/, piece) ->
          [_, n, sub] = m
          {acc ++ ["#{prefix}#{n}#{sub}"], n}

        last && Regex.match?(~r/^\(/, piece) ->
          [subs] = Regex.run(~r/^(?:\([^)]+\))+/, piece)
          {acc ++ ["#{prefix}#{last}#{subs}"], last}

        true ->
          {acc, last}
      end
    end)
    |> elem(0)
  end

  @doc "Whether a list item (a ref or a range \"s.a..s.b\") names `ref` or contains it."
  @spec covers?(String.t(), String.t()) :: boolean()
  def covers?(item, ref) do
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
