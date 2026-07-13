defmodule SertantaiLegal.Fitness.EntityIndex do
  @moduledoc """
  Inverted entity index for fitness applicability matching.

  Uses PostgreSQL GIN index on `fitness_entities` for fast array overlap
  queries. Given a set of customer entities, returns candidate laws whose
  fitness_entities overlap.

  This is the coarse filter (Stage 1) of the applicability engine — it
  narrows ~19K laws to ~400 candidates before expression tree evaluation.
  """

  import Ecto.Query
  alias SertantaiLegal.Repo

  @doc """
  Find laws whose fitness_entities overlap with the given entity list.

  Returns `{:ok, [%{name, title_en, fitness_entities, fitness_scope_dimensions, ...}]}`.

  ## Options
    * `:country` — filter by country partition (default: all)
    * `:limit` — max results (default: nil = all)
    * `:making_only` — only return making laws (default: true)
  """
  @spec find_candidates(list(String.t()), keyword()) :: {:ok, list(map())}
  def find_candidates(entities, opts \\ []) when is_list(entities) and entities != [] do
    country = Keyword.get(opts, :country)
    limit = Keyword.get(opts, :limit)
    making_only = Keyword.get(opts, :making_only, true)

    query =
      from(lr in "legal_register",
        where: fragment("fitness_entities && ?::text[]", ^entities),
        select: %{
          name: lr.name,
          title_en: lr.title_en,
          family: lr.family,
          live: lr.live,
          fitness_entities: lr.fitness_entities,
          fitness_scope_dimensions: lr.fitness_scope_dimensions,
          fitness_mention_count: lr.fitness_mention_count,
          fitness_applies_count: lr.fitness_applies_count,
          fitness_disapplies_count: lr.fitness_disapplies_count,
          is_making: lr.is_making
        },
        order_by: [asc: lr.name]
      )

    query = if country, do: where(query, [lr], lr.country == ^country), else: query
    query = if making_only, do: where(query, [lr], lr.is_making == true), else: query
    query = if limit, do: limit(query, ^limit), else: query

    {:ok, Repo.all(query)}
  end

  @doc """
  List all unique entities in the corpus with their law counts.

  Returns `[%{entity: "employer", law_count: 234}]`, sorted by frequency descending.

  ## Options
    * `:country` — filter by country partition
    * `:min_count` — minimum law count to include (default: 1)
    * `:limit` — max results (default: nil = all)
  """
  @spec list_entities(keyword()) :: list(map())
  def list_entities(opts \\ []) do
    country = Keyword.get(opts, :country)
    min_count = Keyword.get(opts, :min_count, 1)
    limit = Keyword.get(opts, :limit)

    {where_clause, params} =
      if country do
        {"WHERE fitness_entities IS NOT NULL AND country = $1", [country]}
      else
        {"WHERE fitness_entities IS NOT NULL", []}
      end

    limit_clause = if limit, do: "LIMIT $#{length(params) + 2}", else: ""
    min_param_idx = length(params) + 1
    all_params = params ++ [min_count] ++ if(limit, do: [limit], else: [])

    sql = """
    SELECT entity, COUNT(*) as law_count
    FROM legal_register, unnest(fitness_entities) AS entity
    #{where_clause}
    GROUP BY entity
    HAVING COUNT(*) >= $#{min_param_idx}
    ORDER BY law_count DESC
    #{limit_clause}
    """

    %{rows: rows} = Ecto.Adapters.SQL.query!(Repo, sql, all_params)
    Enum.map(rows, fn [entity, count] -> %{entity: entity, law_count: count} end)
  end

  @doc """
  Count how many laws match a set of entities.
  Faster than `find_candidates/2` when you only need the count.
  """
  @spec count_candidates(list(String.t()), keyword()) :: non_neg_integer()
  def count_candidates(entities, opts \\ []) when is_list(entities) and entities != [] do
    country = Keyword.get(opts, :country)
    making_only = Keyword.get(opts, :making_only, true)

    query =
      from(lr in "legal_register",
        where: fragment("fitness_entities && ?::text[]", ^entities),
        select: count()
      )

    query = if country, do: where(query, [lr], lr.country == ^country), else: query
    query = if making_only, do: where(query, [lr], lr.is_making == true), else: query

    Repo.one(query)
  end
end
