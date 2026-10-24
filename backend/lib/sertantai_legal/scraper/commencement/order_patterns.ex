defmodule SertantaiLegal.Scraper.Commencement.OrderPatterns do
  @moduledoc """
  Commencement orders' statements as patterns, in the order reader's terms
  (change vocabulary CV-S04; Jason 2026-10-23: "agreed order and approach -
  dont skip"). Every statement an order makes — an article saying
  provisions of the Act come into force, or a row of its Schedule table — is
  classed by its form and by what `Commencement.Order` made of it; one
  pattern per combination:

  - `kind`: `inline` ("Sections 17 to 22 of the Act shall come into force on
    …"), `following` (the items below: "The following provisions … —"),
    `items_first` (items, then "shall come into force on …"), `appointed`
    ("1st April 1996 is the day appointed for …"), `appointed_is` ("The
    appointed day for … is …"), `whole_act` (the Act named alone, or "Apart
    from the provisions mentioned in paragraph (2), the Act …"), `table`
    (a Schedule row), `table_header` (a row naming the columns), `own` (the
    order's own citation and commencement), `schedule_intro` (an article bringing in the provisions
    its Schedule's table lists: the rows carry the rules);
  - `when`: `date`, `made_relative`, `none`;
  - `qualified`: so far as / in relation to / for the purposes of / except;
  - `full`: so far as not already in force / for all purposes / except so
    far as already in operation;
  - `other_law`: the words name another law's provisions;
  - `outcome`: `none`, or `rules` with `+partial` (a territory or purpose)
    and `+all` (the whole Act).

  An example is the order cut to what its reading needs — its title and made
  date, its articles, the Schedule a table row is in — as XML, read alone
  as in the whole order (`read/4`). Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}

  @cif ~r/\b(?:shall\s+)?(?:comes?|come)\s+into\s+(?:force|operation)\b/i
  @appointed ~r/\bis\s+the\s+(?:day|date)\s+appointed\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i
  @appointed_is ~r/\bthe\s+(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i
  @qualified ~r/\b(?:so|in so|insofar)\s*far\s+as\b|\bto\s+the\s+extent\b|\bfor\s+the\s+purposes?\s+of\b|\bfor\s+(?:specified|certain)\s+purposes\b|\bexcept\b|\bin\s+relation\s+to\b/i
  @full ~r/\bnot\s+(?:already|previously|yet)\s+(?:been\s+)?(?:in\s+(?:force|operation)|commenced|brought)|\bfor\s+all\s+(?:remaining\s+|other\s+)?purposes\b|\bexcept\s+(?:in\s+)?so\s+far\s+as\s+(?:it\s+is\s+|they\s+are\s+)?already\b|\bexcept\s+as\s+aforesaid\b/i
  @other_law ~r/\b(?:of|to|into)\s+the\s+(?:\d{4}\s+)?(?:[A-Z][\w()',-]*\s+){1,12}(?:Act|Order|Regulations|Measure)\s+\d{4}\b/
  @made ~r/\b(?:made|making)\b/i

  @type unit :: %{kind: String.t(), id: String.t(), text: String.t()}

  @doc """
  The order's statements: each article (or paragraph) whose first line
  states a commencement, and each row of a Schedule table.
  """
  @spec units(Doc.t()) :: [unit()]
  def units(%Doc{} = doc) do
    statements =
      for id <- doc.ids,
          String.match?(id, ~r/^(?:article|regulation)-\d+[A-Z]*(?:-\d+[A-Z]*)?$/),
          line =
            doc
            |> Doc.element(id)
            |> Doc.lines()
            |> Enum.find(
              &(Regex.match?(@cif, &1) or Regex.match?(@appointed, &1) or
                  Regex.match?(@appointed_is, &1))
            ),
          is_binary(line),
          not nested?(doc, id, line),
          do: %{kind: statement_kind(line, doc, id), id: id, text: squash(line)}

    rows =
      for id <- doc.ids,
          String.match?(id, ~r/^schedule(-\d+[A-Z]*)?(?:-part-[IVXL\d]+[A-Z]?)?$/),
          el = Doc.element(doc, id),
          tr <- xpath(el, ~x".//*[local-name()='tbody']/*[local-name()='tr']"l),
          [first | _] = cells = tr |> xpath(~x"./*[local-name()='td']"l) |> Enum.map(&Doc.text/1),
          squash(first) != "",
          do: %{
            kind: row_kind(cells),
            id: id,
            text: cells |> Enum.map(&squash/1) |> Enum.join(" | ")
          }

    # a row under a Part is the Part's (its title dates it): kept once, under
    # the deepest container holding it
    rows = rows |> Enum.sort_by(&(-String.length(&1.id))) |> Enum.uniq_by(& &1.text)

    Enum.uniq_by(statements ++ rows, &{&1.id, &1.text})
  end

  # a header row names the columns, never a provision
  defp row_kind([first | _] = cells) do
    if not (first =~ ~r/\d/) and
         Enum.any?(
           cells,
           &(&1 =~ ~r/^\s*(?:Subject|Subject[- ]matter|Purpose|Extent|Provisions?|Date)\b/i)
         ),
       do: "table_header",
       else: "table"
  end

  # an article and its paragraph state it once: the paragraph's kept
  defp nested?(doc, id, line) do
    Enum.any?(doc.ids, fn other ->
      String.starts_with?(other, id <> "-") and
        String.match?(other, ~r/^(?:article|regulation)-\d+[A-Z]*-\d+[A-Z]*$/) and
        doc |> Doc.element(other) |> Doc.lines() |> Enum.any?(&(squash(&1) == squash(line)))
    end)
  end

  defp statement_kind(line, doc, id) do
    cond do
      # the order's own citation and commencement, not the Act's
      line =~
          ~r/^\W*(?:This|These)\s+(?:Order|Regulations|Rules|Scheme)\s+(?:may\s+be\s+cited|shall\s+come|comes?|come)\b|^\W*The\s+title\s+of\s+this\s+Order\b/i ->
        "own"

      # "The provisions mentioned in the first column of each of the
      # Schedules to this Order … shall come into operation— …": its rules
      # are the table rows'
      line =~
          ~r/\b(?:mentioned|specified|set\s+out)\s+in\s+(?:the\s+first\s+column\s+of\s+)?(?:each\s+of\s+)?(?:the\s+)?Schedules?\b(?:\s+\d+)?\s+to\s+this\s+Order\b/i ->
        "schedule_intro"

      Regex.match?(@appointed_is, line) ->
        "appointed_is"

      Regex.match?(@appointed, line) ->
        "appointed"

      line =~ ~r/^\W*(?:apart\s+from|except)\b/i ->
        "whole_act"

      line =~ ~r/\bthe\s+following\b/i ->
        "following"

      items_first?(doc, id, line) ->
        "items_first"

      line =~
          ~r/^\W*(?:The\s+)?[A-Z][\w()',\s-]{3,160}?(?:Act|Order)\s+\d{4}\s+(?:shall\s+)?comes?\s+into/ ->
        "whole_act"

      true ->
        "inline"
    end
  end

  defp items_first?(doc, id, line) do
    lines = doc |> Doc.element(id) |> Doc.lines()
    i = Enum.find_index(lines, &(&1 == line)) || 0
    i > 0 and lines |> Enum.take(i) |> Enum.any?(&(&1 =~ ~r/\b(?:namely|the following)\b/i))
  end

  @doc "A unit's form, the classes keyed with its outcome."
  @spec form(unit()) :: map()
  def form(%{kind: kind, text: text}) do
    %{
      kind: kind,
      when: when_(text),
      qualified: Regex.match?(@qualified, Regex.replace(@full, text, "")),
      full: Regex.match?(@full, text),
      # … or a repeals row naming another law by chapter or title ("1984 c.
      # 54 | Roads (Scotland) Act 1984 | In section 143 …")
      other_law:
        Regex.match?(@other_law, text) or
          (kind in ["table", "table_header"] and
             text =~ ~r/\b\d{4}\s+c\.\s*\d+|\|\s*[A-Z][\w(), -]+\s+(?:Act|Order)\s+\d{4}\b/)
    }
  end

  defp when_(text) do
    cond do
      text =~ ~r/\b\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]+,?\s+\d{4}\b/ -> "date"
      Regex.match?(@made, text) -> "made_relative"
      true -> "none"
    end
  end

  @doc """
  The rules the order read from `unit` (`rules`: `Order.rules/2`): an
  article's are those its id gives as their source (or its paragraph's), a
  table row's those of its Schedule whose words begin with the row's first
  cell; the outcome class and each rule's readable line (no source), sorted.
  """
  @spec outcome(unit(), [Rule.t()]) :: %{class: String.t(), rules: [String.t()]}
  def outcome(%{kind: kind, id: id, text: text}, rules) do
    ref = Order.ref(id) || id
    first = text |> String.split(" | ", parts: 2) |> hd()

    mine =
      Enum.filter(rules, fn r ->
        source = r.source.ref || ""

        case kind do
          "table" ->
            source == ref and String.starts_with?(squash(r.source.text || ""), first)

          _ ->
            (source == ref or String.starts_with?(source, ref <> "(")) and
              String.starts_with?(squash(r.source.text || ""), String.slice(text, 0, 60))
        end
      end)

    class =
      case mine do
        [] ->
          "none"

        _ ->
          "rules" <>
            if(Enum.any?(mine, &(not Rule.full?(&1))), do: "+partial", else: "") <>
            if(Enum.any?(mine, &(&1.scope == :all)), do: "+all", else: "")
      end

    %{class: class, rules: mine |> Enum.map(&line/1) |> Enum.sort()}
  end

  defp line(%Rule{} = r), do: r |> Rule.to_text() |> String.split(" — #{r.source.law} ") |> hd()

  @doc "The pattern key: the unit's form and its outcome."
  @spec key(map(), String.t()) :: String.t()
  def key(f, class) do
    flag = fn b, name -> if b, do: name, else: "-" end

    Enum.join(
      [
        f.kind,
        f.when,
        flag.(f.qualified, "qualified"),
        flag.(f.full, "full"),
        flag.(f.other_law, "other_law"),
        class
      ],
      "|"
    )
  end

  @doc """
  An example: the order as XML — its title and made date, its articles
  (whole, `:whole`; else the one defining "the Act" and the unit's own),
  and for a table row its Schedule.
  """
  @spec example(Doc.t(), unit(), :whole | :cut) :: String.t()
  def example(%Doc{} = doc, %{kind: kind, id: id}, level) do
    articles =
      for aid <- doc.ids,
          String.match?(aid, ~r/^(?:article|regulation)-\d+[A-Z]*$/),
          level == :whole or aid == top(id) or defines?(doc, aid) or
            (kind == "table" and refers_to_schedule?(doc, aid)),
          do: Doc.element(doc, aid)

    schedules =
      if kind == "table", do: [Doc.element(doc, schedule_of(doc, id))], else: []

    body = [{:Body, [], articles}]
    scheds = if schedules == [], do: [], else: [{:Schedules, [], schedules}]

    meta =
      [{:"dc:title", [], [to_charlist(title(doc) || "")]}] ++
        case made(doc) do
          nil -> []
          d -> [{:Made, [Date: to_charlist(d)], []}]
        end

    ns = [{:"xmlns:dc", ~c"http://purl.org/dc/elements/1.1/"}]

    [{:Legislation, ns, meta ++ [{:Secondary, [], body ++ scheds}]}]
    |> :xmerl.export_simple(:xmerl_xml, prolog: [])
    |> :unicode.characters_to_binary()
    |> short_effect_ids()
  end

  # legislation.gov.uk effect ids ("key-" + 32 hex) trip GitHub push
  # protection; the reader never uses them, so a fixture keeps the last 6
  defp short_effect_ids(xml),
    do: Regex.replace(~r/key-[0-9a-f]{26}([0-9a-f]{6})/, xml, "key-\\1")

  defp top(id), do: id |> String.split("-") |> Enum.take(2) |> Enum.join("-")

  defp defines?(doc, aid),
    do: doc |> Doc.element(aid) |> Doc.text() |> String.match?(~r/\bmeans\b|“the Act”|"the Act"/)

  defp refers_to_schedule?(doc, aid),
    do: doc |> Doc.element(aid) |> Doc.text() |> String.match?(~r/\bSchedule\b/)

  # the Schedule a Part of it belongs to is the element read ("schedule-1"
  # for "schedule-1-part-II": its title dates it)
  defp schedule_of(_doc, id), do: id

  defp title(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      case root
           |> xpath(
             ~x"//*[local-name()='title' and namespace-uri()='http://purl.org/dc/elements/1.1/']/text()"s
           )
           |> to_string() do
        "" -> nil
        t -> t
      end
    end)
  end

  defp made(%Doc{roots: roots}) do
    Enum.find_value(roots, fn root ->
      case root |> xpath(~x"//*[local-name()='Made']/@Date"s) |> to_string() do
        "" -> nil
        d -> d
      end
    end)
  end

  @doc "What the order reader makes of the example's unit."
  @spec read(String.t(), map(), String.t(), unit()) :: %{class: String.t(), rules: [String.t()]}
  def read(order_law, act, xml, unit) do
    doc = Doc.new(order_law, [xml])
    outcome(unit, Order.rules(doc, act))
  end

  defp squash(nil), do: ""
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()
end
