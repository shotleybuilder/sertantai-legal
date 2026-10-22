defmodule SertantaiLegal.Scraper.ApplicationClause do
  @moduledoc """
  A law's **application** — where it operates — from whole-instrument
  application clauses in its own text (live status parse session,
  2026-09-28). Extent (the legal system a law forms part of) is
  `ExtentResolver`'s; application can be narrower: "These Regulations extend
  to England and Wales but apply only in relation to Wales".

  Pure. Clauses come from LAT provision text (`ExtentBackfill` reads them at
  each LAT persist, alongside extent clauses), so no extra fetch is needed and
  the LRT parser never reads full text. The result is stored on the law as
  `application_clause` and survives a lean-LAT discard.

  Regions are E, W, S, NI (as `LiveStatus`).
  """

  @instrument "(?:regulations|order|act|rules|scheme|measure|byelaws)"
  @nations [
    {"UNITED KINGDOM", ~w(E W S NI)},
    {"GREAT BRITAIN", ~w(E W S)},
    {"NORTHERN IRELAND", ~w(NI)},
    {"ENGLAND", ~w(E)},
    {"WALES", ~w(W)},
    {"SCOTLAND", ~w(S)}
  ]
  @order ~w(E W S NI)
  @qualifier ~r/\b(except|excepted|save|other than|purposes|subject to|modifications?|as (?:it|they) appl(?:y|ies)|outside)\b/i

  @type clause :: {:apply | :exclude, [String.t()]}

  @doc """
  The whole-instrument application clause in a provision's text, or nil.

  Counts: "These Regulations / This Order / This Act … [shall] [only] apply(ies)
  [only] (in relation) to|in X", the application half of "… extend to X but
  apply only in relation to Y", and "They apply in X" when the same text names
  the instrument ("These Regulations may be cited as …"). "… do not apply to
  X" is an exclusion. Partial subjects ("This regulation", "Regulation 4 of
  these Regulations", "Part 2 of this Act") and qualified or comparative
  targets ("subject to …", "as they apply in …", "every harbour area in …")
  give nil.
  """
  @spec parse(String.t() | nil) :: clause() | nil
  def parse(nil), do: nil

  def parse(text) when is_binary(text) do
    subject =
      "(?:(?<prefix>\\S+\\s+)?(?:these|this)\\s+#{@instrument}\\b(?:\\s+(?:shall\\s+)?extends?\\s+to\\s+[^.;—]*?\\s+(?:and|but)\\b)?|(?<as>\\bas\\s+)?(?<they>\\bthey))"

    regex =
      Regex.compile!(
        "#{subject}\\s+(?:shall\\s+|do\\s+|does\\s+)?(?<not>not\\s+)?(?:only\\s+)?appl(?:y|ies)\\s+(?:only\\s+)?(?:in\\s+relation\\s+to|as\\s+respects|to|in)\\s+(?<target>[^.;—]*)(?<stop>[.;—]|$)",
        "iu"
      )

    with {start, _} <- match_start(regex, text),
         c = Regex.named_captures(regex, text),
         false <- String.downcase(String.trim(c["prefix"] || "")) == "of",
         false <- c["they"] != "" and (c["as"] != "" or not names_instrument?(text)),
         false <- c["stop"] == "—",
         false <- qualified_before?(text, start),
         [_ | _] = regions <- nation_list(c["target"]) do
      {if(c["not"] == "", do: :apply, else: :exclude), regions}
    else
      _ -> nil
    end
  end

  defp match_start(regex, text) do
    case Regex.run(regex, text, return: :index) do
      [{start, len} | _] -> {start, len}
      _ -> nil
    end
  end

  # "Subject to regulation 8, these Regulations …": the clause is qualified.
  defp qualified_before?(text, start) do
    before = text |> binary_part(0, start) |> String.split(~r/[.;:]|\(\d+\)/) |> List.last()
    Regex.match?(@qualifier, before || "")
  end

  # The target must be a list of nations ("England only", "England and
  # Wales", "Great Britain"), optionally followed by "and …" extras (e.g.
  # "and the areas specified in regulation 6"). Anything else — "the
  # compulsory purchase of land in England", "premises … outside Great
  # Britain", "Scotland subject to …" — is not a whole-instrument application.
  @nation "(?:the\\s+)?(?:united\\s+kingdom|great\\s+britain|northern\\s+ireland|england|wales|scotland)"
  @nation_list Regex.compile!(
                 "^\\s*(?<list>#{@nation}(?:\\s*(?:,|and|or)\\s*#{@nation})*)\\s*(?:only)?\\s*(?:$|,?\\s+(?:and|together\\s+with|including)\\s+(?!#{@nation})(?<extra>.*)$)",
                 "iu"
               )

  defp nation_list(target) do
    with %{"list" => list} = c <- Regex.named_captures(@nation_list, target),
         false <- Regex.match?(@qualifier, c["extra"] || "") do
      regions(list)
    else
      _ -> nil
    end
  end

  @doc """
  A whole-instrument clause with the date it takes effect (change vocabulary
  C6): "From 1st January 2021 these Regulations apply in Northern Ireland
  only, in relation to any emissions …" → `{{:apply, ["NI"]}, ~D[2021-01-01]}`.
  A leading "From <date>" is the date (nil when none). A remainder after
  the territory that limits subject matter only ("…, in relation to any
  emissions …") is read past; "except" or "save" there is a territorial
  qualification, unread. Nil when no clause. `parse/1` (live status) is
  unchanged.
  """
  @spec parse_dated(String.t() | nil) :: {clause(), Date.t() | nil} | nil
  def parse_dated(nil), do: nil

  def parse_dated(text) do
    {date, rest} =
      case Regex.run(
             ~r/^\s*From\s+(\d{1,2})(?:st|nd|rd|th)?\s+([A-Z][a-z]+)\s+(\d{4}),?\s+(.*)$/su,
             text
           ) do
        [_, d, m, y, rest] -> {date(d, m, y), rest}
        nil -> {nil, text}
      end

    clause =
      parse(rest) ||
        case Regex.run(~r/^(.*?\bappl(?:y|ies)\b[^,]*?),\s*(in relation to\b.*)$/su, rest) do
          [_, head, tail] ->
            if tail =~ ~r/\b(?:except|save)\b/i, do: nil, else: parse(head <> ".")

          nil ->
            nil
        end

    if clause, do: {clause, date}
  end

  @months ~w(january february march april may june july august september october november december)

  defp date(d, m, y) do
    case Enum.find_index(@months, &(&1 == String.downcase(m))) do
      nil -> nil
      i -> Date.new!(String.to_integer(y), i + 1, String.to_integer(d))
    end
  end

  @doc """
  A clause confining one provision to a territory (change vocabulary C6):
  "This regulation applies in relation to England only" → `{:apply, ["E"]}`.
  Only a provision's own subject ("This regulation / section / article /
  rule"); nil otherwise.
  """
  @spec parse_provision(String.t() | nil) :: clause() | nil
  def parse_provision(nil), do: nil

  def parse_provision(text) do
    case Regex.run(
           ~r/^\s*(?:\(\w+\)\s*)?This\s+(?:regulation|section|article|rule)\s+(?:shall\s+)?(?:only\s+)?appl(?:y|ies)\s+(?:only\s+)?(?:in\s+relation\s+to|in|to|as\s+respects)\s+(England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)(?:\s+only)?\s*[.;]/iu,
           text
         ) do
      [_, place] -> {:apply, place |> String.upcase() |> place_regions()}
      nil -> nil
    end
  end

  defp place_regions("ENGLAND AND WALES"), do: ~w(E W)

  defp place_regions(place),
    do: Enum.find_value(@nations, fn {n, codes} -> if n == place, do: codes end)

  @doc """
  A law's application regions from its clauses: agreeing application clauses
  give their regions; an exclusion is taken from the extent regions; none, or
  disagreeing clauses, give nil.
  """
  @spec resolve([clause()], [String.t()] | nil) :: [String.t()] | nil
  def resolve(clauses, extent_regions) do
    applies = for {:apply, r} <- clauses, uniq: true, do: r
    excludes = for {:exclude, r} <- clauses, reduce: [], do: (acc -> acc ++ r)

    cond do
      length(applies) == 1 -> hd(applies)
      length(applies) > 1 -> nil
      excludes != [] and extent_regions -> nil_if_empty(sort(extent_regions -- excludes))
      true -> nil
    end
  end

  defp names_instrument?(text),
    do: Regex.match?(Regex.compile!("\\b(?:these|this)\\s+#{@instrument}\\b", "i"), text)

  # Longest names first, removed as matched ("NORTHERN IRELAND" ⊄ "IRELAND").
  defp regions(target) do
    upper = String.upcase(target)

    {found, _} =
      Enum.reduce(@nations, {[], upper}, fn {name, codes}, {acc, rest} ->
        if String.contains?(rest, name),
          do: {acc ++ codes, String.replace(rest, name, "")},
          else: {acc, rest}
      end)

    sort(found)
  end

  defp sort(regions), do: Enum.filter(@order, &(&1 in regions))

  defp nil_if_empty([]), do: nil
  defp nil_if_empty(l), do: l
end
