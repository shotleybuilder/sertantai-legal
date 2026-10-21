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

    table = Provisions.table_groups(rows, law, Map.get(input, :schedule_tables))
    groups = Provisions.groups(rows, Map.get(input, :made), law) ++ table

    # a staged clause's law-level rule is LawStart's earliest date (LR-33 P1);
    # whether it should reach rows no sentence names is open (CR-03 question)
    %{
      law: law,
      rules:
        List.wrap(law_rule(law_name, law, table |> Enum.flat_map(& &1.refs) |> Enum.map(&bare/1))) ++
          Enum.flat_map(groups, &group_rule(law_name, &1)) ++ own_words(law_name, rows, input),
      unread: Enum.filter(groups, &(&1.kind == :unread))
    }
  end

  @this ~r/^(?:\(\w+\)\s*)?This\s+(?:section|regulation|article|rule)\s+(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\s+(.+?)\.?$/i

  # "This section shall come into force on the passing of this Act" in any
  # provision: that provision's date
  defp own_words(law_name, rows, input) do
    for row <- rows,
        s <- Clause.sentences(row.text || ""),
        [_, tail] <- [Regex.run(@this, s)],
        {_treatment, %Date{} = d} <- [Clause.tail_date(tail, Map.get(input, :made))],
        uniq: true do
      Rule.new(
        commences: law_name,
        scope: [top(row.section_id)],
        when: {:date, d},
        source: source(law_name, row.section_id, s),
        treatment: :provision_dated
      )
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
    for id <- ids,
        not String.starts_with?(id, "schedule"),
        ref = Order.ref(id),
        ref != nil,
        text = doc |> Doc.element(id) |> own() |> Doc.text(),
        do: %{section_id: "#{law}:#{ref}", text: text, part: nil, chapter: nil}
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
