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

  defp store(path, ps) do
    File.mkdir_p!(@cache)
    File.write!(path, Jason.encode!(ps))
    ps
  end

  defp fetch(name) do
    with ["UK", type, year | number] when number != [] <- String.split(name, "_"),
         number = Enum.join(number, "_"),
         {:ok, %{text: text, urls: urls}} <- introduction(type, year, number) do
      text
      |> EnablingProvisions.parse(urls, titles(text))
      |> Enum.map(&%{"law" => &1.law, "sections" => &1.sections, "schedules" => &1.schedules})
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
