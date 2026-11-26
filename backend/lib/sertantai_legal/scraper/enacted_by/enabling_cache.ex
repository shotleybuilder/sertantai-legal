defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCache do
  @moduledoc """
  An SI's enabling provisions, fetched from its made introduction (never
  the body; a revoked SI's asked for by version: CV-07), parsed by `EnactedBy.EnablingProvisions` and cached in
  `data/cache/enabling/<law>.json` with the parser that wrote it
  (`ParserVersion`: `{"parser", "provisions"}`).

  Shared by `mix live.enabling` (enabling-extent evidence) and `mix lat.scope
  --relevance` (#166: which Parts of a large Act its SIs are made under).
  """

  alias SertantaiLegal.Scraper.EnactedBy
  alias SertantaiLegal.Scraper.EnactedBy.{EnablingProvisions, IntroductionXml}
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache.ParserVersion
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

  @cache Path.join(["data", "cache", "enabling"])

  @doc """
  The cached provisions for `name`, fetching (and caching) them on a miss.
  `retry_empty: true` fetches again where none were parsed before (the
  parser has since learnt a form: CV-07, Acts named in plain words). An
  entry parsed by older code (`ParserVersion`) is re-parsed from the
  introduction held first, never fetched. `:dir`: the cache (tests).
  """
  @spec get(String.t(), keyword()) :: [map()]
  def get(name, opts \\ []) do
    case entry(name, opts) do
      {:current, []} -> if opts[:retry_empty], do: store(name, fetch(name), opts), else: []
      {:current, ps} -> ps
      {:behind, ps} -> name |> refresh(ps, opts) |> retry(name, opts)
      :none -> store(name, fetch(name), opts)
    end
  end

  defp retry([], name, opts),
    do: if(opts[:retry_empty], do: store(name, fetch(name), opts), else: [])

  defp retry(ps, _name, _opts), do: ps

  @doc """
  The cached provisions for `name`, never fetching: `{:ok, provisions}` or
  `:none`. An entry parsed by older code is re-parsed from the introduction
  held (kept as it was where none is held). `:dir`: the cache (tests).
  """
  @spec cached(String.t(), keyword()) :: {:ok, [map()]} | :none
  def cached(name, opts \\ []) do
    case entry(name, opts) do
      {:current, ps} -> {:ok, ps}
      {:behind, ps} -> {:ok, refresh(name, ps, opts)}
      :none -> :none
    end
  end

  # an entry and whether this parser wrote it: a bare list was written
  # before entries recorded their parser (the Extent reader stamps session)
  defp entry(name, opts) do
    case File.read(path(name, opts)) do
      {:ok, json} -> json |> Jason.decode!() |> current()
      _ -> :none
    end
  end

  defp current(%{"parser" => v, "provisions" => ps}) do
    if v == ParserVersion.current(), do: {:current, ps}, else: {:behind, ps}
  end

  defp current(ps) when is_list(ps), do: {:behind, ps}

  # re-parsed from the introduction held; where none is, as cached
  defp refresh(name, old, opts) do
    case reparse(name, opts) do
      {:ok, ps} -> ps
      :not_held -> old
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
  Whether legislation.gov.uk has no introduction for the law: both its
  introduction paths stored as missing (a 404), never fetching.
  """
  @spec absent_upstream?(String.t()) :: boolean()
  def absent_upstream?(name) do
    case String.split(name, "_") do
      ["UK", type, year | number] when number != [] ->
        number = Enum.join(number, "_")

        Enum.all?(
          [EnactedBy.introduction_path(type, year, number), made_path(type, year, number)],
          &match?({:missing, _}, ClmlStore.get(&1))
        )

      _ ->
        false
    end
  end

  @doc """
  Re-parses the cached provisions from the held introduction (`from_store/1`)
  and writes them: `{:ok, provisions}`, or `:not_held` (the cache untouched).
  """
  @spec reparse(String.t(), keyword()) :: {:ok, [map()]} | :not_held
  def reparse(name, opts \\ []) do
    case from_store(name) do
      {:ok, ps} -> {:ok, store(name, ps, opts)}
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
      {:ok, xml, _meta} -> {:ok, IntroductionXml.parse(xml)}
      _ -> :none
    end
  end

  defp provisions(text, urls) do
    text
    |> EnablingProvisions.parse(urls, titles(text))
    |> Enum.map(&%{"law" => &1.law, "sections" => &1.sections, "schedules" => &1.schedules})
  end

  defp path(name, opts), do: Path.join(Keyword.get(opts, :dir, @cache), name <> ".json")

  # with the parser that wrote it (`ParserVersion`)
  defp store(name, ps, opts) do
    path = path(name, opts)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(%{"parser" => ParserVersion.current(), "provisions" => ps}))
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
  # (title_en holds no year: "European Communities Act" + year; some hold
  # it already, "Public Bodies Act 2011": SI 2013/755, 2026-11-09)
  defp titles(text) do
    case EnablingProvisions.titles(text) do
      [] ->
        %{}

      wanted ->
        %{rows: rows} =
          SertantaiLegal.Repo.query!(
            """
            SELECT t, name FROM (
              SELECT CASE WHEN title_en ~ (' ' || year || '$') THEN lower(title_en)
                          ELSE lower(title_en || ' ' || year) END AS t, name, type_code
              FROM uk_lrt) r
            WHERE t = ANY($1)
              AND type_code IN ('ukpga', 'asp', 'anaw', 'asc', 'nia', 'apni', 'nisi')
            """,
            [wanted]
          )

        # (a title naming two laws identifies neither: the register holds
        # "Freedom of Information (Scotland) Act 2002" as asp 2002/13 and
        # ukpga 2002/13, SSI 2008/339; Waste, Water and Climate, 2026-11-26)
        rows
        |> Enum.group_by(fn [t, _] -> t end, fn [_, n] -> n end)
        |> Enum.flat_map(fn
          {t, [n]} -> [{t, n}]
          {_t, _several} -> []
        end)
        |> Map.new()
    end
  end
end
