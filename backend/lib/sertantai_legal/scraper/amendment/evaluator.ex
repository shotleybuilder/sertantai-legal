defmodule SertantaiLegal.Scraper.Amendment.Evaluator do
  @moduledoc """
  Which row of the amended law an amendment rule reaches (amendment-rules
  AR-02), from the rule alone. Pure.

  - **Words-level** (`level: :words`): only the row a target names — never
    its children or its parent ("for “x” substitute “y”" in s.40(2)).
  - **Whole provisions** (`level: :provision`): the row itself when a target
    names it, else its nearest covering ancestor (bracket, or container from
    `ctx.ancestors`) — the target's own row: a whole-provision instruction on
    a sub-provision row targets the provision's own row, as the row-driven
    matcher placed records (LR-08), and the labels carry it down. A block's
    quoted provisions are targets already (expanded at read time: LR-43).
  - **Ranges** ("s.41..s.43") by document order (`ctx.order`), else number.

  `ctx`: `ancestors` (top ref → containers, nearest first), `order` (refs in
  document order). The row's own section_id is returned when a target names
  it (extent suffix kept); an ancestor as `law:ref`.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.LatRef

  @doc "The row the rule reaches for `section_id`: `{:ok, target section_id}` or `:no_match`."
  @spec reach(Rule.t(), String.t(), map()) :: {:ok, String.t()} | :no_match
  def reach(%Rule{amends: law} = rule, section_id, ctx \\ %{}) do
    if String.starts_with?(section_id, law <> ":"),
      do: in_law(rule, section_id, ctx),
      else: :no_match
  end

  @doc "The rows (targets' section_ids) a rule reaches among `section_ids`, first seen first."
  @spec rows(Rule.t(), [String.t()], map()) :: [String.t()]
  def rows(rule, section_ids, ctx \\ %{}) do
    section_ids
    |> Enum.flat_map(fn sid ->
      case reach(rule, sid, ctx) do
        {:ok, t} -> [t]
        :no_match -> []
      end
    end)
    |> Enum.uniq()
  end

  defp in_law(%Rule{level: :words} = rule, section_id, ctx) do
    [own | _] = LatRef.chain(section_id, ctx)
    if covered?(rule, own, ctx), do: {:ok, section_id}, else: :no_match
  end

  defp in_law(%Rule{level: :provision} = rule, section_id, ctx) do
    [own | _] = chain = LatRef.chain(section_id, ctx)

    case Enum.find(chain, &covered?(rule, &1, ctx)) do
      nil -> :no_match
      ^own -> {:ok, section_id}
      ancestor -> {:ok, "#{rule.amends}:#{ancestor}"}
    end
  end

  defp covered?(%Rule{targets: targets}, el, ctx),
    do: Enum.any?(targets, &LatRef.covers?(&1, el, ctx))
end
