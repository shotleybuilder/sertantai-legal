defmodule SertantaiLegal.Scraper.Commencement.Order.SectionHeads do
  @moduledoc """
  A commencement order's "in section N—" heading over its items: "in
  section 86 (contaminated land: …)– (i) in subsection (2), paragraph (f);
  and (ii) subsection (1) in so far as it relates to that paragraph" (SI
  2004/2528 art.2(q)) — the heading names where, never an item, and each
  line under it is that section's. So too "section 6 (…) as follows— (i)
  subsection (1) so far as …" (SI 2015/1938 art.2(a)) and "subsection (1)
  of section 8 (…) as follows— (i) so far as it inserts section 40E …" (SI
  2016/1007 art.2(b)): a line below that names no provision is the
  heading's provision so far as the line says, and an open "subsection (1)
  so far as it— (aa) substitutes section 110A" carries to its lines. Pure
  text.
  """

  alias SertantaiLegal.Scraper.Commencement.Text.Asides

  @brackets ~S"(?:\([0-9A-Za-z]+\))+"
  @section_head ~r/^\W*in\s+section\s+(\d+[A-Z]*)\s*[—–:-]?\s*$/iu
  @in_subsection ~r/^\W*in\s+sub-?section\s+(#{@brackets})\s*,\s*paragraphs?\s+((?:#{@brackets}\s*(?:,|and|to|–)?\s*)+)(.*)$/isu
  @as_follows ~r/^\W*(?:sub-?section\s+(#{@brackets})\s+of\s+)?section\s+(\d+[A-Z]*)\b(?:\s*\([^)]*\))?\s+as\s+follows\s*[—–:.]?\s*$/iu
  @open ~r/\bso\s+far\s+as\s+(?:it|they)\s*[—–:]?\s*$/iu
  @names_provision ~r/^\W*(?:in\s+|the\s+following\s+)?(?:sub-?)?(?:sections?|schedules?|paragraphs?|parts?|articles?|regulations?)\b/iu
  @subsections ~r/^\W*sub-?sections?\s+((?:#{@brackets}\s*(?:,|and|to|–)?\s*)+)(.*)$/isu

  @doc """
  Each line with the words to read it by: "" for a heading, "subsections
  (2)(f) of section 86" for a line under it, the line itself for any other.
  """
  @spec read([String.t()]) :: [{String.t(), String.t()}]
  def read(lines), do: lines |> Enum.map_reduce(nil, &line/2) |> elem(0)

  # the heading in force: nil, {:in, n} or {:follows, n, provision words}
  defp line(line, head) do
    case {head(line), head && under(line, head)} do
      {%{} = new, _} -> {{line, ""}, new}
      {nil, {read, next}} -> {{line, read}, next}
      _ -> {{line, line}, nil}
    end
  end

  defp head(line) do
    stripped = Asides.strip(line)

    case {Regex.run(@section_head, stripped), Regex.run(@as_follows, line)} do
      {[_, n], _} -> %{n: n, of: nil, follows: false}
      {nil, [_, "", n]} -> %{n: n, of: "section #{n}", follows: true}
      {nil, [_, sub, n]} -> %{n: n, of: "subsections #{sub} of section #{n}", follows: true}
      _ -> nil
    end
  end

  # a line under the heading: {its words, the heading after it}, or nil
  defp under(line, head) do
    case {item(line, head.n), head.follows} do
      {read, _} when is_binary(read) -> opened(line, read, head)
      {nil, true} -> so_far(line, head)
      _ -> nil
    end
  end

  # "subsection (1) so far as it—": its lines below are that subsection's
  defp opened(line, read, head) do
    if head.follows and line =~ @open,
      do: {"", %{head | of: String.replace(read, @open, "")}},
      else: {read, head}
  end

  defp so_far(line, head) do
    if line =~ @names_provision or head.of == nil,
      do: nil,
      else: {"#{String.trim(head.of)} #{so_far_words(line)}", head}
  end

  # (the sections a limit names are the amended law's — "substitutes
  # section 110A": the limit is read as a part, its sections never refs)
  defp so_far_words(line) do
    cond do
      line =~ ~r/\bsections?\s+\d/iu -> "(for certain purposes)"
      line =~ ~r/^\W*(?:in\s+)?so\s+far\s+as\b/iu -> line
      true -> "so far as it #{line}"
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
