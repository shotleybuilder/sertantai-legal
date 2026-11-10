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

  # a piece ends at an Act named ("… Act 1995") or referred back to ("…
  # of that Act")
  @powers ~r/\b(?:powers?\s+conferred|powers?\s+under|in\s+pursuance\s+of)\b/iu

  # where the powers clause ends: "and (of) all (every) other (the)
  # power(s)",
  # "hereby", ", is pleased", ", having", "and for the purpose(s)", "makes
  # the following" (SI 2008/912), "for the purpose of giving effect …" and
  # "independently of any proposals …" (a purpose: SI 2014/1637, 2010/93),
  # or a new statement after a semicolon
  # ("…; He is a Minister designated …", SI 2006/3223; "…; b for the
  # purposes of giving effect …", SI 2014/1639) — never a list's "; sections
  # 85(1) …" or "; and c section 23(1)(b) …"
  @clause_end ~r/\b(?:and\s+)?(?:of\s+)?(?:all|every)\s+(?:other|the)\s+powers?\b|\bhereby\b|,\s*is\s+pleased\b|,\s*having\b|\band\s+for\s+the\s+purposes?\b|\bmakes?\s+the\s+following\b|\bfor\s+the\s+purposes?\s+of\s+giving\s+effect\b|\bindependently\s+of\b|;\s+(?:[a-z]{1,3}\s+)?(?:(?=[A-Z])|for\s+the\s+purposes?\b)/u

  @cites ~r/\b(?:Act|Order|Regulations|Rules|Measure)\s+\d{4}$/u

  @act_end ~r/(?<=\bAct\s\d{4})|(?<=\bthat\sAct)|(?<=\bthe\s\d{4}\sAct)/u

  # an Act's short name, defined after its title and marker: "Act 1972
  # f00001 (“the ECA 1972”)"
  @short_name ~r/\bAct\s+(\d{4})\s+([fc]\d{5})\s*\(\s*[“"]\s*(the\s+[^”"()]*?)\s*[”"]\s*\)/u
  # (the match starts at "Act": the title is read from the words before it)

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
        |> short_names(before <> clause)
        |> String.replace(@defined_term, " ")
        |> chunks()
        |> Enum.flat_map_reduce(before, fn {chunk, marker}, so_far ->
          {read_chunk(chunk, marker, titles, {so_far, urls}),
           so_far <> chunk <> " " <> (marker || "")}
        end)
        |> elem(0)
    end
  end

  # (the context: the text read so far, before the chunk, and the markers'
  # URIs — what "that Act" and "the said section" refer back to)
  defp read_chunk(chunk, nil, titles, context), do: by_title(chunk, titles, context)

  defp read_chunk(chunk, marker, titles, {_, urls} = context),
    do: cited(chunk, Map.get(urls, marker, []), titles, context)

  # a chunk ending at an Act's marker: the Act cited last is the marker's;
  # an Act named in plain words before it in the chunk is by title ("by
  # section 2(2) of the European Communities Act 1972 and by sections
  # 185(2C) … of the Merchant Shipping Act 1995 f00005": SI 2016/1061)
  defp cited(chunk, uris, titles, context) do
    {earlier, last} = chunk |> String.split(@act_end) |> split_last_act()
    by_title(Enum.join(earlier), titles, context) ++ marked(last, uris, titles, context)
  end

  # a marker naming no law of the year cited is a footnote on another (the
  # Act that amended it: "section 2(2) of, as read with paragraph 1A of
  # Schedule 2 to, the European Communities Act 1972 f00005", f00005 the
  # 2006 Act: SI 2007/1711): the Act by title
  defp marked(last, uris, titles, context) do
    case provision(last, uris) do
      [] -> by_title(last, titles, context)
      found -> found
    end
  end

  # a short name the text defines for an Act ("Act 1972 f00001 (“the ECA
  # 1972”)") cited in the clause ("section 2(2) of the ECA 1972": SI
  # 2017/585) → the Act's title and marker; a term naming an Act ("the
  # 1974 Act", "the Act") is read where it is cited
  defp short_names(clause, text) do
    @short_name
    |> Regex.scan(text, return: :index)
    |> Enum.map(fn [{at, _}, year, marker, term] ->
      {binary_part(text, 0, at), part(text, year), part(text, marker), part(text, term)}
    end)
    |> Enum.reject(fn {_before, _year, _marker, term} -> term =~ ~r/\bAct\b/u end)
    |> Enum.reduce(clause, fn {before, year, marker, term}, c ->
      Regex.replace(
        ~r/\b#{term_words(term)}\b(?!\s*[”"])/u,
        c,
        "the #{title(before)}Act #{year} #{marker}"
      )
    end)
  end

  defp part(text, {at, len}), do: binary_part(text, at, len)

  # a term as cited, its year spaced or not ("the PPCA1999" cited "the
  # PPCA 1999": WSI 2016/691)
  defp term_words(term),
    do: term |> Regex.escape() |> String.replace(~r/(?<=\D)(\d{4})$/u, "\\s*\\1")

  # the title's words before "Act" at the definition: from its last
  # "the" followed by title words only
  defp title(before) do
    case Regex.run(~r/\bthe\s+((?:(?:[A-Z][\w,.'()-]*|and|of|at|for|in|on|etc\.)\s+)+)$/u, before) do
      [_, words] -> words
      nil -> ""
    end
  end

  # the pieces before the last one ending "Act YYYY", and that one (where
  # none does, the chunk is all plain words: "… 306A of that Act, article 2
  # of the … Order 1996 f00002", SI 2023/246)
  defp split_last_act(pieces) do
    case pieces |> Enum.with_index() |> Enum.filter(fn {p, _} -> p =~ ~r/\bAct\s\d{4}$/u end) do
      [] ->
        {pieces, ""}

      acts ->
        acts |> List.last() |> elem(1) |> then(&{Enum.take(pieces, &1), Enum.at(pieces, &1)})
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
  # section") takes the Act, or the section, named before it
  defp by_title(chunk, titles, {so_far, urls}) do
    chunk
    |> String.split(@act_end)
    |> Enum.flat_map_reduce(so_far, fn piece, read ->
      found =
        case title_law(piece, titles) do
          nil -> referred(piece, titles, {read, urls})
          law -> found(law, piece)
        end

      {found, read <> piece}
    end)
    |> elem(0)
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

  defp referred(piece, titles, {before, _urls} = context) do
    case last_act(before, context, titles) do
      nil -> []
      last_act -> referred(piece, last_act, titles, context)
    end
  end

  defp referred(piece, last_act, titles, {before, _urls} = context) do
    cond do
      piece =~ ~r/\bthat\s+section\b/u ->
        that_section(last_act, before)

      # "by the said section 2(2) and of all other powers" (SI 1999/1704)
      piece =~ ~r/\bthe\s+said\s+sections?\b/u ->
        said(piece, last_act, titles, context)

      # "of the 1995 Act" (defined after its title: SI 2002/2201); "of the
      # said Act of 1995" (SI 1999/3281)
      year = defined_year(piece) ->
        found(act_of_year(year, before, context, titles) || last_act, piece)

      piece =~ ~r/\bthat\s+Act\b/u or (piece =~ ~r/\bthe\s+Act\b/u and defines_the_act?(before)) ->
        found(last_act, piece)

      true ->
        []
    end
  end

  defp that_section(law, before) do
    case Regex.scan(~r/\bsection\s+(\d+[A-Z]*)/u, before) do
      [] -> []
      named -> [%{law: law, sections: [named |> List.last() |> List.last()], schedules: []}]
    end
  end

  # each said section of the Act it was last named in ("section 2(2) of the
  # European Communities Act 1972 f00003 … the said section 2(2)": SI
  # 2004/1266), else of the Act named last
  defp said(piece, last_act, titles, context) do
    ~r/\bsaid\s+sections?\s+(\d+[A-Z]*)/u
    |> Regex.scan(piece)
    |> Enum.map(fn [_, n] -> {said_act(n, titles, context) || last_act, n} end)
    |> Enum.uniq()
    |> Enum.map(fn {law, n} -> %{law: law, sections: [n], schedules: []} end)
  end

  defp said_act(n, titles, {before, _} = context) do
    case Regex.scan(~r/\bsection\s+#{n}(?![\dA-Z])[^;]*?\bAct\s+\d{4}/u, before, return: :index) do
      [] ->
        nil

      named ->
        named
        |> List.last()
        |> hd()
        |> then(fn {i, l} ->
          last_act(binary_part(before, 0, i + l) <> marker_after(before, i + l), context, titles)
        end)
    end
  end

  defp marker_after(text, at) do
    case Regex.run(
           ~r/^(?:\s*\([^()]*\))?\s+([fc]\d{5})\b/u,
           binary_part(text, at, byte_size(text) - at)
         ) do
      [m, _] -> m
      _ -> ""
    end
  end

  defp defined_year(piece) do
    case Regex.run(~r/\bthe\s+(?:(\d{4})\s+Act\s*$|said\s+Act\s+of\s+(\d{4})\b)/u, piece) do
      [_, year] -> year
      [_, "", year] -> year
      _ -> nil
    end
  end

  # the Act of `year` named last in the text so far
  defp act_of_year(year, before, context, titles) do
    case Regex.scan(~r/\bAct\s+#{year}\b/u, before, return: :index) do
      [] ->
        nil

      named ->
        named
        |> List.last()
        |> hd()
        |> then(fn {i, l} ->
          last_act(binary_part(before, 0, i + l) <> marker_after(before, i + l), context, titles)
        end)
    end
  end

  # "the Merchant Shipping Act 1970 f00001 (hereinafter called “the Act”)"
  defp defines_the_act?(before), do: before =~ ~r/[“"]\s*the\s+Act\s*[”"]/u

  # the Act named last in `text`: by its marker where one follows it ("…
  # Act 2018 f00002": SI 2022/241, its title worded unlike the register's;
  # after its defined term: "Act 1972 (“the 1972 Act ”) f00002"),
  # else by title; else the last Act the register knows
  defp last_act(text, {_, urls}, titles) do
    case Regex.scan(~r/\bAct\s+(\d{4})(?:\s*\([^()]*\))?(?:\s+([fc]\d{5}))?/u, text,
           return: :index
         ) do
      [] ->
        nil

      named ->
        [{i, l} | groups] = List.last(named)
        by_marker(text, groups, urls) || title_law(binary_part(text, 0, i + l), titles)
    end || text |> titles() |> Enum.reverse() |> Enum.find_value(&Map.get(titles, &1))
  end

  defp by_marker(text, [{y, yl}, {m, ml}], urls) when m >= 0,
    do: pick_law(Map.get(urls, binary_part(text, m, ml), []), binary_part(text, y, yl))

  defp by_marker(_text, _groups, _urls), do: nil

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
    case Regex.run(@powers, text, return: :index, offset: operative(text)) do
      [{start, len}] ->
        rest = binary_part(text, start + len, byte_size(text) - start - len)

        clause =
          rest
          |> String.split(
            @clause_end,
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

  # where the recitals end ("Whereas … ; Now, therefore, the Secretary of
  # State, in exercise of the powers conferred …"): a recital's "in pursuance
  # of section 82(2)" or "made in exercise of powers conferred by section 85"
  # is no powers clause (SI 2004/3363, 1996/2821), where one follows
  defp operative(text) do
    with [{at, _}] <- Regex.run(~r/\bNow,?\s+therefore\b/iu, text, return: :index),
         true <- Regex.match?(@powers, binary_part(text, at, byte_size(text) - at)) do
      at
    else
      _ -> 0
    end
  end

  # Split the clause after each marker: [{text before marker, marker}]
  defp chunks(clause) do
    parts = Regex.split(@marker, clause, include_captures: true)

    # the text after the last marker (or a clause with none) is a chunk
    # with no marker: its Act is named in plain words
    parts
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [chunk, marker] -> {chunk, marker}
      [tail] -> {tail, nil}
    end)
    |> join_uncited()
  end

  # a marker not after "Act YYYY" (or another instrument: "… Order 1978
  # f00003", SI 2010/160 (NI)) cites no Act (an amendment's footnote, the
  # Treasury's consent: "… section 306A of that Act, and with the consent of
  # the Treasury f00002"; "sections 185(2C) f00003 and 306A f00004 of …"):
  # its text runs on into the next chunk
  defp join_uncited([{chunk, marker}, {next, next_marker} | rest]) when is_binary(marker) do
    if String.trim(chunk) =~ @cites,
      do: [{chunk, marker} | join_uncited([{next, next_marker} | rest])],
      else: join_uncited([{chunk <> " " <> next, next_marker} | rest])
  end

  defp join_uncited([{chunk, marker} | rest]), do: [{chunk, marker} | join_uncited(rest)]
  defp join_uncited([]), do: []

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
    case Regex.run(~r/\bsections?\s+(.*?)\s+of\b/isu, section_run(chunk)) do
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

  # The chunk from the last "section(s)" onward, back over a run of them
  # ("section 85(1) to (1B), (3) and (5) to (7), section 86(1), section
  # 302(1) and section 306A of": SI 2018/155)
  defp section_run(chunk) do
    starts =
      ~r/\bsections?\b/iu |> Regex.scan(chunk, return: :index) |> Enum.map(fn [{i, _}] -> i end)

    case Enum.reverse(starts) do
      [] ->
        chunk

      [last | earlier] ->
        binary_part(
          chunk,
          run_start(chunk, last, earlier),
          byte_size(chunk) - run_start(chunk, last, earlier)
        )
    end
  end

  defp run_start(chunk, at, [prev | earlier]) do
    gap = binary_part(chunk, prev, at - prev)

    # (never back over "the said section 2(2) and sections 15 …": another
    # Act's, SI 1999/3232)
    if gap =~ ~r/^sections?\s+[\w()\s,]*?(?:,|\band)\s*$/iu and not (gap =~ ~r/\bof\b/iu) and
         not said?(chunk, prev),
       do: run_start(chunk, prev, earlier),
       else: at
  end

  defp run_start(_chunk, at, []), do: at

  defp said?(chunk, at), do: binary_part(chunk, 0, at) =~ ~r/\bsaid\s*$/u
end
