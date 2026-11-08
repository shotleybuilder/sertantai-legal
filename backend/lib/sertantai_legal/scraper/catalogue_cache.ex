defmodule SertantaiLegal.Scraper.CatalogueCache do
  @moduledoc """
  One law's part of a whole-store catalogue, kept between runs (#195): a
  re-run reads only the laws whose inputs or catalogue code moved, as
  `Extent.ReadCache` does for the extent reading.

  Keyed by the catalogue's code version (a `SourceVersion`, held by
  `VersionCoverageTest` to every module it reaches) and a digest of the
  inputs the catalogue gathered for the law: its stored files' digests and
  its rows. Every input is in the key because the catalogue computes from
  nothing else. One file per law under `data/cache/catalogues/<catalogue>/`.
  Pure in what it returns: the result is the same with or without the
  cache.
  """

  require Logger

  @dir Path.join(["data", "cache", "catalogues"])

  @doc """
  The law's result from the cache when its key is current, else `fun.()`
  stored: `{result, :hit | :read}`. `opts`: `:dir` (the cache's root),
  `:cache` (false: always computed, never stored).
  """
  @spec fetch(String.t(), String.t(), String.t(), term(), (-> result), keyword()) ::
          {result, :hit | :read}
        when result: term()
  def fetch(catalogue, law, version, inputs, fun, opts \\ []) do
    if Keyword.get(opts, :cache, true) do
      key = {version, digest(inputs)}
      path = Path.join([Keyword.get(opts, :dir, @dir), catalogue, law <> ".bin"])

      case read_file(path) do
        {^key, result} ->
          {result, :hit}

        _ ->
          result = fun.()
          write_file(path, {key, result})
          {result, :read}
      end
    else
      {fun.(), :read}
    end
  end

  @doc "A file's digest, for a catalogue's inputs; nil for no file."
  @spec file_digest(String.t() | nil) :: binary() | nil
  def file_digest(nil), do: nil

  def file_digest(path) do
    case File.read(path) do
      {:ok, bin} -> :erlang.md5(bin)
      _ -> nil
    end
  end

  @doc "The cache line a catalogue prints: hits and laws read."
  @spec summary([:hit | :read]) :: String.t()
  def summary(sources) do
    f = Enum.frequencies(sources)
    "cache: #{Map.get(f, :hit, 0)} hits, #{Map.get(f, :read, 0)} read"
  end

  defp digest(inputs),
    do: :crypto.hash(:sha256, :erlang.term_to_binary(inputs, [:deterministic]))

  # never an executable term (sobelow). Atoms are allowed, as in
  # `Extent.ReadCache` (#192: atoms that exist only once the reader's
  # modules load); a file that won't decode says so and is read again.
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
        "catalogue cache: #{path} won't decode (#{Exception.message(e)}); reading again"
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
