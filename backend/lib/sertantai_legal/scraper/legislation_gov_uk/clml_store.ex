defmodule SertantaiLegal.Scraper.LegislationGovUk.ClmlStore do
  @moduledoc """
  Local store of CLML fetched from legislation.gov.uk (#175), so parses,
  diffs and repairs don't re-fetch documents that haven't changed.

  Handles:
  - `cacheable?/1` — legislation documents only (`/<type>/<year>/<number>/…/data.xml`:
    body, fragments, introduction, contents); never changes feeds, `/new/`
    lists or search, which change by design
  - `put/3`, `put_missing/2`, `get/2` — gzipped document (or a 404 marker)
    plus `<path>.meta.json` (`fetched_at`, `dct_valid`, `status`), written to
    a temp file and renamed, so an interrupted write never leaves a partial copy
  - `fresh?/3` — a stored copy is fresh when its `dct:valid` is at least the
    law's latest known valid date (`legal_register.md_dct_valid_date`, kept
    current by the LRT scrape); with no date, when fetched within 30 days
  - `dct_valid/1` — the latest `<dct:valid>` in a document (pure)

  Root: `opts[:root]`, else `config :sertantai_legal, :clml_store_dir`
  (default `data/cache/clml`); `nil` disables the store (tests).
  """

  @default_root Path.join(["data", "cache", "clml"])
  @ttl_days 30
  @document ~r"^/(?!changes/|new/)[a-z]+/\d{4}/[^/?]+(?:/[^?]*)?/data\.xml$"

  @type meta :: %{fetched_at: DateTime.t(), dct_valid: Date.t() | nil, status: String.t()}

  @doc "Whether a request path is a legislation document the store keeps."
  @spec cacheable?(String.t()) :: boolean()
  def cacheable?(path), do: Regex.match?(@document, path)

  @doc "Store a fetched document."
  @spec put(String.t(), String.t(), keyword()) :: :ok
  def put(path, body, opts \\ []) do
    with_root(opts, :ok, fn root ->
      write!(file(root, path), :zlib.gzip(body))
      write_meta!(root, path, %{"status" => "ok", "dct_valid" => date_string(dct_valid(body))})
    end)
  end

  @doc "Store a 404 (so fallbacks like regulation → article → rule aren't retried)."
  @spec put_missing(String.t(), keyword()) :: :ok
  def put_missing(path, opts \\ []) do
    with_root(opts, :ok, fn root ->
      File.rm(file(root, path))
      write_meta!(root, path, %{"status" => "missing", "dct_valid" => nil})
    end)
  end

  @doc "`{:ok, body, meta}`, `{:missing, meta}` (a stored 404) or `:none`."
  @spec get(String.t(), keyword()) :: {:ok, String.t(), meta()} | {:missing, meta()} | :none
  def get(path, opts \\ []) do
    with_root(opts, :none, fn root ->
      with {:ok, json} <- File.read(file(root, path) <> ".meta.json"),
           meta = parse_meta(json) do
        case meta.status do
          "missing" ->
            {:missing, meta}

          _ ->
            case File.read(file(root, path)) do
              {:ok, gz} -> {:ok, :zlib.gunzip(gz), meta}
              _ -> :none
            end
        end
      else
        _ -> :none
      end
    end)
  end

  @doc """
  Whether a stored copy can be used for a law whose latest known valid date
  is `law_valid` (nil = unknown). `opts[:now]` for tests.
  """
  @spec fresh?(meta(), Date.t() | nil, keyword()) :: boolean()
  def fresh?(meta, law_valid, opts \\ []) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    case {meta.dct_valid, law_valid} do
      {%Date{} = doc, %Date{} = law} -> Date.compare(doc, law) != :lt
      _ -> DateTime.diff(now, meta.fetched_at, :day) <= @ttl_days
    end
  end

  @doc "The latest `<dct:valid>` date in a document, or nil."
  @spec dct_valid(String.t()) :: Date.t() | nil
  def dct_valid(body) do
    ~r/<dct:valid>(\d{4}-\d{2}-\d{2})<\/dct:valid>/
    |> Regex.scan(body, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&Date.from_iso8601!/1)
    |> Enum.max(Date, fn -> nil end)
  end

  @doc "The configured root (nil = disabled)."
  @spec root(keyword()) :: String.t() | nil
  def root(opts \\ []) do
    Keyword.get_lazy(opts, :root, fn ->
      Application.get_env(:sertantai_legal, :clml_store_dir, @default_root)
    end)
  end

  defp with_root(opts, disabled, fun) do
    case root(opts) do
      nil -> disabled
      root -> fun.(root)
    end
  end

  defp file(root, path), do: Path.join(root, String.trim_leading(path, "/") <> ".gz")

  defp write_meta!(root, path, fields) do
    meta = Map.put(fields, "fetched_at", DateTime.utc_now() |> DateTime.to_iso8601())
    write!(file(root, path) <> ".meta.json", Jason.encode!(meta))
  end

  defp write!(target, data) do
    File.mkdir_p!(Path.dirname(target))
    tmp = target <> ".tmp#{System.unique_integer([:positive])}"
    File.write!(tmp, data)
    File.rename!(tmp, target)
    :ok
  end

  defp parse_meta(json) do
    m = Jason.decode!(json)
    {:ok, fetched_at, _} = DateTime.from_iso8601(m["fetched_at"])

    %{
      status: m["status"],
      fetched_at: fetched_at,
      dct_valid: m["dct_valid"] && Date.from_iso8601!(m["dct_valid"])
    }
  end

  defp date_string(nil), do: nil
  defp date_string(date), do: Date.to_iso8601(date)
end
