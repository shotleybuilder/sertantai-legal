defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache do
  @moduledoc """
  A law's extent reading, kept between runs (run time, 2026-10-25): its
  `Extent.read/1`, its catalogue classes (`Patterns.classes/2`), and the
  catalogue's example with the classes it reads alone (`Patterns.example/1`,
  `Patterns.read/2`) — the work the extent catalogue, the check and the
  re-read share, done once per law and re-used until something it rests on
  changes.

  Keyed by the code version (a digest of every compiled module of the app:
  any code change re-reads every law, never a stale reading) and the law's
  stored text files (path and a digest of their bytes: a changed text is read again).
  Stored as one file per law under `data/cache/extent_reads/`; a law with
  no text held is not cached. Pure in what it returns: the reading is the
  same with or without the cache.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @dir Path.join(["data", "cache", "extent_reads"])

  @type reading :: %{
          read: Extent.t(),
          classes: [{String.t(), String.t(), String.t()}],
          example: String.t() | nil,
          alone: [{String.t(), String.t(), String.t()}]
        }

  @doc """
  The law's reading (`reading/0`), from the cache when current; nil when no
  text is held. `opts`: `:dir` (the cache), `:root` (the CLML store).
  """
  @spec law(String.t(), keyword()) :: reading() | nil
  def law(law, opts \\ []) do
    case ClmlStore.law_files(law, Keyword.take(opts, [:root])) do
      [] ->
        nil

      files ->
        key = {version(), fingerprint(files)}
        path = Path.join(Keyword.get(opts, :dir, @dir), law <> ".bin")

        case read_file(path) do
          {^key, reading} ->
            reading

          _ ->
            reading = compute(law, files)
            write_file(path, {key, reading})
            reading
        end
    end
  end

  @doc "The reading computed, never from the cache."
  @spec compute(String.t(), [String.t()]) :: reading()
  def compute(law, files) do
    doc = Doc.new(law, Enum.map(files, &(&1 |> File.read!() |> :zlib.gunzip())))
    read = Extent.read(doc)
    classes = Patterns.classes(doc, read)
    example = if classes != [], do: Patterns.example(doc)

    %{
      read: read,
      classes: classes,
      example: example,
      alone: if(example, do: Patterns.read(law, example), else: [])
    }
  end

  @doc "The code version: a digest of every module of the app, once per VM."
  @spec version() :: binary()
  def version do
    case :persistent_term.get({__MODULE__, :version}, nil) do
      nil ->
        {:ok, modules} = :application.get_key(:sertantai_legal, :modules)

        v =
          modules
          |> Enum.sort()
          |> Enum.map(& &1.module_info(:md5))
          |> then(&:crypto.hash(:sha256, &1))

        :persistent_term.put({__MODULE__, :version}, v)
        v

      v ->
        v
    end
  end

  # each file's path and a digest of its stored bytes
  defp fingerprint(files), do: for(f <- files, do: {f, :erlang.md5(File.read!(f))})

  defp read_file(path) do
    case File.read(path) do
      # never an executable term, never a new atom (sobelow)
      {:ok, bin} -> Plug.Crypto.non_executable_binary_to_term(bin, [:safe])
      _ -> nil
    end
  rescue
    _ -> nil
  end

  # written to a temp file and renamed: never a partial copy
  defp write_file(path, term) do
    File.mkdir_p!(Path.dirname(path))
    tmp = path <> ".tmp#{System.unique_integer([:positive])}"
    File.write!(tmp, :erlang.term_to_binary(term, [:compressed]))
    File.rename!(tmp, path)
  end
end
