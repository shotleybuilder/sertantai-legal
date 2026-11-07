defmodule SertantaiLegal.Scraper.LabelTools.FoldCache do
  @moduledoc """
  A law's fold (`ChangeVocabulary.LabelSource.rows/1`) kept on disk, so the
  label tools a family's later steps run (shadow, rules, strata, gate) fold
  each law once, not once per tool and per `--list` (#191, 2026-11-07).

  The file (`data/cache/label-fold/<law>.etf`) holds the fold under a key
  of everything it reads (`inputs/1`): the change register's code version,
  the law's latest build, its stored timeline, its rows, its register title
  and made date, and its CLML body. Any of them moving folds the law again.
  Rows share the law's change list, which `term_to_binary` would copy into
  every row, so the file holds the changes once and each row's reaching
  changes as their places in it (`pack/1`).

  Lives outside the code version's modules (`ChangeVocabulary.Version`), so
  it never stales a build.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{LabelSource, Version}

  @dir "data/cache/label-fold"

  @type inputs :: %{
          version: String.t(),
          build: term(),
          timeline: String.t() | nil,
          articles: String.t() | nil,
          register: {Date.t() | nil, String.t() | nil},
          clml: {non_neg_integer(), integer()} | nil
        }

  @doc """
  `law`'s fold: from the cache when its key matches, else folded and
  stored. A fold that fails (`{:error, why}`) is returned and not stored.
  `opts`: `cache: false` folds and writes nothing; `:dir`; `:fold` and
  `:inputs` (law → result) in place of `LabelSource.rows/1` and `inputs/1`.
  """
  @spec rows(String.t(), keyword()) :: [LabelSource.row()] | {:error, term()}
  def rows(law, opts \\ []) do
    fold = Keyword.get(opts, :fold, &LabelSource.rows/1)

    if Keyword.get(opts, :cache, true) do
      key = key(Keyword.get(opts, :inputs, &inputs/1).(law))
      path = Path.join(Keyword.get(opts, :dir, @dir), law <> ".etf")
      cached(path, key) || store(path, key, fold.(law))
    else
      fold.(law)
    end
  end

  @doc "The cache key of a law's inputs."
  @spec key(inputs()) :: String.t()
  def key(inputs) do
    :sha256 |> :crypto.hash(:erlang.term_to_binary(Enum.sort(inputs))) |> Base.encode16()
  end

  @doc "Rows as stored: the law's changes once, each row's reaching changes as places in them."
  @spec pack([map()]) :: {:packed, [map()], [map()]}
  def pack([]), do: {:packed, [], []}

  def pack([%{changes: changes} | _] = rows) do
    place = changes |> Enum.with_index() |> Map.new()

    {:packed, changes,
     Enum.map(rows, fn %{changes: ^changes} = r ->
       %{r | changes: nil, reaching: Enum.map(r.reaching, &Map.fetch!(place, &1))}
     end)}
  end

  @doc "The rows `pack/1` stored, as the fold gave them."
  @spec unpack({:packed, [map()], [map()]}) :: [map()]
  def unpack({:packed, changes, rows}) do
    at = List.to_tuple(changes)

    Enum.map(
      rows,
      &%{&1 | changes: changes, reaching: Enum.map(&1.reaching, fn i -> elem(at, i) end)}
    )
  end

  @doc "Everything `LabelSource.rows/1` reads for `law`, as a few values."
  @spec inputs(String.t()) :: inputs()
  def inputs(law) do
    %{
      version: Version.current(),
      build:
        one("SELECT max(id) FROM lat_events WHERE law_name = $1 AND event = 'changes_built'", law),
      timeline:
        one(
          "SELECT md5(string_agg(t::text, '|' ORDER BY t.section_id, t.valid_from, t::text)) FROM lat_label_timeline t WHERE law_name = $1",
          law
        ),
      articles:
        one(
          "SELECT md5(string_agg(concat_ws('~', section_id, extent_code, part, chapter, section_type), '|' ORDER BY section_id, extent_code, part, chapter, section_type)) FROM legal_articles WHERE law_name = $1",
          law
        ),
      register: register(law),
      clml: clml(law)
    }
  end

  defp one(sql, law) do
    %{rows: [[v]]} = Repo.query!(sql, [law])
    v
  end

  defp register(law) do
    case Repo.query!(
           "SELECT coalesce(md_made_date, md_enactment_date), title_en FROM uk_lrt WHERE name = $1 LIMIT 1",
           [law]
         ) do
      %{rows: [[made, title]]} -> {made, title}
      _ -> {nil, nil}
    end
  end

  defp clml(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> path |> File.stat!(time: :posix) |> then(&{&1.size, &1.mtime})
      [] -> nil
    end
  end

  defp cached(path, key) do
    with {:ok, bin} <- File.read(path),
         {^key, packed} <- :erlang.binary_to_term(bin) do
      unpack(packed)
    else
      _ -> nil
    end
  end

  defp store(_path, _key, {:error, _} = error), do: error

  defp store(path, key, rows) do
    File.mkdir_p!(Path.dirname(path))
    tmp = "#{path}.#{System.unique_integer([:positive])}.tmp"
    File.write!(tmp, :erlang.term_to_binary({key, pack(rows)}, [:compressed]))
    File.rename!(tmp, path)
    rows
  end
end
