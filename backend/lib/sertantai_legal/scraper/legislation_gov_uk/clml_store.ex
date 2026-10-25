defmodule SertantaiLegal.Scraper.LegislationGovUk.ClmlStore do
  @moduledoc """
  Local store of CLML fetched from legislation.gov.uk (#175), so parses,
  diffs and repairs don't re-fetch documents that haven't changed.

  Handles:
  - `cacheable?/1` — legislation documents (`/<type>/<year>/<number>/…/data.xml`:
    body, fragments, introduction, contents) and changes-affected feed pages
    (`/changes/affected/<type>/<year>/<number>/data.feed?…&page=N`, stored as
    `…/data.feed.page-N`: the effects layer is measured offline, LR-03); never
    other changes lists, `/new/` lists or search. A feed has no `dct:valid`,
    so its freshness is its fetch age
  - `put/3`, `put_missing/2`, `get/2` — gzipped document (or a 404 marker)
    plus `<path>.meta.json` (`fetched_at`, `dct_valid`, `status`), written to
    a temp file and renamed, so an interrupted write never leaves a partial copy
  - `fresh?/3` — a stored copy is fresh when its `dct:valid` is at least the
    law's latest known valid date (`legal_register.md_dct_valid_date`, kept
    current by the LRT scrape); with no date, when fetched within 30 days
  - `dct_valid/1` — the latest `<dct:valid>` in a document (pure)
  - `law_docs/2`, `law_files/2` — a law's text as the readers read it: its
    body and its Schedules; scoped fragments (`section/44`, #166) only for
    a law with no body held, never beside it (a fragment repeats the
    body's ids and moves document positions: CV-S05 F)
  - storing a body removes the law's non-schedule fragments, storing its
    Schedules its schedule fragments (`remove_fragments/3`): the whole
    text replaces them

  Root: `opts[:root]`, else `config :sertantai_legal, :clml_store_dir`
  (default `data/cache/clml`); `nil` disables the store (tests).
  """

  @default_root Path.join(["data", "cache", "clml"])
  @ttl_days 30
  @document ~r"^/(?!changes/|new/)[a-z]+/\d{4}/[^/?]+(?:/[^?]*)?/data\.xml$"
  @feed ~r"^/changes/affected/[a-z]+/\d{4}/[^/?]+/data\.feed(?:\?.*)?$"

  # a law's fragment folders (#166 scoped LAT): the schedule ones, and the rest
  @schedule_fragments ~w(schedule)
  @body_fragments ~w(section part chapter crossheading article regulation rule paragraph)
  @whole ~r"^/([a-z]+/\d{4}/[^/]+)/(body|schedules)/data\.xml$"

  @type meta :: %{fetched_at: DateTime.t(), dct_valid: Date.t() | nil, status: String.t()}

  @doc "Whether a request path is a legislation document the store keeps."
  @spec cacheable?(String.t()) :: boolean()
  def cacheable?(path), do: Regex.match?(@document, path) or Regex.match?(@feed, path)

  @doc "Store a fetched document."
  @spec put(String.t(), String.t(), keyword()) :: :ok
  def put(path, body, opts \\ []) do
    with_root(opts, :ok, fn root ->
      write!(file(root, path), :zlib.gzip(body))
      write_meta!(root, path, %{"status" => "ok", "dct_valid" => date_string(dct_valid(body))})

      case Regex.run(@whole, path) do
        [_, law, "body"] -> remove_fragments(law, @body_fragments, root: root)
        [_, law, "schedules"] -> remove_fragments(law, @schedule_fragments, root: root)
        _ -> []
      end

      :ok
    end)
  end

  @doc """
  Remove a law's fragment folders (`slash`: \"ukpga/2007/15\"; `kinds`:
  folder names, default all) — their text is in the body or Schedules held.
  Returns the folders removed.
  """
  @spec remove_fragments(String.t(), [String.t()], keyword()) :: [String.t()]
  def remove_fragments(slash, kinds \\ @body_fragments ++ @schedule_fragments, opts \\ []) do
    with_root(opts, [], fn root ->
      for kind <- kinds,
          dir = Path.join([root, slash, kind]),
          File.dir?(dir) do
        File.rm_rf!(dir)
        dir
      end
    end)
  end

  @doc """
  A law's stored text files as the readers read them (`law`:
  \"UK_ukpga_2007_15\"): the body, else its fragments (sorted), then the
  Schedules, else the schedule fragments. Never the introduction or the
  made version (the enabling cache's), never a fragment beside the whole.
  """
  @spec law_files(String.t(), keyword()) :: [String.t()]
  def law_files(law, opts \\ []) do
    with_root(opts, [], fn root ->
      case String.split(law, "_", parts: 4) do
        [_, t, y, n] ->
          dir = Path.join([root, t, y, n])
          whole(dir, "body", @body_fragments) ++ whole(dir, "schedules", @schedule_fragments)

        _ ->
          []
      end
    end)
  end

  @doc "A law's stored text (`law_files/2`), each document gunzipped."
  @spec law_docs(String.t(), keyword()) :: [String.t()]
  def law_docs(law, opts \\ []),
    do: law |> law_files(opts) |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip()))

  @doc """
  A digest of the law's stored text (`law_files/2`'s files, their bytes):
  what a reading of it was made from, so a reading goes stale when the
  text held changes — Schedules stored, fragments removed (run time,
  2026-10-25: amendment indexes stayed "fresh" across both).
  """
  @spec digest(String.t(), keyword()) :: String.t()
  def digest(law, opts \\ []) do
    law
    |> law_files(opts)
    |> Enum.map(&:erlang.md5(File.read!(&1)))
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 16)
  end

  defp whole(dir, name, kinds) do
    file = Path.join([dir, name, "data.xml.gz"])

    if File.exists?(file),
      do: [file],
      else:
        kinds
        |> Enum.flat_map(&Path.wildcard(Path.join([dir, &1, "**", "data.xml.gz"])))
        |> Enum.sort()
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

  defp file(root, path),
    do: Path.join(root, path |> stored_name() |> String.trim_leading("/")) <> ".gz"

  # a feed page without its query: "…/data.feed?results-count=5000&page=2" → "…/data.feed.page-2"
  defp stored_name(path) do
    case String.split(path, "?", parts: 2) do
      [feed, query] ->
        page = query |> URI.decode_query() |> Map.get("page", "1")
        feed <> ".page-" <> page

      [doc] ->
        doc
    end
  end

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
