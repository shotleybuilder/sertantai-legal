defmodule SertantaiLegal.Scraper.Commencement.Amending do
  @moduledoc """
  When an amending provision came into force, as it bears on one changed row
  of the amended law (commencement-rules CR-04): **effects first** — the
  amending Act's "coming into force" effects (`Effects`, legislation.gov.uk's
  editorial data) where any reaches the provision; else the rules read from
  the orders the notes cite (`Order`) — never an Act's Royal Assent
  fallback; a whole Schedule whose entries came in on different dates gets
  none. Jason 2026-10-18: "if we have the
  'effects' data from leg.gov.uk why do we need to pull the laws too?". Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.{Effects, Evaluator, Order, Rule}

  @doc """
  The evaluation for the amending provision `provision_id` (its CLML id,
  "section-8-1") of the Act whose rules are `rules`, for the changed row
  `section_id` of the amended law, whose extent is `extent`.
  """
  @spec evaluate([Rule.t()], String.t(), String.t(), String.t() | nil) :: Evaluator.result()
  def evaluate(rules, provision_id, section_id, extent) do
    ref = Order.ref(provision_id) || provision_id
    ctx = Map.put(Order.context(), :extent, extent)
    {effects, text} = Enum.split_with(rules, &(&1.treatment == :feed_commencement))

    # an Act's Royal Assent where its clause leaves the rest to orders, or a
    # staged clause's earliest stage, is its start (LR-33), not evidence of
    # when an amending provision came in (CR-06: GLA Act 1999, 85 rows)
    text = Enum.reject(text, &(&1.treatment in [:act_enactment, :clause_staged]))

    by_effects = Evaluator.evaluate(Effects.for_row(effects, section_id), ref, ctx)

    if(by_effects.entries == [], do: Evaluator.evaluate(text, ref, ctx), else: by_effects)
    |> whole_schedule(ref)
  end

  # a whole Schedule (a repeals table) whose entries came in on different
  # dates says nothing about one entry: no date rather than a guess
  defp whole_schedule(result, ref) do
    dates = result.entries |> Enum.map(& &1.date) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    if Regex.match?(~r/^sch\.[^.]+$/, ref) and length(dates) > 1,
      do: %{result | entries: [], full_from: nil, partial_from: nil, undated: []},
      else: result
  end
end
