defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.CopiedChangeIds do
  @moduledoc """
  The change elements whose ChangeId legislation.gov.uk copied from another
  change, keyed by their own note's effect.

  A ChangeId carries its effect's id (`key-<hex>-<number>`). Where a second
  change was marked by copying the first's ChangeId with a letter added,
  the id still names the first effect, while the element's CommentaryRef
  names its own: SI 2014/2384 art.2(1), the words "6.1 and" inserted under
  one effect (`…-1788518391375`), then "environmental statement"
  substituted under a second (`…-1788518391375w`, its note the second
  effect's). Such a change is its note's effect.

  The form is narrow on purpose: the ChangeId is another change element's
  ChangeId with one lower-case letter added, and its note is an effect id
  other than the one the ChangeId carries. A ChangeId under another
  effect's note without the copy (a whole-provision repeal marked on many
  elements, a territorial version's change) is common in the store and is
  not this form. Pure.
  """

  @copied ~r/^(key-[0-9a-f]{32})(-\d+)[a-z]$/

  @doc """
  Each copied ChangeId → its note's effect id, from the document's change
  elements as `{ChangeId, CommentaryRef}` pairs (`""` where none).
  """
  @spec keys([{String.t(), String.t()}]) :: %{String.t() => String.t()}
  def keys(elements) do
    ids = MapSet.new(elements, &elem(&1, 0))

    for {id, note} <- elements, copied?(id, note, ids), into: %{}, do: {id, note}
  end

  defp copied?(id, note, ids) do
    case Regex.run(@copied, id) do
      [_, effect, number] ->
        MapSet.member?(ids, effect <> number) and other_effect?(note, effect)

      nil ->
        false
    end
  end

  defp other_effect?(note, effect),
    do: note != effect and note =~ ~r/^key-[0-9a-f]{32}$/
end
