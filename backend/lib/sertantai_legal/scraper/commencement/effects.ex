defmodule SertantaiLegal.Scraper.Commencement.Effects do
  @moduledoc """
  An Act's "coming into force" effects (its legislation.gov.uk changes feed)
  as commencement rules (commencement-rules CR-04, re-scoped 2026-10-18:
  effects first — Jason: "if we have the 'effects' data from leg.gov.uk why
  do we need to pull the laws too?"). legislation.gov.uk's editorial data:
  which provision, the commencing instrument and article, the date, and
  the qualification.

  - **Scope**: the effect's structured refs (`section-8-1` → "s.8(1)",
    `schedule-2-paragraph-5` → "sch.2.para.5"; ranges "from..to").
  - **When**: each in-force entry's date; a prospective entry is
    `appointed`.
  - **Qualification**: "wholly in force", "… in so far as not already in
    force" → full; "for specified purposes" → `:for_specified_purposes`;
    "for E." / "for W." / "for E.W." … → the territory; any other words →
    `:in_relation_to` (or `:for_making_secondary_legislation` when they
    say so).
  - **Source**: the commencing instrument (each order its own source), its
    article, the qualification as written.

  Pure: the effects come in (`ChangesFeed.fetch/4`).
  """

  alias SertantaiLegal.Scraper.Commencement.{Order, Rule}
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @places %{"E" => "E", "W" => "W", "S" => "S", "N.I" => "NI", "NI" => "NI"}

  @doc "The rules an Act's commencement effects state (`act`: the Act's law name)."
  @spec rules(String.t(), [Effect.t()]) :: [Rule.t()]
  def rules(act, effects) do
    for %Effect{type: type} = e <- effects,
        type =~ ~r/coming into force/i,
        scope = scope(e),
        scope != [],
        entry <- entries(e),
        do: rule(act, e, scope, entry)
  end

  defp entries(%Effect{in_force: [_ | _] = entries}), do: entries

  defp entries(%Effect{prospective: true}),
    do: [%{date: nil, prospective: true, qualification: nil}]

  defp entries(_e), do: []

  defp scope(%Effect{affected_refs: refs, affected_ranges: ranges}) do
    singles = refs |> Enum.map(&Order.ref/1) |> Enum.reject(&is_nil/1)

    spans =
      for {a, b} <- ranges,
          ra = Order.ref(a),
          rb = Order.ref(b),
          ra != nil and rb != nil,
          do: "#{ra}..#{rb}"

    refs = Enum.uniq(singles ++ spans)

    # the feed lists a paragraph's Schedule too ("schedule-5",
    # "schedule-5-paragraph-77"): a container named with something inside it
    # is only its place
    Enum.reject(refs, fn r ->
      Enum.any?(
        refs,
        &(&1 != r and (String.starts_with?(&1, r <> ".") or String.starts_with?(&1, r <> "(")))
      )
    end)
  end

  defp rule(act, e, scope, entry) do
    {territory, purposes} = qualification(entry.qualification)

    Rule.new(
      commences: act,
      scope: scope,
      when: if(entry.date, do: {:date, entry.date}, else: {:appointed, "prospective"}),
      territory: territory,
      purposes: purposes,
      source: %{
        law: e.affecting || "unknown",
        ref: e.affecting_provisions,
        text: "#{e.affected_provisions} coming into force" <> qualified(entry.qualification)
      },
      treatment: :feed_commencement
    )
  end

  defp qualified(nil), do: ""
  defp qualified(q), do: " " <> q

  @doc """
  The rules as they bear on one changed row of the amended law (its
  section_id): a qualification naming the amended law's provisions it
  inserts or substitutes ("for the insertion of s. 120A for E. and the
  insertion of s. 120B for specified purposes") reaches only those — a rule
  naming others is dropped; one naming the row's own section is no longer
  "in relation to" something else (the remaining qualifiers, e.g. "for E.",
  "for specified purposes" said of that section, stay).
  """
  @spec for_row([Rule.t()], String.t()) :: [Rule.t()]
  def for_row(rules, section_id) do
    section = section(section_id)

    Enum.flat_map(rules, fn r ->
      case named_sections(r) do
        [] -> [r]
        named -> if section in named, do: [own_part(r, section)], else: []
      end
    end)
  end

  # "ss. 66A, 66AA, 66C", "s. 120B", "s. 66DB(3)" after insertion /
  # substitution / omission: the sections named (no brackets)
  defp named_sections(%Rule{source: %{text: text}}) when is_binary(text) do
    case Regex.run(
           ~r/\bfor\s+the\s+(?:insertion|substitution|omission|repeal)\s+of\s+(.*)$/i,
           text
         ) do
      [_, rest] ->
        for [_, list] <-
              Regex.scan(
                ~r/\bss?\.\s*((?:\d+[A-Z]*(?:\([^)]*\))*(?:\s*(?:,|and|-|–)\s*)?)+)/,
                rest
              ),
            n <- List.flatten(Regex.scan(~r/\d+[A-Z]*/, list)),
            do: n

      nil ->
        []
    end
    |> Enum.uniq()
  end

  defp named_sections(_rule), do: []

  # the part of the qualification about this section
  defp own_part(%Rule{source: %{text: text}} = r, section) do
    part =
      text
      |> String.split(~r/\s+and\s+(?=the\s+(?:insertion|substitution|omission|repeal)\b)/)
      |> Enum.find(text, &(&1 =~ ~r/\bss?\.\s*[^;]*\b#{Regex.escape(section)}\b/))

    rest =
      part
      |> String.replace(
        ~r/^.*?\bfor\s+the\s+(?:insertion|substitution|omission|repeal)\s+of\s+ss?\.\s*[\w(),\s–-]*?(?=\s+for\b|$)/i,
        ""
      )
      |> String.trim()

    {territory, purposes} = qualification(if rest == "", do: nil, else: rest)

    # a place before the first "for the insertion of …" covers every part
    {lead, _} =
      text
      |> String.split(~r/\bfor\s+the\s+(?:insertion|substitution|omission|repeal)\b/i, parts: 2)
      |> hd()
      |> qualification()

    %{r | territory: territory || lead, purposes: purposes}
  end

  # "UK_x:s.120B(2)(a)" → "120B"
  defp section(section_id) do
    case Regex.run(~r/:(?:s|reg|art|rule)\.(\d+[A-Z]*)/, section_id) do
      [_, n] -> n
      nil -> nil
    end
  end

  @doc "A commencement qualification as `{territory, purposes}`."
  @spec qualification(String.t() | nil) :: {String.t() | nil, Rule.purposes()}
  def qualification(nil), do: {nil, nil}

  def qualification(q) do
    territory =
      case Regex.run(~r/\bfor\s+((?:(?:E|W|S|N\.I|NI)\.?\s*)+)(?=\s|$|,)/, q) do
        [_, codes] ->
          codes
          |> String.split(~r/\.\s*/, trim: true)
          |> Enum.map(&Map.get(@places, String.trim(&1)))
          |> Enum.reject(&is_nil/1)
          |> case do
            [] -> nil
            cs -> Enum.join(cs, "+")
          end

        nil ->
          nil
      end

    rest = Regex.replace(~r/\bfor\s+(?:(?:E|W|S|N\.I|NI)\.?\s*)+/, q, "") |> String.trim()

    purposes =
      cond do
        rest == "" ->
          nil

        rest =~
            ~r/^(?:wholly\s+in\s+force|in\s+force)?\s*(?:in\s+so\s+far\s+as\s+not\s+already\s+in\s+force)?$/i ->
          nil

        rest =~ ~r/so\s+far\s+as\s+not\s+already\s+in\s+force|^wholly\s+in\s+force$/i ->
          nil

        rest =~ ~r/specified\s+purposes/i ->
          :for_specified_purposes

        rest =~
            ~r/mak(?:e|ing)\s+(?:regulations|orders?|rules|subordinate\s+legislation)|confers?\s+(?:a\s+)?power/i ->
          :for_making_secondary_legislation

        true ->
          :in_relation_to
      end

    {territory, purposes}
  end
end
