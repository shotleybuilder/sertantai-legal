defmodule SertantaiLegal.Scraper.EnactedBy.EnablingProvisions do
  @moduledoc """
  The specific enabling provisions an SI was made under, from its enacting
  text ("in exercise of the powers conferred by sections 82 and 219(2) of the
  Water Resources Act 1991 f00001 …"), which the LRT enacted_by stage already
  fetches (the introduction, not the body).

  An SI can reach only as far as the provisions that empower it, so the
  extent of those sections (from the parent Act's LAT, `EnablingExtent`) is a
  precise bound — unlike the parent Act's overall extent (WRA 1991 is GB;
  its Part III, including s.82, is E+W).

  Pure. Only the powers clause counts: from "powers conferred" to "and (of)
  all other powers" / "hereby"; later references ("under section 11(2)(d) of
  the 1974 Act") are purpose, not powers. Each Act reference is an inline
  footnote/citation marker resolved through the `urls` map; when a marker
  names several laws, the one whose year matches "… Act YYYY" is taken.
  Section numbers are the base numbers ("219(2)" → "219"; "(3)(a)" continues
  the previous section); "paragraphs … of Schedule 3 to" gives schedule "3".
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed

  @type provision :: %{law: String.t(), sections: [String.t()], schedules: [String.t()]}

  @marker ~r/\b([fc]\d{5})\b/

  # a defined term after a title: "Act 1974 (“ the 1974 Act ”)"
  @defined_term ~r/\(\s*[“"]\s*the\s+[^”"()]*[”"]\s*\)/u

  @doc """
  Enabling provisions per parent law, in clause order. `titles` (lower-case
  "title year" → law name) resolves an Act the clause names in plain words,
  with no citation marker ("… of, the European Communities Act 1972.";
  CV-07), and one it refers back to ("… of, that Act"; "that section").
  """
  @spec parse(String.t() | nil, map(), %{String.t() => String.t()}) :: [provision()]
  def parse(text, urls, titles \\ %{})
  def parse(nil, _urls, _titles), do: []

  def parse(text, urls, titles) do
    case powers_clause(text) do
      nil ->
        []

      {clause, before} ->
        clause
        |> String.replace(@defined_term, " ")
        |> chunks()
        |> Enum.flat_map(fn
          {chunk, nil} -> by_title(chunk, titles, before)
          {chunk, marker} -> provision(chunk, Map.get(urls, marker, []))
        end)
    end
  end

  @doc """
  Every "the … Act YYYY" the text names, as lower-case "title year": each
  "the" before an "Act YYYY" gives one, and the register lookup keeps those
  it knows ("the Pyrotechnic … Regulations 2010, section 2(2) of the
  European Communities Act 1972" → "european communities act 1972" among
  them). Over the whole text: an Act named before the clause can be
  referred back to.
  """
  @spec titles(String.t() | nil) :: [String.t()]
  def titles(nil), do: []

  def titles(text) do
    Regex.scan(~r/\bAct\s+\d{4}\b/u, text, return: :index)
    |> Enum.flat_map(fn [{i, l}] ->
      upto = binary_part(text, 0, i + l)

      Regex.scan(~r/\bthe\s+(?=[A-Z])/u, upto, return: :index)
      |> Enum.map(fn [{j, jl}] ->
        upto |> binary_part(j + jl, byte_size(upto) - j - jl) |> String.downcase()
      end)
    end)
    |> Enum.uniq()
  end

  # text with no marker: each piece ending "Act YYYY" names its Act by
  # title; a piece referring back ("that Act", "that section", "the said
  # section") takes the Act, or the section, named before the clause
  defp by_title(chunk, titles, before) do
    chunk
    |> String.split(~r/(?<=\bAct\s\d{4})/u)
    |> Enum.flat_map(fn piece ->
      case title_law(piece, titles) do
        nil -> referred(piece, titles, before)
        law -> found(law, piece)
      end
    end)
  end

  # the shortest "the … Act YYYY" ending the piece that the register knows
  defp title_law(piece, titles) do
    piece
    |> String.trim()
    |> String.trim_trailing(",")
    |> String.trim()
    |> titles()
    |> Enum.reverse()
    |> Enum.find_value(&Map.get(titles, &1))
  end

  defp referred(piece, titles, before) do
    last_act = before |> titles() |> Enum.reverse() |> Enum.find_value(&Map.get(titles, &1))

    cond do
      last_act == nil ->
        []

      piece =~ ~r/\bthat\s+section\b/u ->
        case Regex.scan(~r/\bsection\s+(\d+[A-Z]*)/u, before) do
          [] ->
            []

          named ->
            [%{law: last_act, sections: [named |> List.last() |> List.last()], schedules: []}]
        end

      piece =~ ~r/\bthat\s+Act\b|\bthe\s+said\s+section\b/u ->
        found(last_act, String.replace(piece, ~r/\bthe\s+said\s+section/u, "section"))

      true ->
        []
    end
  end

  defp found(law, piece) do
    sections = sections(piece)
    schedules = schedules(piece)

    if sections != [] or schedules != [],
      do: [%{law: law, sections: sections, schedules: schedules}],
      else: []
  end

  # The powers clause and the text before it: from "powers conferred" (or
  # "the power conferred", "his powers under", "in pursuance of") up to "and
  # (of) all other powers" / "hereby" / ", is pleased" / ", having" / "and
  # for the purpose", or its sentence's end ("… Act 2018 . In accordance
  # with …"; not "etc. Act")
  defp powers_clause(text) do
    case Regex.run(
           ~r/\b(?:powers?\s+conferred|powers?\s+under|in\s+pursuance\s+of)\b/iu,
           text,
           return: :index
         ) do
      [{start, len}] ->
        rest = binary_part(text, start + len, byte_size(text) - start - len)

        clause =
          rest
          |> String.split(
            ~r/\b(?:and\s+)?(?:of\s+)?all\s+other\s+powers\b|\bhereby\b|,\s*is\s+pleased\b|,\s*having\b|\band\s+for\s+the\s+purposes?\b/iu,
            parts: 2
          )
          |> hd()
          |> String.split(~r/(?<!\betc)\s*\.\s+(?=[A-Z])/u, parts: 2)
          |> hd()

        {clause, binary_part(text, 0, start)}

      _ ->
        nil
    end
  end

  # Split the clause after each marker: [{text before marker, marker}]
  defp chunks(clause) do
    parts = Regex.split(@marker, clause, include_captures: true)

    # the text after the last marker (or a clause with none) is a chunk
    # with no marker: its Act is named in plain words
    parts
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [chunk, marker] -> [{chunk, marker}]
      [tail] -> [{tail, nil}]
    end)
  end

  defp provision(chunk, uris) do
    with [_, year] <- Regex.run(~r/\bAct\s+(\d{4})\s*$/u, String.trim(chunk)),
         law when is_binary(law) <- pick_law(uris, year),
         sections = sections(chunk),
         schedules = schedules(chunk),
         true <- sections != [] or schedules != [] do
      [%{law: law, sections: sections, schedules: schedules}]
    else
      _ -> []
    end
  end

  defp pick_law(uris, year) do
    uris
    |> Enum.map(&ChangesFeed.law_name/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.find(&String.contains?(&1, "_#{year}_"))
  end

  # The section list: after the last "section(s)" up to " of" — base numbers
  # of items that start with a digit ("(3)(a)" continues the previous one).
  defp sections(chunk) do
    case Regex.run(~r/\bsections?\s+(.*?)\s+of\b/isu, last_from(chunk, ~r/\bsections?\b/iu)) do
      [_, list] ->
        ~r/(?:^|[\s,])(\d+[A-Z]*)(?=[\s(,]|$)/u
        |> Regex.scan(list)
        |> Enum.map(fn [_, n] -> n end)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  # "paragraphs … of Schedule 3 to"; several Schedules before one "to"
  # ("paragraph 1 of Schedule 4 and paragraph 21 of Schedule 7 to")
  defp schedules(chunk) do
    ~r/\bSchedules?\s+(\d+[A-Z]*)\b(?=[^.;]*?\bto\b)/iu
    |> Regex.scan(chunk)
    |> Enum.map(fn [_, n] -> n end)
    |> Enum.uniq()
  end

  # The chunk from the last match of `regex` onward (a chunk can carry the
  # previous Act's trailing words: "… f00001 and sections 15 and 43 of …").
  defp last_from(chunk, regex) do
    case Regex.scan(regex, chunk, return: :index) do
      [] ->
        chunk

      matches ->
        matches
        |> List.last()
        |> hd()
        |> then(fn {i, _} -> binary_part(chunk, i, byte_size(chunk) - i) end)
    end
  end
end
