defmodule SertantaiLegal.Scraper.Amendment.Index do
  @moduledoc """
  The read pass's index for an amending law (amendment-rules AR-03/AR-04),
  beside its stored rules (`amendment_rules`): its element ids (for
  `Locator`), each repeals table's introducing section, each Schedule
  paragraph's Part (AR-12), the reader version
  that read it (`ReaderVersion`), the stored text it was read from
  (`ClmlStore.digest/1`) and the laws it was read for. One JSON file
  per amending law under `data/cache/amendment-index/` (NAS-backed with
  `backend/data`).

  The stored rules stand for an amending law only when its index is
  `current?/3` for the law collected: read by this reader, from the text
  held now, for that law.
  Otherwise the collector reads the document (no silent loss for a law
  LAT-parsed, or an amending law first cited, after the read pass).
  """

  alias SertantaiLegal.Scraper.Amendment.ReaderVersion
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

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

  @typedoc "What the read pass found in the document (`ReadPass.index_entries/1`)."
  @type entries :: %{elements: [String.t()], references: map(), parts: map()}

  @doc """
  Write `amending`'s index from its document's `entries` (element ids,
  repeals tables' sections, Schedule paragraphs' Parts:
  `ReadPass.index_entries/1`), read for `laws` (law names), at `pointers`
  (the provisions read: notes' and feed's, CV-07). The entries come in
  ready-made, so the index reaches no reading code and the build can ask
  `current?/3` without it (the Amending-law reader stamps session).
  """
  @spec write(String.t(), entries(), [String.t()], [String.t()]) :: :ok
  def write(
        amending,
        %{elements: elements, references: references, parts: parts},
        laws,
        pointers \\ []
      ) do
    File.mkdir_p!(@dir)

    File.write!(
      path(amending),
      Jason.encode!(%{
        "elements" => elements,
        "references" => references,
        "parts" => parts,
        "reader" => ReaderVersion.current(),
        "files" => ClmlStore.digest(amending),
        "laws" => Enum.sort(Enum.uniq(laws)),
        "pointers" => Enum.sort(Enum.uniq(pointers))
      })
    )
  end

  @doc "True when `amending`'s `index` was read by this reader from the text held now (any law)."
  @spec fresh?(String.t(), t() | nil) :: boolean()
  def fresh?(amending, %{"reader" => v, "files" => files}),
    do: v == ReaderVersion.current() and files == ClmlStore.digest(amending)

  def fresh?(_amending, _index), do: false

  @doc "True when `amending`'s `index` is fresh and was read for `law`."
  @spec current?(String.t(), t() | nil, String.t()) :: boolean()
  def current?(amending, index, law),
    do: fresh?(amending, index) and law in (index["laws"] || [])

  defp path(amending), do: Path.join(@dir, "#{amending}.json")
end
