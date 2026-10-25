defmodule SertantaiLegal.Scraper.LegislationGovUk.FeedCache do
  @moduledoc """
  A law's changes-feed effects as parsed from its stored pages, kept between
  runs (run time, 2026-10-25): parsing every LAT law's pages took 160 s at
  the start of each amendment read pass, and golden and build parse them per
  law (110 ms a law; a cached parse loads in ~1.5 ms).

  Offline only (`store: :only`): keyed by the parser's code version
  (`FeedVersion`) and a digest of the stored pages, so a re-parse or a page
  fetched since is read again. One file per law under
  `data/cache/feed_effects/`.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.{ChangesFeed, ClmlStore, FeedVersion}

  @dir Path.join(["data", "cache", "feed_effects"])

  @doc """
  The law's effects from its stored pages (`ChangesFeed.fetch/4` with
  `store: :only`), from the cache when current. `opts`: `:root` (the
  CLML store's), `:dir` (the cache's).
  """
  @spec effects(String.t(), String.t(), String.t(), keyword()) ::
          {:ok, [ChangesFeed.Effect.t()]} | {:error, String.t()}
  def effects(type, year, number, opts \\ []) do
    store = [store: :only] ++ Keyword.take(opts, [:root])

    case ClmlStore.feed_files(type, year, number, Keyword.take(opts, [:root])) do
      [] ->
        ChangesFeed.fetch(type, year, number, store)

      files ->
        key = {FeedVersion.current(), Enum.map(files, &{Path.basename(&1), md5(&1)})}
        path = Path.join(Keyword.get(opts, :dir, @dir), "#{type}_#{year}_#{number}.bin")

        case read_file(path) do
          {^key, effects} ->
            {:ok, effects}

          _ ->
            with {:ok, effects} <- ChangesFeed.fetch(type, year, number, store) do
              write_file(path, {key, effects})
              {:ok, effects}
            end
        end
    end
  end

  defp md5(file), do: :erlang.md5(File.read!(file))

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
