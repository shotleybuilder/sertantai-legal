defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Dump do
  @moduledoc """
  Every held law's extent sentences, in full, with the reader's class
  (CV-S05c `dump.exs`, #192): `sentences.tsv` (law, ref, class, sentence),
  whitespace collapsed, lines sorted. Reads `Extent.ReadCache`.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache

  @doc "`sentences.tsv` for `laws` (default every held law), and the count of laws."
  @spec run([String.t()] | nil) :: {String.t(), non_neg_integer()}
  def run(laws \\ nil) do
    laws = laws || ReadCache.held()

    lines =
      laws
      |> Task.async_stream(&law/1, max_concurrency: 4, timeout: :infinity)
      |> Enum.flat_map(fn {:ok, l} -> l end)

    {"law\tref\tclass\tsentence\n" <> Enum.join(Enum.sort(lines), "\n") <> "\n", length(laws)}
  end

  defp law(law) do
    case ReadCache.law(law) do
      nil ->
        []

      r ->
        for {ref, s, c} <- r.classes,
            do: Enum.join([law, ref, c, String.replace(s, ~r/\s+/u, " ")], "\t")
    end
  end
end
