defmodule SertantaiLegal.Scraper.Amendment.Reader.ProvisionTable do
  @moduledoc """
  A repeals table of one law's provisions (CV-06a, U12): "Provision |
  Extent of repeal", each row a section and what of it goes — SI 1974/1941
  Sch. 1 ("Section 1. | Subsection (5)."), SI 1976/2005 ("Sections 28 to
  41. | The whole section in each case."), SI 1975/1012 ("Section 125. |
  In subsection (2), paragraph (h) and the words …"). The law is the one
  the table's heading names (`RepealTable`).

  Each row is restated as the law-column table's lines ("Section 1(5).",
  "In section 125, in subsection (2), …"), which `RepealTable` reads into
  targets. A qualification ("except in relation to offences committed
  before …", "so far as still in operation") stays on the line: the
  provision is repealed, its savings unread.

  Pure.
  """

  # "Section 1." / "Section 85" / "Sections 40 to 52." / "Section 9 and 10."
  @provision ~r/^Sections?\s+(\d+[A-Z]*)(?:\s+(to|and)\s+(\d+[A-Z]*))?\s*\.?\s*$/

  # a new entry in the extent cell: "… (12). Subsection (13) except …"
  @entry ~r/\.\s+(?=Subsections?\s|In\s+subsection\b|The\s+whole\b|The\s+words?\b)/

  @doc "True when a cell names a section (\"Section 3.\", \"Sections 40 to 52.\"), not a law."
  @spec provision?(String.t()) :: boolean()
  def provision?(cell), do: Regex.match?(@provision, String.trim(cell))

  @doc "The row restated as repeals-table lines; [] when the provision cell names no section."
  @spec lines(String.t(), String.t()) :: [String.t()]
  def lines(provision, extent) do
    case Regex.run(@provision, String.trim(provision)) do
      [_, n] -> extent |> entries() |> Enum.map(&line(n, &1))
      [_, n, "to", m] -> extent |> entries() |> Enum.map(&range(n, m, &1))
      [_, n, "and", m] -> for s <- [n, m], e <- entries(extent), do: line(s, e)
      nil -> []
    end
  end

  defp entries(extent) do
    extent
    |> String.split(@entry)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp range(n, m, entry) do
    if entry =~ ~r/^The\s+whole\b/i,
      do: "Sections #{n} to #{m}.",
      else: line(n, entry)
  end

  # "Subsection (5)." → "Section 1(5)."; "Subsections (11) and (12)." →
  # "Section 42(11) and (12)."; "The whole section …" → "Section 53."; any
  # other ("In subsection (2), …", "The words “…”.") → "In section 125, …"
  defp line(n, entry) do
    cond do
      entry =~ ~r/^The\s+whole\b/i ->
        "Section #{n}."

      match = Regex.run(~r/^Subsections?\s+(\(.*)$/s, entry) ->
        "Section #{n}#{Enum.at(match, 1)}"

      true ->
        "In section #{n}, #{lower_first(entry)}"
    end
  end

  defp lower_first(<<c::utf8, rest::binary>>), do: String.downcase(<<c::utf8>>) <> rest
end
