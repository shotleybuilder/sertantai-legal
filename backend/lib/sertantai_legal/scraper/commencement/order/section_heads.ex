defmodule SertantaiLegal.Scraper.Commencement.Order.SectionHeads do
  @moduledoc """
  A commencement order's "in section N—" heading over its items: "in
  section 86 (contaminated land: …)– (i) in subsection (2), paragraph (f);
  and (ii) subsection (1) in so far as it relates to that paragraph" (SI
  2004/2528 art.2(q)) — the heading names where, never an item, and each
  line under it is that section's. Pure text.
  """

  alias SertantaiLegal.Scraper.Commencement.Order.Asides

  @brackets ~S"(?:\([0-9A-Za-z]+\))+"
  @section_head ~r/^\W*in\s+section\s+(\d+[A-Z]*)\s*[—–:-]?\s*$/iu
  @in_subsection ~r/^\W*in\s+sub-?section\s+(#{@brackets})\s*,\s*paragraphs?\s+((?:#{@brackets}\s*(?:,|and|to|–)?\s*)+)(.*)$/isu
  @subsections ~r/^\W*sub-?sections?\s+((?:#{@brackets}\s*(?:,|and|to|–)?\s*)+)(.*)$/isu

  @doc """
  Each line with the words to read it by: "" for a heading, "subsections
  (2)(f) of section 86" for a line under it, the line itself for any other.
  """
  @spec read([String.t()]) :: [{String.t(), String.t()}]
  def read(lines), do: lines |> Enum.map_reduce(nil, &line/2) |> elem(0)

  defp line(line, section) do
    case {head(line), section && item(line, section)} do
      {n, _} when is_binary(n) -> {{line, ""}, n}
      {nil, read} when is_binary(read) -> {{line, read}, section}
      _ -> {{line, line}, nil}
    end
  end

  defp head(line) do
    case Regex.run(@section_head, Asides.strip(line)) do
      [_, n] -> n
      nil -> nil
    end
  end

  # nil for a line that is no subsection of the heading's
  defp item(line, n) do
    case {Regex.run(@in_subsection, line), Regex.run(@subsections, line)} do
      {[_, sub, paragraphs, rest], _} -> of_section(sub <> String.trim(paragraphs), n, rest)
      {nil, [_, list, rest]} -> of_section(String.trim(list), n, rest)
      _ -> nil
    end
  end

  defp of_section(list, n, rest), do: "subsections #{list} of section #{n} #{rest}"
end
