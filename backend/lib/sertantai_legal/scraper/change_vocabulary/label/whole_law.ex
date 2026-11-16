defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.WholeLaw do
  @moduledoc """
  A law revoked provision by provision is revoked whole (Fire and OH&S:
  Label fold, Decision 3 a): when one law, on one day, repeals every
  top-level provision of the law, each of those repeals whose level no
  source states is whole, so it reaches the rows under it (`Label.reaches?/2`).
  SI 2009/716 revoked SI 2008/2337 as reg.1 to reg.7, one feed effect each
  with no level: reg.1(1) to reg.4(f) had stayed in force.

  The top-level provisions are the law's own rows with no row holding
  them: the outermost level of each row id (`LatRef.ancestors/1`), never a
  Part or Chapter row, which goes with its children (`Label.Containers`).
  Signatures, headings and tables are not rows of the fold. Schedules are
  not parsed (v0.1), so a Schedule the law has but we don't hold is never
  asked for; a Schedule row held is a top-level provision like any other.

  No record is made and no level is stated: the repeals stay on their own
  provisions, each marked as reaching what lies under it (`sources.reach`:
  `:whole_law`, read by `whole?/1`), so the repeal's own row is read as
  before. One provision repealed alone, or a set short of one top-level
  provision, stays as it was. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.LatRef

  @container ~r/^(pt|ch)\./

  @doc "The changes, the repeals of a law revoked whole marked; `ids` the law's row ids."
  @spec state([Change.t()], [String.t()]) :: [Change.t()]
  def state(changes, ids) do
    case whole_days(changes, ids) do
      [] -> changes
      days -> Enum.map(changes, &if(day(&1) in days, do: stated(&1), else: &1))
    end
  end

  @doc "True when the resolved change is a repeal of a law revoked whole (`state/2`)."
  @spec whole?(map()) :: boolean()
  def whole?(%{sources: %{reach: :whole_law}}), do: true
  def whole?(_resolved), do: false

  @doc "Each `{law, day}` on which `law` repealed every top-level provision of `ids`."
  @spec whole_days([Change.t()], [String.t()]) :: [{String.t(), Date.t()}]
  def whole_days(changes, ids) do
    tops = tops(ids)

    repealed =
      changes
      |> Enum.filter(&day/1)
      |> Enum.group_by(&day/1, &untagged(&1.target))

    for {day, targets} <- repealed,
        tops != [],
        tops -- targets == [],
        do: day
  end

  @doc "The top-level provisions of the rows `ids`: no row holds them."
  @spec tops([String.t()]) :: [String.t()]
  def tops(ids) do
    ids
    |> Enum.map(&(&1 |> untagged() |> LatRef.ancestors() |> List.last()))
    |> Enum.reject(&Regex.match?(@container, &1))
    |> Enum.uniq()
  end

  # the law and the day of a dated whole-provision repeal, else nil
  defp day(%Change{
         target: target,
         resolved: %{operation: :repealed, level: :provision, by: by, date: %Date{} = date}
       })
       when is_binary(by) and is_binary(target),
       do: {by, date}

  defp day(_change), do: nil

  defp stated(%Change{resolved: %{sources: %{level: nil} = sources} = r} = c),
    do: %{c | resolved: %{r | sources: Map.put(sources, :reach, :whole_law)}}

  defp stated(c), do: c

  defp untagged(id), do: String.replace(id, ~r/\[[^\]]+\]$/, "")
end
