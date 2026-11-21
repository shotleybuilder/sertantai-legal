defmodule SertantaiLegal.Scraper.Commencement.Order.OtherLaw do
  @moduledoc """
  The words of a commencement order that give provisions to a law by
  pointing at it: a statement's head naming the law whose provisions it
  lists ("The following provisions of the 2023 Act come into force …": SI
  2024/452, an order commencing two Acts), and "of that Act" after a law
  its item names ("section 3ZA of the Road Traffic Act 1988 has effect for
  the purposes of sections 3 and 3A of that Act": SI 2007/2472 art.2(h)).
  Whether a named law is the Act commenced is the caller's (`own?`). Pure
  text.
  """

  @law ~S"(?:the\s+\d{4}\s+(?:Act|Order|Measure)|(?:the\s+)?[A-Z][\w()',’.-]*\s+(?:(?:[A-Z(][\w()',’.-]*|of|and|for|the|in|on|at|to|with|etc\.)\s+){0,14}(?:Act|Order|Regulations|Measure)(?:\s+\([^()]*\))?\s+\d{4})"
  @head Regex.compile!("\\bprovisions?\\s+of\\s+(#{@law})", "u")
  @named Regex.compile!(@law, "u")
  @that ~r/\b(?i:(?:sub-?)?sections?|paragraphs?|Schedules?|regulations?|articles?|Parts?)\s+\d+(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*(?:\s*(?:,|and|to)\s*\d*(?:[A-Z]+\d*)*(?:\([0-9A-Za-z]+\))*)*\s+(?:of|to)\s+(?:that\s+(?:Act|Order|Measure)|those\s+Regulations)\b/u

  @type own? :: (String.t() -> boolean())

  @doc """
  True when a statement's `head` gives the provisions it lists to a law
  other than the Act commenced: "The following provisions of the 2023 Act
  come into force on 25th April 2024—" read for the Planning Act 2008.
  """
  @spec head?(String.t(), own?()) :: boolean()
  def head?(head, own?) do
    case Regex.run(@head, head) do
      [_, law] -> not own?.(bare(law))
      nil -> false
    end
  end

  @doc """
  `item` without the provisions "of that Act" where that Act is another
  law: the law last named before them in the item. With none named, or the
  Act commenced, they stay.
  """
  @spec drop_that_law(String.t(), own?()) :: String.t()
  def drop_that_law(item, own?) do
    @that
    |> Regex.scan(item, return: :index)
    |> Enum.reverse()
    |> Enum.reduce(item, fn [{at, len}], text ->
      if other_before?(binary_part(item, 0, at), own?),
        do: binary_part(text, 0, at) <> binary_part(text, at + len, byte_size(text) - at - len),
        else: text
    end)
  end

  defp other_before?(before, own?) do
    case Regex.scan(@named, before) do
      [] -> false
      named -> not (named |> List.last() |> hd() |> bare() |> own?.())
    end
  end

  defp bare(law), do: String.replace(law, ~r/^the\s+/, "")
end
