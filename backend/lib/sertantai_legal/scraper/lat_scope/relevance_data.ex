defmodule SertantaiLegal.Scraper.LatScope.RelevanceData do
  @moduledoc """
  DB reads for relevance scopes (#166); the rule itself is the pure
  `LatScope.Relevance`.

  Handles:
  - `candidates/1` — large Acts (LAT rows ≥ min) with no family, unscoped
  - `section_parts/1` — a law's section number → Part map from its LAT
  - `citations/1` — sections of the law cited by in-family SIs made under it
    (stored `enabling_provisions`, else `EnablingCache`, which fetches the
    SI's introduction)
  - `rows/1` — the law's LAT rows' Part/Chapter/provision/schedule and
    whether fractalaw enriched them, for dry-run estimates
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache

  @type candidate :: %{name: String.t(), title: String.t(), rows: non_neg_integer()}

  @doc "Unscoped Acts with no family and at least `min_rows` LAT rows, largest first."
  @spec candidates(pos_integer()) :: [candidate()]
  def candidates(min_rows) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT r.name, r.title_en, count(*)
        FROM legal_articles a JOIN legal_register r ON r.name = a.law_name AND r.country = 'uk'
        WHERE coalesce(r.family, '') = '' AND r.lat_scope IS NULL
        GROUP BY 1, 2 HAVING count(*) >= $1 ORDER BY 3 DESC
        """,
        [min_rows]
      )

    Enum.map(rows, fn [name, title, n] -> %{name: name, title: title, rows: n} end)
  end

  @doc "Section (or article) number → Part (nil when not in a Part)."
  @spec section_parts(String.t()) :: %{String.t() => String.t() | nil}
  def section_parts(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT DISTINCT ON (provision) provision, part FROM legal_articles
        WHERE law_name = $1 AND provision IS NOT NULL AND schedule IS NULL
        ORDER BY provision, sort_key
        """,
        [law_name]
      )

    Map.new(rows, fn [provision, part] -> {provision, part} end)
  end

  @doc """
  `[{si_name, family, [section]}]`: in-family SIs made under `law_name` and
  the sections of it they cite (an SI whose introduction gives none has []).
  """
  @spec citations(String.t()) :: [{String.t(), String.t(), [String.t()]}]
  def citations(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT name, family, enabling_provisions FROM legal_register
        WHERE country = 'uk' AND $1 = ANY(enacted_by) AND coalesce(family, '') <> ''
        ORDER BY name
        """,
        [law_name]
      )

    Enum.map(rows, fn [si, family, stored] ->
      provisions =
        case stored do
          %{"provisions" => [_ | _] = ps} -> ps
          _ -> EnablingCache.get(si)
        end

      sections =
        provisions
        |> Enum.filter(&(&1["law"] == law_name))
        |> Enum.flat_map(&(&1["sections"] || []))
        |> Enum.uniq()

      {si, family, sections}
    end)
  end

  @doc "The law's LAT rows as `%{part, chapter, provision, schedule, enriched}` maps."
  @spec rows(String.t()) :: [map()]
  def rows(law_name) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT part, chapter, provision, schedule, taxa_enriched_at IS NOT NULL
        FROM legal_articles WHERE law_name = $1
        """,
        [law_name]
      )

    Enum.map(rows, fn [p, c, pr, s, e] ->
      %{part: p, chapter: c, provision: pr, schedule: s, enriched: e}
    end)
  end
end
