defmodule SertantaiLegal.Scraper.Amendment.Review.Probe do
  @moduledoc """
  One amending provision as the reader sees it, printed for review
  (Amending-law reader: review tooling; it replaces the hand-written
  `probe.exs`): its words (the instruction, the quote and the provisions
  it holds, its parents and context, `AmendingLaw.Text`), the rules
  stored from it and a fresh reading, and whether the two agree. Pure:
  the task reads the document and the rules.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Rule

  @doc "The printed lines for provision `id` of `amending`: its text (nil when not in the document), the stored and the fresh rules."
  @spec lines(String.t(), String.t(), Text.t() | nil, [Rule.t()], [Rule.t()]) :: [String.t()]
  def lines(amending, id, nil, stored, _fresh),
    do: ["#{amending} #{id}: not in the document" | rules("stored", stored)]

  def lines(amending, id, %Text{} = t, stored, fresh) do
    ["#{amending} #{id}"] ++
      words("parents", t.parents) ++
      words("context", t.context) ++
      ["  instruction: #{t.instruction}"] ++
      if(t.quoted in [nil, ""], do: [], else: ["  quoted: #{String.slice(t.quoted, 0, 600)}"]) ++
      words("quoted provisions", Enum.map(t.inserted, &Enum.join(&1, "/"))) ++
      rules("stored", stored) ++
      rules("fresh reading", fresh) ++
      [agreement(stored, fresh)]
  end

  @doc "Whether the stored and fresh rules say the same (as `Amendment.ReadReport` compares them)."
  @spec same?([Rule.t()], [Rule.t()]) :: boolean()
  def same?(stored, fresh), do: keys(stored) == keys(fresh)

  defp words(_, []), do: []
  defp words(label, ws), do: ["  #{label}:" | Enum.map(ws, &"    #{String.slice(&1, 0, 300)}")]

  defp rules(label, []), do: ["  #{label}: no rules"]

  defp rules(label, rs),
    do: ["  #{label}: #{length(rs)}" | Enum.map(rs, &"    #{Rule.to_text(&1)}")]

  defp agreement(stored, fresh),
    do:
      if(same?(stored, fresh),
        do: "  the same",
        else: "  DIFFERENT: the stored rules are not this reader's reading"
      )

  defp keys(rules),
    do:
      rules
      |> Enum.map(
        &{&1.amends, Enum.sort(&1.targets), &1.operation, &1.level, &1.source.ref, &1.treatment}
      )
      |> Enum.sort()
end
