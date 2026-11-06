defmodule SertantaiLegal.Scraper.Amendment.Disagreement do
  @moduledoc """
  The amending-law reader's family gate (Decision 1, Jason 2026-11-06,
  Maritime Safety: Amending-law reader): every change the amending law's
  text states that legislation.gov.uk contradicts or leaves unstated (the
  check's D and L strata, `CheckStrata`), grouped by its cause and amending
  law. Causes come from the change and its rule, never from reading:

  - `quote-new-number`: inserted by a substitution's quote, a number the
    instruction doesn't name (`Reader.NewNumbers`; RULES.md
    `quote-new-numbers-are-inserted`), which legislation.gov.uk records as
    substituted, or records only on the provision substituted;
  - `quote-dropped-number`: a number a whole substitution's quote no longer
    makes, repealed (`Readers.AmendingLaw.Dropped`;
    `quote-dropped-numbers-are-repealed`);
  - `operation <law's text>/<legislation.gov.uk>`, `level …`: a value
    conflict on what this reader reads;
  - `unjoined`: the law's text alone beside legislation.gov.uk's likely
    same event left apart (the merge's);
  - `no operation from legislation.gov.uk: <operation> <level>`: joined to
    legislation.gov.uk's record of the change, which names no operation
    (the feed's "amended", legacy markup);
  - `law text only: <operation> <level>`: nothing beside it.

  Each group's words are its changes (amended law, target, amending
  provision) and its status is reviewed in
  `test/fixtures/amendment_patterns/disagreements.json` (`"<cause> @
  <amending law>"`, else `"<cause>"`), with the commencement gate's status
  semantics (`Commencement.Leftovers.status/3`, `gate/1`). Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.{CheckStrata, Rule}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.Commencement.Leftovers

  # what this reader reads (`CheckStrata`)
  @judged [:operation, :level, :by]

  @doc """
  The causes reaching the family: `rows` (`{amended law, change, stratum}`,
  the D and L strata), the amended laws' rules by law, the reviewed statuses.
  """
  @spec items(
          [{String.t(), Change.t(), CheckStrata.stratum()}],
          %{String.t() => [Rule.t()]},
          map()
        ) ::
          [Leftovers.item()]
  def items(rows, rules_by_law, reviewed) do
    rows
    |> Enum.group_by(fn {law, c, s} -> {cause(c, s, Map.get(rules_by_law, law, [])), by(c)} end)
    |> Enum.map(fn {{cause, by}, changes} ->
      words =
        for {law, c, _} <- Enum.sort_by(changes, &{elem(&1, 0), elem(&1, 1).target}),
            do: %{words: words(law, c)}

      Leftovers.item(
        :amending,
        by,
        "-",
        cause,
        words,
        length(changes),
        Leftovers.status(cause, reviewed, by)
      )
    end)
  end

  @doc "The gate over the items: as `Commencement.Leftovers.gate/1`."
  @spec gate([Leftovers.item()]) :: %{
          pass?: boolean(),
          failing: [Leftovers.item()],
          counts: map()
        }
  def gate(items), do: Leftovers.gate(items)

  @doc "One change's cause, from its stratum, conflicts and the rule its law-text key names."
  @spec cause(Change.t(), CheckStrata.stratum(), [Rule.t()]) :: String.t()
  def cause(c, stratum, rules) do
    cond do
      Enum.any?(keys(c), &String.ends_with?(&1, "#dropped")) ->
        "quote-dropped-number"

      Change.value(c, :law_text, :operation) == :inserted and quote_new_number?(c, rules) ->
        "quote-new-number"

      stratum == :L ->
        alone(c)

      true ->
        conflict_cause(c)
    end
  end

  defp alone(c) do
    reading = "#{Change.value(c, :law_text, :operation)} #{Change.value(c, :law_text, :level)}"

    if Enum.any?(c.claims, &(&1.source in [:feed, :markup])),
      do: "no operation from legislation.gov.uk: " <> reading,
      else: "law text only: " <> reading
  end

  defp conflict_cause(%Change{resolved: r}) do
    case r && Enum.filter(r.conflicts, fn {a, _, _} -> a in @judged end) do
      [_ | _] = cs ->
        named(cs)

      _ ->
        "unjoined"
    end
  end

  defp named([{attribute, {_, ours}, {_, theirs}} | _]), do: "#{attribute} #{ours}/#{theirs}"

  # inserted by a quote under a substituting instruction (`NewNumbers.split/2`)
  defp quote_new_number?(c, rules) do
    provisions = c |> keys() |> MapSet.new(&provision/1)

    Enum.any?(rules, fn %Rule{source: s} = r ->
      r.operation == :inserted and r.treatment == :quoted and
        MapSet.member?(provisions, "#{s.law}:#{s.ref}") and (s.text || "") =~ ~r/substitut/i
    end)
  end

  # the law-text records' keys ("law:element id", "…#dropped"), never an
  # effect id the merge joined
  defp keys(c),
    do:
      for(
        %Claim{source: :law_text, attribute: :operation, ref: "UK_" <> _ = ref} <- c.claims,
        uniq: true,
        do: ref
      )

  defp provision(key), do: key |> String.split("#") |> hd()

  defp by(c), do: Change.value(c, :law_text, :by) || "-"

  defp words(law, c) do
    refs =
      c |> keys() |> Enum.map(&(&1 |> provision() |> String.split(":", parts: 2) |> List.last()))

    "#{law} #{c.target} (#{Enum.join(refs, ", ")})"
  end
end
