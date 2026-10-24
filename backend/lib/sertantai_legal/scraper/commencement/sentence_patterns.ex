defmodule SertantaiLegal.Scraper.Commencement.SentencePatterns do
  @moduledoc """
  A law's own commencement sentences as patterns, in the own-clause
  reader's terms (change vocabulary CV-S04; Jason 2026-10-23: "agreed order
  and approach - dont skip"). Every sentence of the law's rows saying that
  something comes into force is classed by its form and by what
  `Commencement.OwnClause` made of it; one pattern per combination:

  - `role`: a `statement` ("These Regulations come into force on …") or a
    `mention` ("before this section comes into force", "the coming into
    force of");
  - `lead`: a lead-in naming exceptions or conditions — `except_as`
    ("Except as provided in subsection (2) …"), `apart_from`, `subject_to`
    — or none;
  - `subject`: what comes into force — `whole` (this Act, these
    Regulations, they), `rest` (the remaining / preceding / other
    provisions, otherwise), `parts` (Parts, Chapters), `this` (this section),
    `named` (provisions by number), `following` (a list below), `schedules`,
    `instrument` (another instrument: a scheme, an order made under the
    law, a notice), or `other`;
  - `verb`: `shall`, `is_to` ("is to come into force"), `present`
    ("comes"), `not_until` ("shall not come into operation … until"), or
    `other`;
  - `when`: `date`, `made_relative` (incl. on the passing), `named_day`,
    `period` ("at the end of the period of two months …"), `by_order`,
    `tied`, `list` (dates in the items below), `none`;
  - `qualified`: so far as / in relation to / for the purposes of;
  - `outcome`: what the reader made of it — `law:<treatment>` (the law's
    start read from it), `rules:<treatments>` (the rules it gave), `unread`
    (a group it couldn't resolve), or `none`.

  An example is the law's rows the reading needs — the provision holding
  the sentence and every row stating a commencement, with their text; the
  others' ids only — and the law's metadata the start is decided from, so
  it reads alone as in the law (`read/3`); a law's examples share one
  input (`merge/2`). Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}
  alias SertantaiLegal.Scraper.LawStart.Clause

  @cif ~r/\b(?:comes?|came|coming|be\s+brought|brought)\s+into\s+(?:force|operation)\b/i
  @lead [
    except_as: ~r/^(?:\(\w+\)\s*)?(?:except|save)\s+(?:as|in\s+so\s+far\s+as|so\s+far\s+as)\b/i,
    apart_from: ~r/^(?:\(\w+\)\s*)?apart\s+from\b/i,
    subject_to: ~r/^(?:\(\w+\)\s*)?subject\s+to\b/i
  ]
  @verb ~r/\b(shall\s+not|shall|is\s+to|are\s+to|will|may)?\s*(?:,[^,]{0,160},\s*)?(?:comes?|came|be\s+brought)\s+into\s+(?:force|operation)\b/i
  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? of|in relation to|with respect to|to the extent|for (?:specified|certain) purposes)\b/i

  @type form :: %{
          role: String.t(),
          lead: String.t(),
          subject: String.t(),
          verb: String.t(),
          when: String.t(),
          qualified: boolean()
        }

  @doc "Every sentence of `rows` saying something comes into force: `{row section_id, sentence}`, in order."
  @spec sentences([map()]) :: [{String.t(), String.t()}]
  def sentences(rows) do
    for row <- rows,
        s <- Clause.sentences(Map.get(row, :text)),
        Regex.match?(@cif, s),
        do: {row.section_id, s}
  end

  @doc "Whether text says something comes into force (a row worth keeping in an example)."
  @spec commencement_words?(String.t() | nil) :: boolean()
  def commencement_words?(nil), do: false
  def commencement_words?(text), do: Regex.match?(@cif, text)

  @doc "A sentence's form (see the moduledoc)."
  @spec form(String.t()) :: form()
  def form(s) do
    {head, tail} =
      case Regex.split(@cif, s, parts: 2) do
        [h, t] -> {h, t}
        [h] -> {h, ""}
      end

    %{
      role: if(Clause.mention?(s), do: "mention", else: "statement"),
      lead: lead(s),
      subject: subject(head),
      verb: verb(s),
      when: when_(tail),
      qualified: Regex.match?(@qualified, s)
    }
  end

  defp lead(s),
    do: Enum.find_value(@lead, "none", fn {k, re} -> if Regex.match?(re, s), do: to_string(k) end)

  defp subject(head) do
    h =
      String.replace(
        head,
        ~r/^(?:\(\w+\)\s*)?(?:subject\s+to|except\s+as|save\s+as|apart\s+from)[^,]*,\s*/i,
        ""
      )

    cond do
      # another instrument's coming into force: a scheme, an order or
      # regulations made under the law, a notice, a direction …
      h =~
          ~r/^\s*(?:\(\w+\)\s*)?(?:an?|any|the|such|no|each|every)\s+(?:[\w-]+\s+){0,3}(?:order|orders|scheme|schemes|notice|notices|direction|directions|prohibition|code|plan|strategy|byelaws?|arrangements?|determination|designation|licence|agreement|guidance|rules|charging\s+scheme|regulations\s+(?:under|made))\b/i ->
        "instrument"

      h =~
          ~r/\b(?:remaining|remainder|other\s+provisions|preceding|rest\s+of)\b|^\s*(?:\(\w+\)\s*)?otherwise\b/i ->
        "rest"

      h =~ ~r/\bthe\s+following\b/i ->
        "following"

      h =~ ~r/\bthis\s+(?:section|regulation|article|rule|paragraph|Schedule)\b/i ->
        "this"

      h =~ ~r/\b(?:sections?|regulations?|articles?|rules?|paragraphs?)\s+\(?\d/i ->
        "named"

      h =~ ~r/\b(?:Parts?|Chapters?)\s+[\dIVXL]/ or h =~ ~r/\bthis\s+Part\b/i ->
        "parts"

      h =~ ~r/\bSchedules?\b/ ->
        "schedules"

      h =~
          ~r/\b(?:this|these|the)\s+(?:Act|Regulations|Order|Rules|Measure|Scheme|instrument)\b|^\s*(?:\(\w+\)\s*)?(?:they|it)\b/i ->
        "whole"

      true ->
        "other"
    end
  end

  defp verb(s) do
    cond do
      s =~ ~r/\bshall\s+not\s+(?:come|be\s+brought)\s+into\s+(?:force|operation)\b.*\buntil\b/is ->
        "not_until"

      true ->
        case Regex.run(@verb, s) do
          [_, v | _] when v != "" ->
            v
            |> String.downcase()
            |> String.replace(~r/\s+/, "_")
            |> then(&if(&1 in ~w(is_to are_to), do: "is_to", else: &1))

          _ ->
            if s =~ ~r/\bcomes?\s+into\b/i, do: "present", else: "other"
        end
    end
  end

  defp when_(tail) do
    t = String.trim(tail)

    cond do
      t =~ ~r/^[,\s]*(?:as\s+follows|on\s+the\s+following\s+dates?)?\s*[—–:-]?\s*$/u ->
        "list"

      Clause.by_order?(t) ->
        "by_order"

      t =~ ~r/\bat\s+the\s+same\s+time\s+as\b|\bimmediately\s+(?:after|before)\b/i ->
        "tied"

      t =~ ~r/\b(?:IP|implementation period)\s+completion\s+day\b|\bexit\s+day\b/i ->
        "named_day"

      t =~
          ~r/\b(?:end|expiry|expiration)\s+of\s+(?:the\s+)?(?:period|\d|two|three|six|one)\b|\bend\s+of\s+\d{4}\b/i ->
        "period"

      t =~ ~r/\b(?:passing|passed|made|making|Royal\s+Assent)\b/i ->
        "made_relative"

      Clause.date_at_start(String.replace(t, ~r/^(?:[^,]{0,60}?\b)?(?:on|from)\s+/i, "")) ->
        "date"

      t =~ ~r/\b\d{1,2}(?:st|nd|rd|th)?\s+[A-Z][a-z]+\s+\d{4}\b/ ->
        "date"

      true ->
        "none"
    end
  end

  @doc """
  What the reader made of `sentence` from its reading of the law
  (`OwnClause.read/2`): the outcome class and its rules, one readable line
  each (`Rule.to_text/1` without the source), sorted.
  """
  @spec outcome(String.t(), map()) :: %{class: String.t(), rules: [String.t()]}
  def outcome(sentence, %{law: law, rules: rules, unread: unread}) do
    s = squash(sentence)
    from = Enum.filter(rules, &(squash(&1.source.text) == s))
    unread? = Enum.any?(unread, &(squash(&1.text) == s))

    class =
      cond do
        from != [] and Enum.any?(from, &(&1.scope == :all)) ->
          "law:" <> (from |> Enum.find(&(&1.scope == :all)) |> Map.get(:treatment) |> to_string())

        from != [] ->
          "rules:" <>
            (from
             |> Enum.map(&to_string(&1.treatment))
             |> Enum.uniq()
             |> Enum.sort()
             |> Enum.join("+"))

        squash(law.text) == s ->
          "law:" <> to_string(law.treatment)

        unread? ->
          "unread"

        true ->
          "none"
      end

    %{class: class, rules: from |> Enum.map(&line/1) |> Enum.sort()}
  end

  # a rule's readable form without its source
  defp line(%Rule{} = r), do: r |> Rule.to_text() |> String.split(" — #{r.source.law} ") |> hd()

  @doc "The pattern keys of one sentence: its form and outcome as one key."
  @spec key(form(), String.t()) :: String.t()
  def key(f, class),
    do:
      Enum.join(
        [
          f.role,
          f.lead,
          f.subject,
          f.verb,
          f.when,
          if(f.qualified, do: "qualified", else: "plain"),
          class
        ],
        "|"
      )

  @doc """
  An example: the input the reader needs to read `sentence` of the law, at
  a pruning `level` — `:tight` (the rows stating a commencement and the
  sentence's provision, with their text; every whole provision's id),
  `:named` (also the rows of provisions those rows name by number), `:ids`
  (every row's id; text only where it has commencement words), `:full`
  (every row) — and the law's metadata (`input` from
  `ChangeCollector.law_start_input/2`, its CLML head cut to what `LawStart`
  reads). Rows are compact: `[ref, text, part, chapter]`, trailing nils
  dropped, the law's prefix left off. The caller keeps the smallest level
  that reads as the whole law does.
  """
  @spec example(String.t(), map(), :tight | :named | :ids | :full) :: map()
  def example(row_id, input, level) do
    base = provision(row_id)
    statement? = &(Map.get(&1, :text) |> statements?())

    numbers =
      input.rows
      |> Enum.filter(statement?)
      |> Enum.flat_map(&(Regex.scan(~r/\b\d+[A-Z]*\b/, &1.text) |> List.flatten()))
      |> MapSet.new()

    # (a comprehension's `x = false` would filter: the tests sit in `keep`)
    keep = fn r ->
      top = provision(r.section_id)
      text? = top == base or statement?.(r)

      keep? =
        level in [:ids, :full] or text? or top == r.section_id or
          (level == :named and MapSet.member?(numbers, top |> String.split(".") |> List.last()))

      words? = level == :ids and commencement_words?(Map.get(r, :text))
      {keep?, text? or words? or level == :full}
    end

    rows =
      for r <- input.rows,
          {true, text?} <- [keep.(r)],
          do: compact(r, text?)

    %{
      "type_code" => input.type_code,
      "lrt_date" => input.lrt_date && Date.to_iso8601(input.lrt_date),
      "made" => input.made && Date.to_iso8601(input.made),
      "tied_date" => input[:tied_date] && Date.to_iso8601(input.tied_date),
      "clml_head" => head(input.clml_head || ""),
      "rows" => rows
    }
  end

  @doc """
  One input for a law's examples: the law's metadata and the union of the
  rows they keep (a row's text where any keeps it), in the law's order —
  stored once per law (`laws.json`). The caller checks each example still
  reads alone as in the law.
  """
  @spec merge(map(), [map()]) :: map()
  def merge(input, examples) do
    kept = for ex <- examples, [ref | rest] <- ex["rows"], into: %{}, do: {ref, rest}

    text? =
      for ex <- examples, [ref, text | _] <- ex["rows"], text != nil, into: MapSet.new(), do: ref

    rows =
      for r <- input.rows,
          ref = bare(r.section_id),
          Map.has_key?(kept, ref),
          do: compact(r, MapSet.member?(text?, ref))

    examples |> hd() |> Map.put("rows", rows)
  end

  # a row's text says something comes into force, not only mentions it
  defp statements?(nil), do: false

  defp statements?(text),
    do:
      text
      |> Clause.sentences()
      |> Enum.any?(&(Regex.match?(@cif, &1) and not Clause.mention?(&1)))

  defp compact(r, text?) do
    [bare(r.section_id), if(text?, do: r.text), r[:part], r[:chapter]]
    |> Enum.reverse()
    |> Enum.drop_while(&is_nil/1)
    |> Enum.reverse()
  end

  defp bare(sid), do: sid |> String.split(":", parts: 2) |> List.last()

  @doc "An example's input back as `LawStart.input()` (schedule tables aren't kept)."
  @spec input(String.t(), map()) :: map()
  def input(law, ex) do
    %{
      type_code: ex["type_code"],
      lrt_date: date(ex["lrt_date"]),
      made: date(ex["made"]),
      tied_date: date(ex["tied_date"]),
      clml_head: ex["clml_head"],
      schedule_tables: %{},
      rows:
        for(
          r <- ex["rows"],
          [ref, text, part, chapter] = r ++ List.duplicate(nil, 4 - length(r)),
          do: %{section_id: "#{law}:#{ref}", text: text, part: part, chapter: chapter}
        )
    }
  end

  @doc "What the reader makes of the example's sentence."
  @spec read(String.t(), map(), String.t()) :: %{class: String.t(), rules: [String.t()]}
  def read(law, ex, sentence), do: outcome(sentence, OwnClause.read(law, input(law, ex)))

  # the CLML head's parts LawStart reads: Royal Assent, coming into force,
  # the made date, EU identity and entry into force
  defp head(head) do
    [
      ~r{<ukm:EnactmentDate[^>]*/>},
      ~r{<ukm:ComingIntoForce>.*?</ukm:ComingIntoForce>}s,
      ~r{<ukm:Made[^>]*/>},
      ~r{<ukm:CELEX[^>]*/>},
      ~r{<RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE[^>]*>\s*<VALUE>[^<]*</VALUE>}
    ]
    |> Enum.flat_map(&(Regex.scan(&1, head) |> List.flatten()))
    |> Enum.join("\n")
  end

  defp date(nil), do: nil
  defp date(d), do: Date.from_iso8601!(d)

  defp squash(nil), do: nil
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
