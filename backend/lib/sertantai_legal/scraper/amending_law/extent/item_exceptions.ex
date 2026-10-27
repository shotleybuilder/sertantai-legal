defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ItemExceptions do
  @moduledoc """
  What a list item excepts from itself (CV-S05 round 11, from the CV-S05c
  census, classes B and F): in brackets ("Chapter 3 of Part 1 (with the
  exception of section 59 …)", "(excluding paragraph 5(3) of Schedule 8
  and section 91)") or after the item's words ("Part 1, apart from sections
  17 and 18", "Part 3, except for section 163(3)", "Part 2 … but excluding
  sections 60 and 61, Schedule 5 …"); and the provisions read less what is
  excepted, one only some of which is excepted withheld. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.RefList

  @except_words "(?:except(?:\\s+for)?|other\\s+than|excluding|apart\\s+from|with\\s+the\\s+exception\\s+of)"

  # one bracket deep: "(with the exception of section 59 and paragraphs 1,
  # … 10(1) and (2) … of Schedule 14)"
  @bracketed Regex.compile!("\\s*\\(\\s*#{@except_words}\\s+((?:[^()]|\\([^()]*\\))*)\\)", "iu")

  # to the item's end
  @tail Regex.compile!("(?:\\s*,\\s*|\\s+)(?:but\\s+)?#{@except_words}\\s+(.+)$", "iu")

  @doc """
  An item split at its exception: `{item without it, the exception's words
  (nil: none), where it starts, its length}`. The words exclude what the
  exception refers on to ("…, except as provided by subsection (2)").
  """
  @spec split(String.t()) :: {String.t(), String.t() | nil, non_neg_integer(), non_neg_integer()}
  def split(item) do
    case Regex.run(@bracketed, item, return: :index) do
      [{at, len}, {ex_at, ex_len}] ->
        {binary_part(item, 0, at) <>
           " " <> binary_part(item, at + len, byte_size(item) - at - len),
         words(binary_part(item, ex_at, ex_len)), at, len}

      nil ->
        case Regex.run(@tail, item, return: :index) do
          [{at, len}, {ex_at, ex_len}] ->
            {binary_part(item, 0, at), words(binary_part(item, ex_at, ex_len)), at, len}

          nil ->
            {item, nil, 0, 0}
        end
    end
  end

  defp words(text),
    do: String.replace(text, ~r/,?\s*except\s+as\s+(?:provided|mentioned|specified)\b.*$/iu, "")

  @doc """
  Whether `ref` is `excepted` (`:excepted`), or holds one of them
  (`:holds`: "s.163" when "s.163(3)" is excepted, so it can be read whole
  no more).
  """
  @spec touched?(String.t(), [String.t()]) :: :excepted | :holds | false
  def touched?(ref, excepted) do
    cond do
      Enum.any?(excepted, &(&1 == ref or RefList.covers?(&1, ref))) -> :excepted
      Enum.any?(excepted, &RefList.covers?(ref, &1)) -> :holds
      true -> false
    end
  end

  @doc "`refs` less the `excepted`: `{read whole, holding one excepted (to withhold)}`."
  @spec apart([String.t()], [String.t()]) :: {[String.t()], [String.t()]}
  def apart(refs, excepted) do
    refs
    |> Enum.reject(&(touched?(&1, excepted) == :excepted))
    |> Enum.split_with(&(touched?(&1, excepted) == false))
  end
end
