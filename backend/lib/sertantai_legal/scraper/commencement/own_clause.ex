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
  - Sentences the reader can't resolve make no rule.

  `context/1` gives the evaluator a law's row structure (containers from
  `part` / `chapter`, document order). Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Provisions

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
  def rules(law_name, input) do
    law = LawStart.resolve(input)
    rows = Map.get(input, :rows, [])

    provisions =
      rows
      |> Provisions.groups(Map.get(input, :made), law)
      |> Enum.flat_map(&group_rule(law_name, &1))

    # a staged clause's law-level rule is LawStart's earliest date (LR-33 P1);
    # whether it should reach rows no sentence names is open (CR-03 question)
    List.wrap(law_rule(law_name, law)) ++ provisions
  end

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

  defp law_rule(law_name, %LawStart{} = law) do
    case law_when(law) do
      nil ->
        nil

      w ->
        Rule.new(
          commences: law_name,
          scope: :all,
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
