defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.LawReading do
  @moduledoc """
  What the shape checks read for one law (#192): its documents from the
  CLML store (`AmendingLaw.Doc`) and the extent reader's stored reading
  (`Extent.ReadCache`), and the mined items regrouped into their
  sentences. Reads the store and the cache; writes nothing.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @doc "`law`'s documents and the extent reader's reading of them."
  @spec load(String.t()) :: {Doc.t(), map()}
  def load(law) do
    doc =
      Doc.new(law, Enum.map(ClmlStore.law_files(law), &(&1 |> File.read!() |> :zlib.gunzip())))

    {doc, ReadCache.law(law, doc: doc).read}
  end

  @doc """
  `items.tsv`'s rows (its line number from 2, after the header), regrouped
  into sentences: a lead row and the item rows after it. Sentences with
  no items (kind "sentence") are dropped, as are those `keep?` refuses.
  """
  @spec sentences(String.t(), (map() -> boolean())) :: %{String.t() => [[map()]]}
  def sentences(items_tsv, keep? \\ fn _ -> true end) do
    items_tsv
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index(2)
    |> Enum.map(&row/1)
    |> Enum.chunk_while([], &chunk/2, fn acc -> {:cont, Enum.reverse(acc), []} end)
    |> Enum.filter(fn [h | _] -> h.kind == "lead" and keep?.(h) end)
    |> Enum.group_by(fn [h | _] -> h.law end)
  end

  # each field its own binary, never a slice of the whole file: a slice
  # sent to a worker takes the file with it, and the checks ran 2.6x
  # slower over slices (#192, 2026-11-07: verdicts 271 s against 102 s)
  defp row({line, i}) do
    [law, ref, class, kind, _letter, shape, _fine, text] =
      line |> String.split("\t") |> Enum.map(&:binary.copy/1)

    %{line: i, law: law, ref: ref, class: class, kind: kind, shape: shape, text: text}
  end

  defp chunk(r, acc) do
    if r.kind in ["lead", "sentence"] and acc != [],
      do: {:cont, Enum.reverse(acc), [r]},
      else: {:cont, [r | acc]}
  end

  @doc "A sentence's whole text from its lead and items, as the checks rebuild it."
  @spec whole([map()]) :: String.t()
  def whole([lead | items]), do: lead.text <> "—" <> Enum.map_join(items, "; ", & &1.text)

  @doc "`fun.(law, sentences)` per law, two at a time, the lines flattened."
  @spec per_law(%{String.t() => term()}, (String.t(), term() -> [String.t()])) :: [String.t()]
  def per_law(by_law, fun) do
    by_law
    |> Task.async_stream(fn {law, sents} -> fun.(law, sents) end,
      max_concurrency: 2,
      timeout: :infinity
    )
    |> Enum.flat_map(fn {:ok, lines} -> lines end)
  end

  @doc "A TSV: the header, then the lines sorted, each ended by a newline."
  @spec tsv(String.t(), [String.t()]) :: String.t()
  def tsv(header, lines), do: header <> "\n" <> Enum.join(Enum.sort(lines), "\n") <> "\n"
end
