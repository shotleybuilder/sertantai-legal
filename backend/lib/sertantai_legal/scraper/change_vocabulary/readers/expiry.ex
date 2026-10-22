defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Expiry do
  @moduledoc """
  A law's own sunset, and the orders continuing it, as removals — primary
  (change vocabulary CV-04; Jason 2026-10-22). Coronavirus Act 2020:

  - **The sunset** (s.89(1)): "This Act expires at the end of the period of
    2 years beginning with the day on which it is passed" — every section
    is removed on the day after that period ends (2022-03-25), except those
    the next subsection lists ("Subsection (1) does not apply to— sections
    59 to 70; this Part; … section 8 so far as relating to those Parts"):
    wholly, or — "so far as" — in part (`:repealed_in_part`).
  - **A continuation order** (SR 2023/140 art.2): "Section 78 of the
    Coronavirus Act 2020 does not expire at the time when it would
    otherwise expire and expires instead on 24th March 2024" — for the
    order's territory, the section is removed the day after that date
    instead; the sunset then takes the other territories. The latest order
    for a section and territory governs.

  Each removal is the law's own (`by`: the law; its `changed_by` is none,
  D1). Claims (source `:law_text`): `operation`, `level` `:provision`,
  `date`, `territory`, `clause` (the sunset provision, or the order), `by`.
  The law's provisions (`xml`; its passing date from its EnactmentDate
  unless given), its title and the
  continuation orders (`%{law, text, territory}`) come in as data. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Ref}
  alias SertantaiLegal.Scraper.Territory

  @numbers %{"one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5, "six" => 6}
  @sunset ~r/\bThis Act expires at the end of the period of (\w+) (years?|months?) beginning with the day on which it is passed\b/i
  @continued ~r/\bSections?\s+([^.]+?)\s+of the ([^.]+?)\s+(?:does|do) not expire at the time when (?:it|they) would otherwise expire and expires? instead on (\d{1,2})(?:st|nd|rd|th)?\s+([A-Z][a-z]+)\s+(\d{4})/u

  @type continuation :: %{law: String.t(), text: String.t(), territory: String.t() | nil}

  @doc "Claim sets `{key, target, claims}` for the law's sunset and its continuations."
  @spec read(String.t(), String.t(), Date.t() | nil, String.t() | nil, [continuation()]) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(xml, law, passed, title, continuations) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    # when it was passed: given, else its own document's EnactmentDate
    passed = passed || enacted(doc)

    case passed && sunset(doc, law) do
      {clause_id, period} ->
        changes(doc, law, Date.shift(passed, period), clause_id, title, continuations)

      _ ->
        []
    end
  end

  defp enacted(doc) do
    with d when d != "" <-
           doc |> xpath(~x"//*[local-name()='EnactmentDate']/@Date"s) |> to_string(),
         {:ok, date} <- Date.from_iso8601(d) do
      date
    else
      _ -> nil
    end
  end

  # the provision stating the sunset, and its period
  defp sunset(doc, law) do
    Enum.find_value(xpath(doc, ~x"//*[@id]"l), fn el ->
      text = el |> own() |> Doc.text()

      case Regex.run(@sunset, text) do
        [_, n, unit] ->
          k = Map.get(@numbers, String.downcase(n)) || String.to_integer(n)
          period = if unit =~ ~r/^year/i, do: [year: k], else: [month: k]

          id = el |> xpath(~x"./@id"s) |> to_string()

          if Ref.from_clml(id, law),
            do:
              {id, period}
              |> then(fn {id, p} -> if Ref.from_clml(id, law), do: {id, p} end)

        nil ->
          nil
      end
    end)
  end

  defp changes(doc, law, expires, clause_id, title, continuations) do
    extent =
      doc |> xpath(~x"/*/@RestrictExtent"s) |> to_string() |> Territory.normalize() || "E+W+S+NI"

    {wholly, partly} = exceptions(doc, clause_id, law)
    continued = continued(continuations, title)
    clause = Ref.from_clml(clause_id, law)

    for ref <- sections(doc, law),
        not Enum.any?(wholly, &RefList.covers?(&1, ref)),
        change <-
          section_changes(ref, law, expires, extent, clause, partly, Map.get(continued, ref, %{})),
        do: change
  end

  defp section_changes(ref, law, expires, extent, clause, partly, continued) do
    operation =
      if Enum.any?(partly, &RefList.covers?(&1, ref)), do: :repealed_in_part, else: :repealed

    rest = Territory.subtract(extent, Territory.union(Map.keys(continued)) || "")

    sunset =
      if rest,
        do: [{"#{law}:expiry:#{ref}", ref, claims(operation, expires, rest, clause, law)}],
        else: []

    sunset ++
      for {territory, {date, order}} <- continued do
        {"#{law}:expiry:#{ref}:#{territory}", ref, claims(operation, date, territory, order, law)}
      end
  end

  defp claims(operation, date, territory, clause, law) do
    key = "#{law}:expiry"

    Enum.concat([
      Claim.new(:law_text, :operation, operation, key),
      Claim.new(:law_text, :level, :provision, key),
      Claim.new(:law_text, :date, date, key),
      Claim.new(:law_text, :territory, territory, key),
      Claim.new(:law_text, :clause, clause, key),
      Claim.new(:law_text, :by, law, key)
    ])
  end

  # the law's sections (top level)
  defp sections(doc, law) do
    for id <- xpath(doc, ~x"//*[@id]/@id"sl),
        id =~ ~r/^section-\d+[A-Z]*$/,
        ref = Ref.from_clml(id, law),
        uniq: true,
        do: ref
  end

  # "Subsection (1) does not apply to— …": the items, wholly or "so far as"
  defp exceptions(doc, clause_id, law) do
    # the section holding the sunset subsection ("section-89")
    section = clause_id |> String.split("-") |> Enum.take(2) |> Enum.join("-")

    lines =
      case xpath(doc, ~x"//*[@id='#{section}']"l) do
        [el | _] -> Doc.lines(el)
        [] -> []
      end

    items =
      lines
      |> Enum.drop_while(&(not (&1 =~ ~r/\bdoes not apply to\b/i)))
      |> Enum.drop(1)
      |> Enum.take_while(&(not (&1 =~ ~r/^\s*(?:\(?\d+\)?\s+)?[A-Z][a-z]+ [a-z]+ .*\bmay\b/u)))

    part = part_of(doc, section, law)

    Enum.reduce(items, {[], []}, fn line, {wholly, partly} ->
      refs = RefList.parse(line) ++ if(line =~ ~r/\bthis Part\b/i, do: part, else: [])

      if line =~ ~r/\bso far as\b/i do
        # "Parts 2 to 5 of Schedule 7, and section 8 so far as relating to those Parts"
        {wholly, partly ++ refs}
      else
        {wholly ++ refs, partly}
      end
    end)
  end

  # the sections of the Part holding the sunset section ("this Part")
  defp part_of(doc, section, law) do
    case xpath(doc, ~x"//*[local-name()='Part'][.//*[@id='#{section}']]"l) do
      [part | _] ->
        for id <- xpath(part, ~x".//*[@id]/@id"sl),
            id =~ ~r/^section-\d+[A-Z]*$/,
            ref = Ref.from_clml(id, law),
            do: ref

      [] ->
        []
    end
  end

  # each section's latest continuation per territory: {expiry day, order}
  defp continued(continuations, title) do
    for %{law: order, text: text, territory: t} <- continuations,
        t != nil,
        [_, list, act, d, m, y] <- Regex.scan(@continued, text || ""),
        same_act?(act, title),
        ref <- RefList.parse("sections " <> list),
        date = Date.add(date!(d, m, y), 1),
        reduce: %{} do
      acc ->
        Map.update(acc, ref, %{t => {date, order}}, fn by_t ->
          Map.update(by_t, t, {date, order}, fn {d0, o0} ->
            if Date.compare(date, d0) == :gt, do: {date, order}, else: {d0, o0}
          end)
        end)
    end
  end

  defp same_act?(_act, nil), do: true

  # titles compared without a year (the register holds "Coronavirus Act";
  # the order cites "the Coronavirus Act 2020"); the orders are the law's
  # own feed's
  defp same_act?(act, title), do: bare(act) == bare(title)

  defp bare(t),
    do: t |> String.replace(~r/\s+\d{4}\s*$/, "") |> String.trim() |> String.downcase()

  @months ~w(january february march april may june july august september october november december)

  defp date!(d, m, y) do
    month = Enum.find_index(@months, &(&1 == String.downcase(m))) + 1
    Date.new!(String.to_integer(y), month, String.to_integer(d))
  end

  # an element's own words: not its number, title or sub-provisions
  defp own({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    kept =
      Enum.flat_map(children, fn
        {:xmlElement, name, _, _, _, _, _, attrs, _, _, _, _} = c ->
          id? = Enum.any?(attrs, &match?({:xmlAttribute, :id, _, _, _, _, _, _, _, _}, &1))
          if name in [:Pnumber, :Title] or id?, do: [], else: [own(c)]

        other ->
          [other]
      end)

    put_elem(el, 8, kept)
  end
end
