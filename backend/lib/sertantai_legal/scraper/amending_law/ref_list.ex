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
    |> String.split(
      ~r/(?:^|[,;]|\s)\s*(?:and\s+)?(?=\b(?:this section|(?<!this\s)sections?|(?<!of\s)Schedules?|Part\s+\d)\b)/iu,
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

      m = Regex.run(~r/^\s*Part\s+(\d+[A-Z]*)\s+of\s+Schedule\s+(\d+[A-Z]*)/i, chunk) ->
        [_, part, sch] = m
        ["sch.#{sch}.pt.#{part}"]

      chunk =~ ~r/^\s*Schedules?\b/i ->
        # the item ends at its full stop ("Schedules 1, 3, 5 and 15.")
        item = chunk |> String.split(~r/\.(?:\s|$)/u, parts: 2) |> hd()
        for [_, n] <- Regex.scan(~r/\b(\d+[A-Z]*)\b/, item), do: "sch.#{n}"

      chunk =~ ~r/^\s*sections?\b/i ->
        section_items(chunk)

      true ->
        []
    end
  end

  # "sections 60 to 68, 70, 107(1) and (4)": ranges as "s.60..s.68",
  # subsections on the number before them
  defp section_items(chunk) do
    chunk
    |> String.replace(~r/^\s*sections?\s*/i, "")
    |> String.split(~r/\s*(?:,|\band\b)\s*/u, trim: true)
    |> Enum.reduce({[], nil}, fn piece, {acc, last} ->
      cond do
        m = Regex.run(~r/^(\d+[A-Z]*)(\([^)]+\))*\s+to\s+(\d+[A-Z]*)/, piece) ->
          [_, a | rest] = m
          {acc ++ ["s.#{a}..s.#{List.last(rest)}"], a}

        m = Regex.run(~r/^(\d+[A-Z]*)((?:\([^)]+\))*)/, piece) ->
          [_, n, sub] = m
          {acc ++ ["s.#{n}#{sub}"], n}

        last && Regex.match?(~r/^\(/, piece) ->
          [subs] = Regex.run(~r/^(?:\([^)]+\))+/, piece)
          {acc ++ ["s.#{last}#{subs}"], last}

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
      ["s." <> a, "s." <> b] ->
        case Regex.run(~r/^s\.(\d+)/, ref) do
          [_, n] -> number(a) <= String.to_integer(n) and String.to_integer(n) <= number(b)
          nil -> false
        end

      [single] ->
        ref == single or String.starts_with?(ref, single <> "(") or
          String.starts_with?(ref, single <> ".")
    end
  end

  defp number(s), do: s |> Integer.parse() |> elem(0)
end
