defmodule SertantaiLegal.Scraper.LawStart.PointingBack do
  @moduledoc """
  The split of a commencement list at a closing qualifier that points back
  to provisions the list itself names: "… paragraphs 27 to 29 of Schedule
  18 (…), and sections 222 and 227, and Schedule 19 (consequential
  repeals), in so far as they relate to those paragraphs" (the Housing Act
  1996 s.232(2)). The qualifier limits the items standing after the
  paragraphs it points to; the paragraphs, and every item before them,
  come in fully (RULES `a-qualifier-binds-its-own-item`). Pure text.
  """

  @qualifier ~r/,?\s+(?:(?:in\s+)?so\s+far\s+as|insofar\s+as|to\s+the\s+extent\s+that)\s+they\s+relate\s+to\s+those\s+(paragraph|section|regulation|article|Part|Schedule)s\b.*$/is
  # where the items pointed back to end and the limited ones begin
  @next_item ~r/,\s+and\s+/

  @doc """
  `{the items in full, the items the qualifier limits}`; nil where the
  list closes on no such qualifier, or no item stands between the
  provisions pointed to and it.
  """
  @spec split(String.t()) :: {String.t(), String.t()} | nil
  def split(list) do
    with [{at, _}, {k, n}] <- Regex.run(@qualifier, list, return: :index),
         before = binary_part(list, 0, at),
         from when is_integer(from) <- pointed_to(before, binary_part(list, k, n)),
         [{b, len} | _] <- Regex.run(@next_item, before, offset: from, return: :index) do
      {binary_part(before, 0, b),
       before |> binary_part(b + len, byte_size(before) - b - len) |> String.trim()}
    else
      _ -> nil
    end
  end

  # where the last provisions of the qualifier's kind are named
  defp pointed_to(before, kind) do
    case Regex.scan(~r/\b#{kind}s?\s+[\dIVXL]/i, before, return: :index) do
      [] -> nil
      found -> found |> List.last() |> hd() |> elem(0)
    end
  end
end
