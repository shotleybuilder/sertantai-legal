defmodule SertantaiLegal.Scraper.ChangeVocabulary.Merge.Compound do
  @moduledoc """
  The pieces of the feed's compound amending provision. legislation.gov.uk's
  changes feed names two sibling pieces of one amending provision in one
  string: "reg.4(2)(a)(b)" is reg.4(2)(a) and reg.4(2)(b), "reg.10(1)(3)"
  is (1) and (3) (NISR 2007/165 on NISR 1996/228 reg.2(1); Fire and OH&S:
  Merge, Decision 1).

  The last two bracket groups are siblings only when of one kind: both
  numbers ("(1A)(2)"), both roman numerals ("(i)(ii)"), or both letters
  ("(a)(e)"). A nesting is never expanded ("(a)(i)", "(1)(a)"), nor a letter
  beside what may be a roman numeral ("(h)(i)": ambiguous). The feed reader
  carries the string as written; the merge reads it here, for identity only.
  Pure.
  """

  @last_two ~r/\A(.+)\(([^()]+)\)\(([^()]+)\)\z/

  @doc "A feed affecting provision's pieces: a compound's two siblings, else the ref itself."
  @spec pieces(String.t()) :: [String.t()]
  def pieces(ref) do
    case Regex.run(@last_two, ref) do
      [_, stem, a, b] when a != b ->
        if siblings?(kind(a), kind(b)), do: ["#{stem}(#{a})", "#{stem}(#{b})"], else: [ref]

      _ ->
        [ref]
    end
  end

  @doc "Every piece of a list of feed affecting provisions, in order, once each."
  @spec expand([String.t()]) :: [String.t()]
  def expand(refs), do: refs |> Enum.flat_map(&pieces/1) |> Enum.uniq()

  defp siblings?(kind, kind) when kind != nil, do: true
  defp siblings?(_, _), do: false

  # a roman numeral is read before a letter, so "(h)(i)" is two kinds
  defp kind(group) do
    cond do
      group =~ ~r/\A\d+[A-Z]*\z/ -> :number
      group =~ ~r/\A[ivx]+\z/ -> :roman
      group =~ ~r/\A[a-z]+\z/ -> :letter
      true -> nil
    end
  end
end
