defmodule SertantaiLegal.Scraper.Amendment.Index do
  @moduledoc """
  The read pass's index for an amending law (amendment-rules AR-03/AR-04),
  beside its stored rules (`amendment_rules`): its element ids (for
  `Locator`), each repeals table's introducing section, the reader version
  that read it (`ReaderVersion`) and the laws it was read for. One JSON file
  per amending law under `data/cache/amendment-index/` (NAS-backed with
  `backend/data`).

  The stored rules stand for an amending law only when its index is
  `current?/2` for the law collected: read by this reader, for that law.
  Otherwise the collector reads the document (no silent loss for a law
  LAT-parsed, or an amending law first cited, after the read pass).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Reader, ReaderVersion}

  @dir "data/cache/amendment-index"

  @type t :: %{String.t() => term()}

  @doc "The index of `amending`, or nil when not read."
  @spec get(String.t()) :: t() | nil
  def get(amending) do
    case File.read(path(amending)) do
      {:ok, json} -> Jason.decode!(json)
      _ -> nil
    end
  end

  @doc "Write `amending`'s index from its document, read for `laws` (law names)."
  @spec write(String.t(), Doc.t(), [String.t()]) :: :ok
  def write(amending, doc, laws) do
    File.mkdir_p!(@dir)

    File.write!(
      path(amending),
      Jason.encode!(%{
        "elements" => Map.keys(doc.elements),
        "references" => Reader.references(doc),
        "reader" => ReaderVersion.current(),
        "laws" => Enum.sort(Enum.uniq(laws))
      })
    )
  end

  @doc "True when `index` was read by this reader (any law)."
  @spec fresh?(t() | nil) :: boolean()
  def fresh?(%{"reader" => v}), do: v == ReaderVersion.current()
  def fresh?(_), do: false

  @doc "True when `index` was read by this reader for `law`."
  @spec current?(t() | nil, String.t()) :: boolean()
  def current?(index, law), do: fresh?(index) and law in (index["laws"] || [])

  defp path(amending), do: Path.join(@dir, "#{amending}.json")
end
