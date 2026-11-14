defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedRange do
  @moduledoc """
  Whether a provision lying between a feed range's two ends is of the
  ends' own sequence.

  A range with a lettered end ("reg. 19A-19F", "s. 1(6A)-(6C)") names a
  run: 19B to 19E, (6B). A provision named by more letters than either end
  (19AA, 19AZA, (6AA)) stands outside that run: put between them later by
  another law, or made with them by the same law ("s. 174(2A)-(2B)"
  substituted with (2AA) to (2AC)). Which, the feed's own records say: the
  reader (`Feed`) drops from a range its effect made only such a provision
  that another law's effect inserts. A range of plain numbers ("reg. 3-7")
  is every provision between, lettered ones too; and a name with no number
  (a lettered or roman paragraph, a heading) is of the run.

  Pure: XML ids in, no document read.
  """

  @numbered ~r/^\d+([A-Za-z]*)$/

  @doc """
  Is `id`, lying between `first` and `last` in the document, one of the
  provisions the range names?
  """
  @spec member?(String.t(), String.t(), String.t()) :: boolean()
  def member?(id, first, last) do
    case max(letters(first) || 0, letters(last) || 0) do
      0 -> true
      most -> (letters(id) || 0) <= most
    end
  end

  # how many letters follow the number in an id's own (last) part: 0 for
  # "regulation-19", 2 for "regulation-19AA"; nil when it has no number
  defp letters(id) do
    case Regex.run(@numbered, id |> String.split("-") |> List.last()) do
      [_, suffix] -> String.length(suffix)
      nil -> nil
    end
  end
end
