defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache do
  @moduledoc """
  A law's extent reading, kept between runs (run time, 2026-10-25): its
  `Extent.Reader.withheld/1` (the statements and the catalogue classes,
  `Patterns.classes/2`), the catalogue's example with the classes it reads
  alone (`Patterns.Example.example/1`, `read/2`), and the extent-ish sentences the catalogue misses
  (`Sweep.uncaught/2`) — the work the extent catalogue, the check and the
  re-read share, done once per law and re-used until something it rests on
  changes.

  Keyed by the code version (`version/0`: the document reading's and the
  catalogue's own stamps, held by `ExtentReadStampsTest` — a change to any
  of their files re-reads every law, never a stale reading) and the law's stored text files (path
  and a digest of their bytes: a changed text is read again).
  Stored as one file per law under `data/cache/extent_reads/`; a law with
  no text held is not cached. Pure in what it returns: the reading is the
  same with or without the cache.
  """

  require Logger

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Reader, Store, Sweep}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion.{Catalogue, Document}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns.Example
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @dir Path.join(["data", "cache", "extent_reads"])

  @type reading :: %{
          read: Extent.t(),
          classes: [{String.t(), String.t(), String.t()}],
          example: String.t() | nil,
          alone: [{String.t(), String.t(), String.t()}],
          uncaught: [{String.t(), String.t(), String.t()}]
        }

  @doc """
  The law's reading (`reading/0`), from the cache when current; nil when no
  text is held. `opts`: `:dir` (the cache), `:root` (the CLML store),
  `:doc` (the law's document, already parsed from those files: not parsed
  again on a miss).
  """
  @spec law(String.t(), keyword()) :: reading() | nil
  def law(law, opts \\ []), do: law |> fetch(opts) |> elem(0)

  @doc """
  As `law/2`, with whether the reading came from the cache (`:hit`) or was
  computed (`:read`): what a catalogue's run record counts (`CatalogueRun`).
  A law with no text held is `{nil, :read}`.
  """
  @spec fetch(String.t(), keyword()) :: {reading() | nil, :hit | :read}
  def fetch(law, opts \\ []) do
    case ClmlStore.law_files(law, Keyword.take(opts, [:root])) do
      [] ->
        {nil, :read}

      files ->
        key = {version(), fingerprint(files)}
        path = Path.join(Keyword.get(opts, :dir, @dir), law <> ".bin")

        case read_file(path) do
          {^key, reading} ->
            {reading, :hit}

          _ ->
            reading = compute(law, files, opts[:doc])
            write_file(path, {key, reading})
            {reading, :read}
        end
    end
  end

  @doc "The reading computed, never from the cache."
  @spec compute(String.t(), [String.t()], Doc.t() | nil) :: reading()
  def compute(law, files, doc \\ nil) do
    doc = doc || Doc.new(law, Enum.map(files, &(&1 |> File.read!() |> :zlib.gunzip())))
    {read, classes} = read_classes(doc)
    example = if classes != [], do: Example.example(doc)

    %{
      read: read,
      classes: classes,
      example: example,
      alone: if(example, do: Example.read(law, example), else: []),
      # the sentences the catalogue misses (CV-S05a)
      uncaught: Sweep.uncaught(doc, classes)
    }
  end

  @doc "Every held law of a type whose extent the reader reads (its body in the CLML store)."
  @spec held() :: [String.t()]
  def held do
    for path <- Path.wildcard("data/cache/clml/*/*/*/body/data.xml.gz"),
        [t, y, n | _] = path |> Path.relative_to("data/cache/clml") |> Path.split(),
        law = "UK_#{t}_#{y}_#{n}",
        Store.reads?(law),
        uniq: true,
        do: law
  end

  @doc """
  The law's extent from its document, computed (never from the cache):
  `Extent.Reader.withheld/1`: the statements read, with the bounds the
  unread ones withhold (`Extent.Unread`, CV-S05 round 6).
  """
  @spec read(Doc.t()) :: Extent.t()
  def read(%Doc{} = doc), do: doc |> read_classes() |> elem(0)

  # the statements read, the catalogue's classes of every sentence (read
  # against those statements), then the bounds the unread ones withhold
  defp read_classes(doc), do: Reader.withheld(doc)

  @doc """
  The code version: the document reading's (`ReadVersion.Document`) and
  the catalogue's own (`ReadVersion.Catalogue`), so an amendment-reader
  change, a powers change or a tool's leaves the cache warm (run time
  2026-10-26; it was a digest of every module of the app, then the whole
  extent folder until the Extent reader stamps session).
  """
  @spec version() :: String.t()
  def version, do: Document.current() <> "+" <> Catalogue.current()

  # each file's path and a digest of its stored bytes
  defp fingerprint(files), do: for(f <- files, do: {f, :erlang.md5(File.read!(f))})

  # never an executable term (sobelow). Atoms are allowed: a reading holds
  # atoms that exist only once the reader's modules load, and `[:safe]`
  # refused them in a fresh VM, so every such law was read again, silently
  # (#192, 2026-11-07). A file that won't decode says so.
  defp read_file(path) do
    case File.read(path) do
      {:ok, bin} -> decode(path, bin)
      _ -> nil
    end
  end

  defp decode(path, bin) do
    Plug.Crypto.non_executable_binary_to_term(bin)
  rescue
    e ->
      Logger.warning(
        "extent read cache: #{path} won't decode (#{Exception.message(e)}); reading again"
      )

      nil
  end

  # written to a temp file and renamed: never a partial copy
  defp write_file(path, term) do
    File.mkdir_p!(Path.dirname(path))
    tmp = path <> ".tmp#{System.unique_integer([:positive])}"
    File.write!(tmp, :erlang.term_to_binary(term, [:compressed]))
    File.rename!(tmp, path)
  end
end
