defmodule SertantaiLegal.Scraper.Commencement.Leftovers do
  @moduledoc """
  The words of a commencement statement that bear on when provisions came
  into force and that no rule read from it uses: the long tail of forms
  the readers half-read, found in code over every statement held, not by
  sampling (Jason 2026-11-05, after two agent rounds of whack-a-mole on
  Maritime Safety). Kinds:

  - `:date` — a stated date no rule's `when` holds ("… 30th November 2019"
    after a ";": SI 2018/1107);
  - `:exception` — a provision after "except", "other than", "apart from"
    or "save that" in no rule's exception (SI 2012/2267 reg.3(3)(b)), nor
    dated apart beside a rule for the rest ("save that regulations 9 and
    12(1)(b) shall come into force on …"); an order's "rest of the Act,
    except sections 85 to 87" read as those sections is one (SI 1996/3146);
  - `:provision` — a numbered provision of the law's own in no rule's
    scope or exception;
  - `:qualifier` — "in relation to", "for the purposes of", "so far as",
    "to the extent that" with no partial rule (SI 2007/3075 reg.1(a)); a
    completing "so far as not already in force", "for all other purposes"
    never counts;
  - `:relative_day` — "the 22nd day after", "laid", "notified", "the end of
    the period" with no relative rule (SI 2018/1221).

  A mention ("before regulation 2 comes into force") has none; another
  law's provisions are never the statement's own (the reader's ref
  extractor, given as `refs`, leaves them out). Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.{Order, OrderPatterns, Rule, SentencePatterns}
  alias SertantaiLegal.Scraper.LawStart.{Clause, Provisions}

  @type leftover :: %{
          kind: :date | :exception | :provision | :qualifier | :relative_day,
          words: String.t()
        }

  @months ~w(January February March April May June July August September October November December)
  @date Regex.compile!(
          "\\b\\d{1,2}\\s*(?:st|nd|rd|th)?\\s+(?:day\\s+of\\s+)?(?:#{Enum.join(@months, "|")}),?\\s+\\d{4}\\b"
        )
  @except ~r/\b(?:except(?:\s+for)?|other\s+than|apart\s+from|save\s+that)\s+([^,;]+?)(?=\s*(?:,|;|\bwhich\b|\b(?:shall|comes?|is\s+to|are\s+to)\b|$))/i
  @completing ~r/\b(?:(?:(?:in\s+)?so\s+far|insofar|to\s+the\s+extent)\s+(?:as|that)\s+(?:(?:it|they|th(?:at|ose|ese)\s+[\w-]+)\s+(?:is|are|has|have)\s+)?not\s+(?:already\s+|yet\s+|previously\s+|then\s+)?(?:been\s+)?(?:in\s+force|commenced|brought\s+into\s+force)|for\s+all\s+(?:other\s+|remaining\s+)?purposes)\b/i
  @qualifier ~r/\b(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\b/i
  @relative ~r/\bthe\s+(?:\w+\s+)?day\s+after\b|\blaid\b|\bnotified\b|\bthe\s+end\s+of\s+the\s+period\b/i

  # a power to provide for something to come into force, never a statement
  # ("… include power to provide for the provision to come into force
  # although the agreement has not come into force": MSA 1995 s.84B(10))
  @power ~r/\b(?:power|powers|may|shall)\b[^.;]{0,80}\bprovide\s+for\b[^.;]{0,120}\bto\s+come\s+into\s+(?:force|operation)\b|\bmay\s+be\s+made\s+so\s+as\s+to\s+come\s+into\b/i

  # another instrument coming into force — regulations an Act requires, a
  # code's amendments, arrangements, a notice — never the law's own
  # provisions ("The regulations required by subsection (1) must come into
  # force …": asp 2010/5 s.38(2)); "These Regulations" is the law
  @instrument ~r/^\W*(?:(?:the|any|an?|such)\s+)?(?:[\w-]+\s+){0,3}(?:regulations|orders?|schemes?|codes?(?:\s+of\s+practice)?|arrangements|amendments|notices?|directions?|byelaws|determinations?|designations?)\b(?!\s*\d|\s+of\s+this\s+(?:Act|Order))[^.;]{0,160}?\b(?:must|shall|may|will)?\s*(?:comes?|come)\s+into\b/i

  # a pointer to where something else is provided, never what is excepted
  # or named ("Except as provided by subsection (2)", "Subject to
  # subsection (2)", "in accordance with …": s.183(1) of 2017 c.3)
  @pointer ~r/\b(?:except\s+as\s+(?:otherwise\s+)?(?:provided|mentioned|specified|set\s+out)\s+(?:by|in|under)|subject\s+to|in\s+accordance\s+with|(?:as|to\s+the\s+extent)\s+(?:provided|mentioned|specified)\s+(?:by|in|under))\s+[^,;]*/i

  # no time stated and no rule read: a condition or description, never a
  # statement ("… until section 55 comes into force")
  @time ~r/\bon\b|\bfrom\b|\bat\s+the\s+end\b|\bday\b|\bdate\b|\bby\s+order\b|\bappoint|\bpass(?:ed|ing)\b|\bmade\b|\bexit\b/i

  @doc """
  The leftovers of `statement` (a sentence, with its list items when it
  opens a list) given the `rules` read from it — the law's own rule too
  when its start was read from it — and `refs`, the reader's own ref
  extractor (text → bare refs: "reg.7", "s.85..s.87").
  """
  @spec of(String.t(), [Rule.t()], (String.t() -> [String.t()])) :: [leftover()]
  def of(statement, rules, refs) do
    statement = Regex.replace(@pointer, statement, ",")

    if Clause.mention?(statement) or power?(statement) or instrument?(statement) or
         no_when?(statement, rules) do
      []
    else
      (dates(statement, rules) ++
         exceptions(statement, rules, refs) ++
         provisions(statement, rules, refs) ++
         qualifiers(statement, rules) ++ relative_days(statement, rules))
      |> Enum.uniq()
    end
  end

  defp power?(s), do: Regex.match?(@power, s)

  defp instrument?(s) do
    # (after a lead-in: "For the purpose of this article, a CFD transfer
    # notice comes into force—": SSI 2009/140 reg.21B(8))
    s =
      String.replace(
        s,
        ~r/^\W*(?:for\s+the\s+purposes?\s+of|subject\s+to)\s+[^,]{1,120},\s*/i,
        ""
      )

    Regex.match?(@instrument, s) and
      not (s =~ ~r/^\W*(?:These|This)\s+(?:Regulations|Order|Rules)\b/)
  end

  defp no_when?(s, []),
    do: not Regex.match?(@time, String.replace(s, ~r/^.*?\binto\s+(?:force|operation)\b/is, ""))

  defp no_when?(_s, _rules), do: false

  defp dates(s, rules) do
    held = for %Rule{when: {:date, d}} <- rules, into: MapSet.new(), do: d

    for [words] <- Regex.scan(@date, s),
        d = Clause.date_at_start(words),
        d != nil,
        not MapSet.member?(held, d),
        do: %{kind: :date, words: words}
  end

  defp exceptions(s, rules, refs) do
    excepted = Enum.flat_map(rules, & &1.except)
    general? = Enum.any?(rules, &(&1.scope in [:all, :rest]))

    named =
      if general?,
        do: Enum.flat_map(rules, &List.wrap(if is_list(&1.scope), do: &1.scope)),
        else: []

    for [_, words] <- Regex.scan(@except, s),
        ref <- refs.(words),
        not schedule?(ref),
        not covered?(ref, excepted ++ named),
        do: %{kind: :exception, words: ref}
  end

  defp provisions(s, rules, refs) do
    used = Enum.flat_map(rules, &(List.wrap(if is_list(&1.scope), do: &1.scope) ++ &1.except))
    excepted = for [_, words] <- Regex.scan(@except, s), ref <- refs.(words), do: ref
    # "the following provisions of Part 1 …": the Part is where they are
    container? = s =~ ~r/\bprovisions\s+of\s+(?:Parts?|Chapters?)\b/i

    for segment <- @except |> Regex.replace(s, ",") |> segments(),
        ref <- refs.(segment),
        not schedule?(ref),
        not (container? and String.starts_with?(ref, ["pt.", "ch."])),
        ref not in excepted,
        not covered?(ref, used),
        not with_the_whole?(s, rules),
        do: %{kind: :provision, words: ref}
  end

  # one time for the whole law, stated once: the provisions it names come
  # in with it ("This section and sections 44 to 52 come into force on such
  # day as …", the Act wholly by order: asp 2009/12 s.100(2))
  defp with_the_whole?(s, rules) do
    Enum.any?(rules, &(&1.scope == :all and &1.except == [])) and
      length(Regex.scan(@date, s)) <= 1 and not Regex.match?(@except, s)
  end

  defp qualifiers(s, rules) do
    partial? = Enum.any?(rules, &(not Rule.full?(&1)))

    # (never the order power's own words: "different days may be appointed
    # … in relation to premises of different classes": 1963 c.41 s.91(2))
    text =
      s
      |> String.replace(@completing, "")
      |> String.replace(
        ~r/\b(?:different|a\s+later|an\s+earlier)\s+days?\s+may\s+be\s+appointed\b[^.;]*/i,
        ""
      )

    case Regex.run(@qualifier, text) do
      [words] when not partial? -> [%{kind: :qualifier, words: words}]
      _ -> []
    end
  end

  # a relative day the reader resolved: a relative rule, or a date the text
  # doesn't state (counted from the making or passing) — never where a
  # named day ("exit day") could give that date
  defp relative_days(s, rules) do
    stated =
      for [w] <- Regex.scan(@date, s),
          d = Clause.date_at_start(w),
          d != nil,
          into: MapSet.new(),
          do: d

    named_day? = s =~ ~r/\b(?:exit|IP\s+completion|implementation\s+period\s+completion)\s+day\b/i

    relative? =
      Enum.any?(rules, fn
        %Rule{when: {:after, _, _}} -> true
        %Rule{when: {:date, d}} -> not named_day? and not MapSet.member?(stated, d)
        _ -> false
      end)

    case Regex.run(@relative, s) do
      [words] when not relative? -> [%{kind: :relative_day, words: words}]
      _ -> []
    end
  end

  # ── a law's own clause ───────────────────────────────────────────────

  @open ~r/(?:into\s+(?:force|operation)|as\s+follows|following\s+dates?|except\s+that)\s*[—–:-]?\s*$/iu

  @doc """
  The statement a sentence of row `row_id` makes — with its list items when
  it opens a list ("… shall come into force —", "… except that—") — and the
  rules `read` (`OwnClause.read/2`) holds from it: from the row or an item
  under it, their words part of the statement (or it of theirs).
  """
  @spec statement(String.t(), String.t(), [map()], map()) :: {String.t(), [Rule.t()]}
  def statement(row_id, sentence, rows, %{rules: rules}) do
    items =
      if Regex.match?(@open, sentence),
        do: for(r <- rows, String.starts_with?(r.section_id, row_id <> "("), do: r.text || ""),
        else: []

    text = Enum.join([sentence | items], " ")
    base = row_id |> bare() |> provision()
    squashed = squash(text)

    # (an item's rule carries the sentence the reader made of it — "regulations
    # 4 and 14 come into force on …" — so an item row's rules are its own)
    item? = &(items != [] and String.starts_with?(&1, bare(row_id) <> "("))

    own =
      for %Rule{source: %{ref: ref, text: t}} = r <- rules,
          is_binary(ref) and is_binary(t),
          provision(ref) == base,
          item?.(ref) or String.contains?(squashed, squash(t)) or
            String.contains?(squash(t), squash(sentence)),
          do: r

    {text, own}
  end

  @doc "Each commencement sentence of a law's `rows` with its leftovers, given the law's reading."
  @spec for_law([map()], map(), [{String.t(), String.t()}]) :: [
          {String.t(), String.t(), [leftover()]}
        ]
  def for_law(rows, read, sentences) do
    for {row_id, sentence} <- sentences do
      {text, own} = statement(row_id, sentence, rows, read)
      refs = &Provisions.refs_in(&1, rows, provision(row_id))
      {row_id, sentence, of(text, own, refs)}
    end
  end

  @type statement :: %{
          row: String.t(),
          sentence: String.t(),
          form: map(),
          outcome: map(),
          pattern: String.t(),
          leftovers: [leftover()]
        }

  @doc """
  Each commencement sentence of a law's `rows` as the catalogue classes it
  (`SentencePatterns`: form, outcome, pattern key) with its leftovers,
  given the law's reading — the one reading the catalogue and the family
  gate share. Another instrument's commencement has none (it names none
  of the law's own provisions).
  """
  @spec sentences([map()], map()) :: [statement()]
  def sentences(rows, read) do
    found = SentencePatterns.sentences(rows)

    for {{row_id, s}, {_, _, left}} <- Enum.zip(found, for_law(rows, read, found)) do
      f = SentencePatterns.form(s)
      o = SentencePatterns.outcome(s, read)

      %{
        row: row_id,
        sentence: s,
        form: f,
        outcome: o,
        pattern: SentencePatterns.key(f, o.class),
        # (a mention the catalogue classes so, as SI 2015/1947 reg.96(7))
        leftovers: if(f.subject == "instrument" or f.role == "mention", do: [], else: left)
      }
    end
  end

  @doc """
  Each statement of a commencement order (`OrderPatterns.units/1`) as the
  order catalogue classes it, with its leftovers given the order's `rules`.
  """
  @spec order_units(SertantaiLegal.Scraper.AmendingLaw.Doc.t(), [Rule.t()]) :: [map()]
  def order_units(doc, rules) do
    for unit <- OrderPatterns.units(doc) do
      f = OrderPatterns.form(unit)
      o = OrderPatterns.outcome(unit, rules)

      %{
        unit: unit,
        form: f,
        outcome: o,
        pattern: OrderPatterns.key(f, o.class),
        leftovers: order_leftovers(unit, rules)
      }
    end
  end

  # the order's own commencement and a table's header commence none of the
  # Act; a table row's provisions are its first cell (the next is a subject)
  defp order_leftovers(%{kind: kind}, _rules) when kind in ["own", "table_header"], do: []

  defp order_leftovers(unit, rules) do
    text = if unit.kind == "table", do: unit.text |> String.split(" | ") |> hd(), else: unit.text
    own = OrderPatterns.own_rules(unit, rules)

    cond do
      own_articles?(text) -> []
      # a statement bringing in its Schedule's table: the rows' rules use its words
      own == [] and text =~ ~r/\bSchedule\b|\bcolumn\b/ -> of(text, rules, &Order.refs_in/1)
      true -> of(text, own, &Order.refs_in/1)
    end
  end

  # the order's own articles ("This article and article 2 come into force …",
  # "The following provisions of this Order …", "Article 3 comes into force …")
  defp own_articles?(text),
    do:
      text =~ ~r/^\W*(?:This|These)\s+(?:articles?|Order|regulations?|Regulations)\b/ or
        text =~
          ~r/^\W*The\s+(?:remaining\s+|other\s+|following\s+)?provisions\s+of\s+this\s+(?:Order|instrument)\b/ or
        text =~ ~r/^\W*Articles?\s+\d[^.]*?\b(?:comes?|shall\s+come)\s+into\b/

  # ── the review: a statement's status ────────────────────────────────

  @doc "A leftover group's reviewed status (`leftovers.json`), nil when it has none."
  @spec status(String.t(), map()) :: String.t() | nil
  def status(shape, reviewed), do: Map.get(reviewed, shape)

  @doc "True for a status that names the leftover as a known limit (the family gate passes it)."
  @spec named?(String.t() | nil) :: boolean()
  def named?("known: " <> _), do: true
  def named?(_status), do: false

  # ── the family gate ─────────────────────────────────────────────────

  @type item :: %{
          source: :own | :order | :amending,
          law: String.t(),
          ref: String.t(),
          shape: String.t(),
          words: [String.t()],
          reach: integer(),
          status: String.t() | nil
        }

  @doc "A leftover reaching a family: where it is, its group's shape, its words, reach and status."
  @spec item(
          atom(),
          String.t(),
          String.t(),
          String.t(),
          [leftover()],
          integer(),
          String.t() | nil
        ) ::
          item()
  def item(source, law, ref, shape, leftovers, reach, status),
    do: %{
      source: source,
      law: law,
      ref: ref,
      shape: shape,
      words: Enum.map(leftovers, & &1.words),
      reach: reach,
      status: status
    }

  @doc """
  The family gate over its leftovers: `pass?` when every one is named
  (`known:`); the failing ones (`fix:`, `check:`, no status) widest reach
  first; counts by status.
  """
  @spec gate([item()]) :: %{pass?: boolean(), failing: [item()], counts: map()}
  def gate(items) do
    failing =
      items |> Enum.reject(&named?(&1.status)) |> Enum.sort_by(&{-&1.reach, &1.law, &1.ref})

    %{
      pass?: failing == [],
      failing: failing,
      counts: Enum.frequencies_by(items, &status_kind(&1.status))
    }
  end

  defp status_kind("known: " <> _), do: :known
  defp status_kind("fix: " <> _), do: :fix
  defp status_kind("check: " <> _), do: :check
  defp status_kind(_none), do: :unreviewed

  # ── groups, ranked by reach ─────────────────────────────────────────

  @type groups :: %{String.t() => %{count: integer(), laws: map(), examples: [map()]}}

  @doc "A group's shape: the statement's pattern and the kinds left over."
  @spec shape(String.t(), [leftover()]) :: String.t()
  def shape(pattern, leftovers),
    do:
      pattern <>
        " | left: " <>
        (leftovers
         |> Enum.map(&to_string(&1.kind))
         |> Enum.uniq()
         |> Enum.sort()
         |> Enum.join("+"))

  @doc """
  Adds one statement's leftovers to `groups` under its shape: the count,
  each law with its reach (its LAT rows, or the changes it makes on ours),
  up to 3 examples from different laws.
  """
  @spec add(groups(), String.t(), String.t(), String.t(), [leftover()], integer()) :: groups()
  def add(groups, _shape, _law, _row, [], _reach), do: groups

  def add(groups, shape, law, row, leftovers, reach) do
    g = Map.get(groups, shape, %{count: 0, laws: %{}, examples: []})
    example = %{"law" => law, "row" => row, "words" => Enum.map(leftovers, & &1.words)}

    examples =
      if length(g.examples) < 3 and law not in Enum.map(g.examples, & &1["law"]),
        do: g.examples ++ [example],
        else: g.examples

    Map.put(groups, shape, %{
      count: g.count + 1,
      laws: Map.put(g.laws, law, reach),
      examples: examples
    })
  end

  @doc "The groups by reach (the sum of their laws'), widest first: `{shape, reach, group}`."
  @spec ranked(groups()) :: [{String.t(), integer(), map()}]
  def ranked(groups) do
    groups
    |> Enum.map(fn {shape, g} -> {shape, g.laws |> Map.values() |> Enum.sum(), g} end)
    |> Enum.sort_by(fn {shape, reach, _} -> {-reach, shape} end)
  end

  @doc "The summary a catalogue prints: the groups, the widest `n` with their review status, those with none."
  @spec summary([{String.t(), integer(), map()}], map(), integer()) :: [String.t()]
  def summary(ranked, reviewed, n \\ 30) do
    statements = ranked |> Enum.map(&elem(&1, 2).count) |> Enum.sum()
    unreviewed = Enum.count(ranked, fn {shape, _, _} -> not Map.has_key?(reviewed, shape) end)

    [
      "\nleftovers by shape (words no rule uses): #{length(ranked)} groups, #{statements} statements"
    ] ++
      for(
        {shape, reach, g} <- Enum.take(ranked, n),
        do: "  #{reach} reach, #{g.count}: #{shape} [#{Map.get(reviewed, shape, "no status")}]"
      ) ++ ["leftover groups with no status: #{unreviewed}"]
  end

  @doc "The groups as their generated file: shape → reach, count, laws, examples."
  @spec to_json(groups()) :: map()
  def to_json(groups) do
    Map.new(ranked(groups), fn {shape, reach, g} ->
      {shape,
       %{
         "reach" => reach,
         "count" => g.count,
         "laws" => map_size(g.laws),
         "examples" => g.examples
       }}
    end)
  end

  @doc "The ranked groups as report lines."
  @spec lines([{String.t(), integer(), map()}]) :: [String.t()]
  def lines(ranked) do
    for {shape, reach, g} <- ranked,
        line <-
          ["#{reach} reach, #{g.count} statements, #{map_size(g.laws)} laws — #{shape}"] ++
            for(
              e <- g.examples,
              do: "    #{e["law"]} #{e["row"]}: #{Enum.join(e["words"], " · ")}"
            ),
        do: line
  end

  defp bare(sid), do: sid |> String.split(":", parts: 2) |> List.last()
  defp provision(ref), do: ref |> String.split("(", parts: 2) |> hd()
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()

  # the statement's clauses: commas, semicolons, dashes and "which" part
  # them, so another law's provision never hides the statement's own (the
  # extractor drops a clause naming another law)
  defp segments(s), do: String.split(s, ~r/[,;—–]|\bwhich\b/u, trim: true)

  # Schedules aren't parsed into rows (a v0.1 limit): never counted
  defp schedule?(ref), do: String.starts_with?(ref, ["sch", "annex"])

  # a ref is used by a scope or exception naming it or a provision holding it
  # — or its subsections the rules name ("Subsections (1) to (3) … of section
  # 190": SI 2009/2260, the rules s.190(1)…)
  defp covered?(ref, used),
    do:
      Enum.any?(
        used,
        &(ref == &1 or String.starts_with?(ref, [&1 <> "(", &1 <> "."]) or
            String.starts_with?(&1, ref <> "("))
      )
end
