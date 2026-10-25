defmodule SertantaiLegal.Scraper.Commencement.OwnClause do
  @moduledoc """
  A law's own commencement clause as rules (commencement-rules CR-03): the
  reader for "this law comes into force …". The reading stays where it is —
  `LawStart` (which treatment decides the law's start, LR-33) and
  `LawStart.Provisions` (the sentences commencing particular provisions,
  LR-34) — and this module writes what they read as `Commencement.Rule`s:

  - **The law-level rule**: scope `all`, `when` the decided date
    (`{:date, d}`: the treatment and the clause verbatim say how it was
    counted), `appointed "by order"` (by_order), `appointed "with another
    enactment"` (tied_to_other_law) or `unread` (clause_unread). No rule for
    `no_clause` and the EU known limits: unknown stays unknown.
  - **Named provisions** ("Regulation 73 … on 1 October 2030"): their refs
    (Parts and Chapters as the law's own ids, "pt.6.ch.1").
  - **Remaining provisions** ("The remaining provisions …", "Otherwise …"):
    `rest`, never the commencement provision itself (it commences with the
    law: `except`).
  - **Qualified sentences** ("in relation to Wales", "for the purpose of
    making regulations", "with respect to any tip …"): the territory, else
    one of the four purposes, with their date — partial entries.
  - **A provision's own words** ("This section shall come into force on the
    passing of this Act", anywhere in the law): that provision, its date
    (CR-06: the form the deleted `AmendingLaw.Commencement` read).
  - Sentences the reader can't resolve make no rule.

  `context/1` gives the evaluator a law's row structure (containers from
  `part` / `chapter`, document order). `doc_rows/1` gives a law we hold no
  LAT for (an amending law, one hop from our rows: CR-06) rows from its
  CLML, in LAT's grammar. `treatments/0`: the treatments this reader
  writes. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}
  alias SertantaiLegal.Scraper.LatParser.Xml
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.{Clause, Provisions}

  @territories %{
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI",
    "england and wales" => "E+W",
    "great britain" => "E+W+S"
  }

  # an Act's clause that leaves the whole Act undated (its rule, not
  # Royal Assent's)
  @whole_undated [:by_order, :tied_to_other_law]

  @doc "The rules a law's own commencement clause states (`input`: `LawStart.input()`)."
  @spec rules(String.t(), LawStart.input()) :: [Rule.t()]
  def rules(law_name, input), do: read(law_name, input).rules

  @doc """
  The law's start (`LawStart.resolve/1`), the rules its clause states, and
  the provision-level sentences it couldn't resolve (`unread`: groups, no
  rule).
  """
  @spec read(String.t(), LawStart.input()) :: %{
          law: LawStart.t(),
          rules: [Rule.t()],
          unread: [map()]
        }
  def read(law_name, input) do
    law = LawStart.resolve(input)
    rows = Map.get(input, :rows, [])

    # the law's start may be decided by metadata — the register's date, the
    # CLML's, an Act's Royal Assent (LR-33) — but the law's text is primary
    # for when its provisions came in (CV-S04): the clause found is read for
    # its sentences, and its own date, or an Act's whole-Act "by order",
    # is the rule (NISR 1997/455 reg.1: 1 April 1998, the register's 1
    # December 1997 being reg.1(2)'s; HSWA 1974 s.85(2))
    clause = clause(law, rows, Map.get(input, :made), LawStart.act?(Map.get(input, :type_code)))
    read_from = clause || law

    table = Provisions.table_groups(rows, read_from, Map.get(input, :schedule_tables))
    groups = Provisions.groups(rows, Map.get(input, :made), read_from) ++ table

    table_refs = table |> Enum.flat_map(& &1.refs) |> Enum.map(&bare/1)

    by_clause =
      cond do
        rule_from_clause?(law, clause) ->
          clause

        # Royal Assent is an Act's own only where it says nothing of its
        # commencement: a sentence of the Act's own the reader can't read
        # (no group read from it) leaves it unread, never Royal Assent (Gas
        # Act 1995 s.18(2) "This Act, except— … shall come into force on
        # the appointed day, that is to say, such day as …": CV-S04 round 2,
        # N4)
        law.treatment == :act_enactment ->
          case unread_own(rows, groups) do
            nil -> law
            unread -> unread
          end

        true ->
          law
      end

    # what the general clause leaves out, when it is the rule
    excepted =
      if by_clause != law or law.treatment != :act_enactment,
        do: by_clause |> Provisions.except_refs(rows) |> Enum.map(&bare/1),
        else: []

    # a staged clause's law-level rule is LawStart's earliest date (LR-33 P1);
    # whether it should reach rows no sentence names is open (CR-03 question)
    %{
      law: law,
      rules:
        List.wrap(law_rule(law_name, by_clause, table_refs ++ excepted)) ++
          assent_rules(law_name, law, by_clause, excepted -- named(groups)) ++
          ((Enum.flat_map(groups, &group_rule(law_name, preceding(&1, rows))) ++
              own_words(law_name, rows, input))
           # a provision's own words read as a sentence too: once
           |> Enum.uniq_by(&{&1.scope, &1.except, &1.when, &1.territory, &1.purposes})),
      unread: Enum.filter(groups, &(&1.kind == :unread))
    }
  end

  @this ~r/^(?:\(\w+\)\s*)?This\s+(?:section|regulation|article|rule)\s+(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\s+(.+?)\.?$/i

  # "This section shall come into force on the passing of this Act" in any
  # provision: that provision's date
  # … or left to an order ("This section comes into force on such day as
  # the Treasury may by order made by statutory instrument appoint": FA 2014
  # s.300(3), CV-S04)
  defp own_words(law_name, rows, input) do
    for row <- rows,
        s <- Clause.sentences(row.text || ""),
        [_, tail] <- [Regex.run(@this, s)],
        when_ = own_when(tail, Map.get(input, :made)),
        when_ != nil,
        uniq: true do
      Rule.new(
        commences: law_name,
        scope: [top(row.section_id)],
        when: when_,
        source: source(law_name, row.section_id, s),
        treatment: if(match?({:date, _}, when_), do: :provision_dated, else: :provision_by_order)
      )
    end
  end

  defp own_when(tail, made) do
    case Clause.tail_date(tail, made) do
      {_treatment, %Date{} = d} -> {:date, d}
      _ -> if Clause.by_order?(tail), do: {:appointed, "by order"}
    end
  end

  @doc "The treatments the own-clause reader writes (the law's and its provisions')."
  @spec treatments() :: [atom()]
  def treatments,
    do:
      Enum.map(LawStart.catalogue(), &elem(&1, 0)) ++
        Enum.map(LawStart.provision_catalogue(), &elem(&1, 0))

  @doc """
  A law's body provisions from its CLML as rows (`section_id` in LAT's
  grammar, the provision's own words: no number, title, quoted text or
  sub-provisions), in document order — what `LawStart` reads a clause from.
  """
  @spec doc_rows(Doc.t()) :: [map()]
  def doc_rows(%Doc{law_name: law, ids: ids} = doc) do
    containers = containers(doc)

    for id <- ids,
        not String.starts_with?(id, "schedule"),
        ref = Order.ref(id),
        ref != nil,
        text = doc |> Doc.element(id) |> own() |> Doc.text(),
        {part, chapter} = Map.get(containers, id, {nil, nil}),
        do: %{section_id: "#{law}:#{ref}", text: text, part: part, chapter: chapter}
  end

  # each provision's Part and Chapter, from the elements holding it
  # ("part-II", "part-2-chapter-1"), as LAT names them: "Part II comes into
  # force …", "This Part …" read in an amending law (CV-S04: LGRA 1997,
  # DRA 2014)
  defp containers(%Doc{elements: els}) do
    for {id, el} <- els,
        [_ | groups] <- [Regex.run(~r/^part-([^-]+)(?:-chapter-([^-]+))?$/, id)],
        {part, chapter} = {hd(groups), Enum.at(groups, 1)},
        d <- Xml.descendants(el),
        inner = Xml.attr_or_nil(d, :id),
        inner != nil,
        reduce: %{} do
      acc ->
        Map.update(acc, to_string(inner), {part, chapter}, fn {p, c} -> {p, c || chapter} end)
    end
  end

  @skip [:Pnumber, :Title, :BlockAmendment, :Footnote, :CommentaryRef]

  # the element without its numbered children, number, title or quotes
  defp own({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    kept =
      Enum.reject(children, fn
        {:xmlElement, name, _, _, _, _, _, _, _, _, _, _} = c ->
          name in @skip or Xml.attr_or_nil(c, :id) != nil

        _ ->
          false
      end)

    put_elem(el, 8, Enum.map(kept, &own_inner/1))
  end

  defp own_inner({:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = el), do: own(el)
  defp own_inner(other), do: other

  @doc "The evaluator's context for a law's rows: each provision's containers, and document order."
  @spec context([map()]) :: map()
  def context(rows) do
    containers =
      Map.new(rows, fn r ->
        part = Map.get(r, :part)
        chapter = Map.get(r, :chapter)

        {top(r.section_id),
         Enum.reject(
           [part && chapter && "pt.#{part}.ch.#{chapter}", part && "pt.#{part}"],
           &is_nil/1
         )}
      end)

    %{
      ancestors: &Map.get(containers, &1, []),
      order: rows |> Enum.map(&top(&1.section_id)) |> Enum.uniq()
    }
  end

  # ── the law-level rule ──────────────────────────────────────────────

  # an Act's clause leaving provisions out of it says nothing of them: they
  # are in force on Royal Assent (Interpretation Act 1978 s.4; Gas Act 1995
  # s.18(2)(a)–(d), CV-S04 round 3)
  # the provisions a sentence of the clause names: its own words for them
  # win over the general clause's except list (Gas Act 1995 s.18(4): s.12
  # by order, though s.18(2)(b) excepts it)
  defp named(groups),
    do: for(g <- groups, g.kind != :unread, r <- g.refs, do: bare(r))

  defp assent_rules(_law_name, _law, _clause, []), do: []

  defp assent_rules(
         law_name,
         %LawStart{treatment: :act_enactment, date: %Date{} = d},
         clause,
         excepted
       ) do
    [
      Rule.new(
        commences: law_name,
        scope: excepted,
        when: {:date, d},
        source: source(law_name, clause.evidence, clause.text),
        treatment: :act_enactment
      )
    ]
  end

  defp assent_rules(_law_name, _law, _clause, _excepted), do: []

  @metadata [:lrt_metadata, :clml_coming_into_force, :act_enactment]
  @clause_dated [:clause_date, :clause_made_relative, :clause_named_day]

  # the clause's own date; an Act's general clause left to orders, tied or
  # unread (not a sentence about some provisions, "The preceding provisions
  # …", which is read as a group and leaves the rest to Royal Assent)
  defp rule_from_clause?(_law, nil), do: false
  defp rule_from_clause?(_law, %LawStart{treatment: t}) when t in @clause_dated, do: true

  # a staged clause: its sentences date the provisions, never the register's
  # one date over them all (SI 2007/764: England 1 July, Wales 2 April 2007)
  defp rule_from_clause?(_law, %LawStart{treatment: :clause_staged}), do: true

  defp rule_from_clause?(%LawStart{treatment: :act_enactment}, %LawStart{} = clause),
    do: whole_undated?(clause)

  defp rule_from_clause?(_law, _clause), do: false

  defp whole_undated?(%LawStart{treatment: :clause_unread, text: text}) when is_binary(text),
    do: Clause.general?(text)

  defp whole_undated?(%LawStart{treatment: t}), do: t in @whole_undated

  @own_head ~r/^(?:\(\w+\)\s*)?(?:(?:Subject\s+to|Except|Save|Apart\s+from|Other\s+than)\b[^.;]{0,300}?,\s*)?(?:this|the\s+provisions\s+of\s+this)\s+(?:Act|Measure)\b[^.;]{0,400}?\b(?:shall\s+|is\s+to\s+)?(?:comes?|come)\s+into\s+(?:force|operation)\b/i

  # the Act's own commencement sentence no group was read from
  defp unread_own(rows, groups) do
    read = for g <- groups, g.kind != :unread, into: MapSet.new(), do: squash(g.text)

    Enum.find_value(rows, fn r ->
      r
      |> Map.get(:text)
      |> Clause.sentences()
      |> Enum.find(
        &(Regex.match?(@own_head, &1) and not Clause.mention?(&1) and
            not MapSet.member?(read, squash(&1)))
      )
      |> then(&(&1 && %LawStart{treatment: :clause_unread, evidence: r.section_id, text: &1}))
    end)
  end

  defp squash(nil), do: nil
  defp squash(s), do: s |> String.replace(~r/\s+/u, " ") |> String.trim()

  # the clause behind a start metadata decided, when the law has one
  defp clause(%LawStart{treatment: t}, rows, made, act?) when t in @metadata do
    case Clause.read(rows, made, act?) do
      %LawStart{evidence: e} = clause when is_binary(e) -> clause
      _ -> nil
    end
  end

  defp clause(_law, _rows, _made, _act?), do: nil

  # a law commenced by its Schedule's table (V1-02): the table names what it
  # commences, so the law's rule leaves out every provision it names — never
  # completing one the table commences partly
  defp law_rule(law_name, %LawStart{} = law, except) do
    case law_when(law) do
      nil ->
        nil

      w ->
        Rule.new(
          commences: law_name,
          scope: :all,
          except: Enum.uniq(except),
          when: w,
          source: source(law_name, law.evidence, law.text),
          treatment: law.treatment
        )
    end
  end

  defp law_when(%LawStart{date: %Date{} = d}), do: {:date, d}
  defp law_when(%LawStart{treatment: :by_order}), do: {:appointed, "by order"}

  defp law_when(%LawStart{treatment: :tied_to_other_law}),
    do: {:appointed, "with another enactment"}

  defp law_when(%LawStart{treatment: :clause_unread}), do: :unread
  defp law_when(_no_clause_or_known_limit), do: nil

  # ── provision-level sentences ───────────────────────────────────────

  # "The preceding provisions of this Act …" (CMCHA 2007 s.27(1)): the
  # remaining provisions before the clause, never those after it
  defp preceding(%{kind: :remaining, text: text, evidence: evidence} = g, rows)
       when is_binary(text) and is_binary(evidence) do
    if text =~ ~r/\bpreceding provisions\b/i do
      tops = rows |> Enum.map(&top(&1.section_id)) |> Enum.uniq()
      later = tops |> Enum.drop_while(&(&1 != provision(evidence))) |> Enum.drop(1)
      %{g | excluded: g.excluded ++ later}
    else
      g
    end
  end

  defp preceding(g, _rows), do: g

  defp group_rule(_law_name, %{kind: :unread}), do: []

  defp group_rule(law_name, g) do
    {territory, purposes} = qualification(g)

    when_ =
      cond do
        d = g.date || g.qualified_date ->
          {:date, d}

        g.treatment == :provision_by_order ->
          {:appointed, "by order"}

        Regex.match?(~r/\bby order\b|\bmay appoint\b|\bsuch day\b/i, g.text) ->
          {:appointed, "by order"}

        true ->
          :unread
      end

    {scope, except} =
      case g.kind do
        # the commencement provision commences with the law, never with "the rest"
        :remaining -> {:rest, Enum.uniq([provision(g.evidence) | Enum.map(g.excluded, &bare/1)])}
        _ -> {Enum.map(g.refs, &bare/1), Enum.map(g.excluded, &bare/1)}
      end

    if scope == [] do
      []
    else
      [
        Rule.new(
          commences: law_name,
          scope: scope,
          except: except,
          when: when_,
          territory: territory,
          purposes: purposes,
          source: source(law_name, g.evidence, g.text),
          treatment: g.treatment
        )
      ]
    end
  end

  # a qualified sentence's territory, else its purposes (the four)
  # a group naming its country itself (a sentence dating each country apart)
  defp qualification(%{treatment: :provision_qualified, territory: place}) when is_binary(place),
    do: {Map.get(@territories, String.downcase(place)), nil}

  defp qualification(%{treatment: :provision_qualified, text: text}) do
    case territory(text) do
      nil -> {nil, purposes(text)}
      t -> {t, nil}
    end
  end

  defp qualification(_g), do: {nil, nil}

  defp territory(text) do
    case Regex.run(
           ~r/\b(?:in relation to|in|as respects|so far as it (?:extends|applies) to)\s+(England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\b/i,
           text
         ) do
      [_, place] -> Map.get(@territories, String.downcase(place))
      nil -> nil
    end
  end

  defp purposes(text) do
    cond do
      text =~
          ~r/\bmak(?:e|ing) (?:regulations|an? order|orders|rules|subordinate legislation)\b|\bconfers? (?:a )?power\b|\bpowers? to make\b/i ->
        :for_making_secondary_legislation

      text =~ ~r/\bspecified purposes\b/i ->
        :for_specified_purposes

      true ->
        :in_relation_to
    end
  end

  # ── refs ────────────────────────────────────────────────────────────

  defp source(law_name, evidence, text),
    do: %{law: law_name, ref: evidence && bare(evidence), text: text}

  # "UK_x:reg.1(2)" → "reg.1(2)"; metadata evidence ("ukm:EnactmentDate") as is
  defp bare(ref) do
    case String.split(ref, ":", parts: 2) do
      [law, rest] -> if String.starts_with?(law, "UK_"), do: rest, else: ref
      [_] -> ref
    end
  end

  # "UK_x:reg.1(2)" → "reg.1"
  defp provision(ref), do: ref |> bare() |> String.split("(", parts: 2) |> hd()

  # a row's whole provision, as the evaluator's chain ends: "s.12" for
  # "UK_x:s.12(3)[S]"
  defp top(section_id),
    do:
      section_id
      |> bare()
      |> String.replace(~r/\[[^\]]*\]$/, "")
      |> String.split("(", parts: 2)
      |> hd()
end
