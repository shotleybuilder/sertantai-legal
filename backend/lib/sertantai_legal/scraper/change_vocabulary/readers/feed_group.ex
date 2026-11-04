defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedGroup do
  @moduledoc """
  A Part, Chapter or Title the changes feed names, as our rows name it
  when the feed spells its number otherwise than the text — Roman for
  Arabic (`part-7`, the text's `part-VII`: SI 1997/2962) or another letter
  case (`part-10A`, the text's `part-10a`: SI 2014/1613). Pure.
  """

  @kinds ~w(part chapter title)

  @doc """
  The ref for group id `id` among the rows' `xml_ids` (id → ref): the one
  row group with the same kinds and numbers; nil for an id that isn't a
  group's, that no row group has, or that two share.
  """
  @spec ref(String.t(), %{String.t() => String.t()}) :: String.t() | nil
  def ref(id, xml_ids) do
    case pairs(id) do
      nil -> nil
      pairs -> pick(matches(key(pairs), xml_ids))
    end
  end

  @doc "True for a Part, Chapter or Title id the feed names (`part-6`, `title-I-chapter-2`)."
  @spec group?(String.t()) :: boolean()
  def group?(id), do: pairs(id) != nil

  @doc "True when `ids` (the text's group ids) hold group `id`, however each numbers it."
  @spec held?(String.t(), [String.t()]) :: boolean()
  def held?(id, ids), do: matches(key(pairs(id)), Map.new(ids, &{&1, &1})) != []

  defp matches(key, xml_ids),
    do: for({x, ref} <- xml_ids, (p = pairs(x)) != nil, key(p) == key, uniq: true, do: ref)

  defp pick([ref]), do: ref
  defp pick(_none_or_shared), do: nil

  # "title-I-chapter-2" → [["title", "I"], ["chapter", "2"]]; nil unless
  # every segment pairs a group kind with its number
  defp pairs(id) do
    pairs = id |> String.split("-") |> Enum.chunk_every(2)

    if Enum.all?(pairs, &match?([kind, _] when kind in @kinds, &1)), do: pairs
  end

  defp key(pairs), do: Enum.map(pairs, fn [kind, n] -> {kind, number(n)} end)

  # a Roman numeral is its value; any other number in one letter case
  defp number(n) do
    if n =~ ~r/^[IVXL]+$/i, do: roman(String.upcase(n)), else: String.downcase(n)
  end

  @roman %{?I => 1, ?V => 5, ?X => 10, ?L => 50}

  defp roman(n) do
    values = n |> String.to_charlist() |> Enum.map(&@roman[&1])

    values
    |> Enum.zip(tl(values) ++ [0])
    |> Enum.reduce(0, fn {v, next}, acc -> if v < next, do: acc - v, else: acc + v end)
    |> Integer.to_string()
  end
end
