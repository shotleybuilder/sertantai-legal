defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCache do
  @moduledoc """
  An SI's enabling provisions, fetched from its made introduction (never
  the body; a revoked SI's asked for by version: CV-07), parsed by `EnactedBy.EnablingProvisions` and cached in
  `data/cache/enabling/<law>.json`.

  Shared by `mix live.enabling` (enabling-extent evidence) and `mix lat.scope
  --relevance` (#166: which Parts of a large Act its SIs are made under).
  """

  alias SertantaiLegal.Scraper.EnactedBy
  alias SertantaiLegal.Scraper.EnactedBy.EnablingProvisions
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @cache Path.join(["data", "cache", "enabling"])

  @doc """
  The cached provisions for `name`, fetching (and caching) them on a miss.
  `retry_empty: true` fetches again where none were parsed before (the
  parser has since learnt a form: CV-07, Acts named in plain words).
  """
  @spec get(String.t(), keyword()) :: [map()]
  def get(name, opts \\ []) do
    path = Path.join(@cache, name <> ".json")

    case File.read(path) do
      {:ok, json} when json != "[]" ->
        Jason.decode!(json)

      {:ok, _empty} ->
        if opts[:retry_empty], do: store(path, fetch(name)), else: []

      _ ->
        store(path, fetch(name))
    end
  end

  @doc "The cached provisions for `name`, never fetching: `{:ok, provisions}` or `:none`."
  @spec cached(String.t()) :: {:ok, [map()]} | :none
  def cached(name) do
    case File.read(Path.join(@cache, name <> ".json")) do
      {:ok, json} -> {:ok, Jason.decode!(json)}
      _ -> :none
    end
  end

  @doc """
  The provisions parsed from the introduction held in the CLML store, never
  fetching: `{:ok, provisions}`, or `:not_held` where no introduction is
  stored (the usual path, else the made version where the usual one is the
  repealed placeholder).
  """
  @spec from_store(String.t()) :: {:ok, [map()]} | :not_held
  def from_store(name) do
    with ["UK", type, year | number] when number != [] <- String.split(name, "_"),
         {:ok, %{text: text, urls: urls}} <-
           stored_introduction(type, year, Enum.join(number, "_")) do
      {:ok, provisions(text, urls)}
    else
      _ -> :not_held
    end
  end

  @doc """
  Re-parses the cached provisions from the held introduction (`from_store/1`)
  and writes them: `{:ok, provisions}`, or `:not_held` (the cache untouched).
  """
  @spec reparse(String.t()) :: {:ok, [map()]} | :not_held
  def reparse(name) do
    case from_store(name) do
      {:ok, ps} -> {:ok, store(Path.join(@cache, name <> ".json"), ps)}
      :not_held -> :not_held
    end
  end

  defp stored_introduction(type, year, number) do
    case stored_enacting(EnactedBy.introduction_path(type, year, number)) do
      {:ok, %{text: text}} = ok ->
        if placeholder?(text), do: stored_enacting(made_path(type, year, number)), else: ok

      _ ->
        stored_enacting(made_path(type, year, number))
    end
  end

  defp stored_enacting(path) do
    case ClmlStore.get(path) do
      {:ok, xml, _meta} -> {:ok, EnactedBy.parse_enacting_xml(xml)}
      _ -> :none
    end
  end

  defp provisions(text, urls) do
    text
    |> EnablingProvisions.parse(urls, titles(text))
    |> Enum.map(&%{"law" => &1.law, "sections" => &1.sections, "schedules" => &1.schedules})
  end

  defp store(path, ps) do
    File.mkdir_p!(@cache)
    File.write!(path, Jason.encode!(ps))
    ps
  end

  defp fetch(name) do
    with ["UK", type, year | number] when number != [] <- String.split(name, "_"),
         number = Enum.join(number, "_"),
         {:ok, %{text: text, urls: urls}} <- introduction(type, year, number) do
      provisions(text, urls)
    else
      _ -> []
    end
  end

  # the made introduction: the usual path, else — a revoked SI, whose
  # usual path falls back to the current, repealed text — the made
  # version asked for by name (CV-07)
  defp introduction(type, year, number) do
    case EnactedBy.fetch_enacting_data(EnactedBy.introduction_path(type, year, number)) do
      {:ok, %{text: text}} = ok ->
        if placeholder?(text),
          do: EnactedBy.fetch_enacting_data(made_path(type, year, number)),
          else: ok

      _ ->
        EnactedBy.fetch_enacting_data(made_path(type, year, number))
    end
  end

  @doc "True for no text, or legislation.gov.uk's repealed placeholder (\". . . .\")."
  @spec placeholder?(String.t() | nil) :: boolean()
  def placeholder?(nil), do: true
  def placeholder?(text), do: String.trim(String.replace(text, ".", "")) == ""

  @doc "The made introduction's path, asked for by version."
  @spec made_path(String.t(), String.t(), String.t()) :: String.t()
  def made_path(type, year, number), do: "/#{type}/#{year}/#{number}/introduction/made/data.xml"

  # the Acts the powers clause names in plain words, by register title
  # (title_en holds no year: "European Communities Act" + year)
  defp titles(text) do
    case EnablingProvisions.titles(text) do
      [] ->
        %{}

      wanted ->
        %{rows: rows} =
          SertantaiLegal.Repo.query!(
            """
            SELECT lower(title_en || ' ' || year), name FROM uk_lrt
            WHERE lower(title_en || ' ' || year) = ANY($1)
              AND type_code IN ('ukpga', 'asp', 'anaw', 'asc', 'nia', 'apni', 'nisi')
            """,
            [wanted]
          )

        Map.new(rows, fn [t, n] -> {t, n} end)
    end
  end
end
