defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCache do
  @moduledoc """
  An SI's enabling provisions, fetched from its introduction (never the
  body), parsed by `EnactedBy.EnablingProvisions` and cached in
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

  defp store(path, ps) do
    File.mkdir_p!(@cache)
    File.write!(path, Jason.encode!(ps))
    ps
  end

  defp fetch(name) do
    with ["UK", type, year | number] when number != [] <- String.split(name, "_"),
         {:ok, %{text: text, urls: urls}} <-
           EnactedBy.fetch_enacting_data(
             EnactedBy.introduction_path(type, year, Enum.join(number, "_"))
           ) do
      text
      |> EnablingProvisions.parse(urls, titles(text))
      |> Enum.map(&%{"law" => &1.law, "sections" => &1.sections, "schedules" => &1.schedules})
    else
      _ -> []
    end
  end

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
