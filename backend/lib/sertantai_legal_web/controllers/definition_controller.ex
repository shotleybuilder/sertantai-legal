defmodule SertantaiLegalWeb.DefinitionController do
  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo

  @moduledoc """
  REST API for legislative definitions.

  Public reference data endpoints — no authentication required.

  ## Endpoints

    * `GET /api/definitions?term=workplace` — all definitions of a term across laws
    * `GET /api/definitions?law=UK_uksi_1999_3242` — all definitions in a law
    * `GET /api/definitions?term=workplace&law=UK_uksi_1999_3242` — specific lookup
    * `GET /api/definitions/search?q=work` — partial match for autocomplete
  """

  @doc """
  Query definitions by term, law, or both.

  ## Parameters

    * `term` — exact term match (lowercase)
    * `law` — exact law_name match
    * At least one of `term` or `law` is required
  """
  def index(conn, %{"term" => term, "law" => law_name}) do
    query_definitions(conn, "AND ld.term = $1 AND ld.law_name = $2", [term, law_name])
  end

  def index(conn, %{"term" => term}) do
    query_definitions(conn, "AND ld.term = $1", [term])
  end

  def index(conn, %{"law" => law_name}) do
    query_definitions(conn, "AND ld.law_name = $1", [law_name])
  end

  def index(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "At least one of 'term' or 'law' query parameter is required"})
  end

  @doc """
  Search definitions by partial term match (prefix search for autocomplete).

  ## Parameters

    * `q` — search prefix (minimum 2 characters)
    * `limit` — max results (default: 20, max: 100)
  """
  def search(conn, %{"q" => q}) when byte_size(q) >= 2 do
    limit = min(parse_integer(conn.params["limit"], 20), 100)

    case Repo.query(
           """
           SELECT DISTINCT ld.term, COUNT(*) as law_count
           FROM legislative_definitions ld
           WHERE ld.term LIKE $1
           GROUP BY ld.term
           ORDER BY ld.term
           LIMIT $2
           """,
           [q <> "%", limit]
         ) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [term, count] ->
            %{term: term, law_count: count}
          end)

        json(conn, %{data: results, count: length(results)})

      {:error, err} ->
        conn
        |> put_status(500)
        |> json(%{error: "Query failed: #{inspect(err)}"})
    end
  end

  def search(conn, %{"q" => _}) do
    conn
    |> put_status(400)
    |> json(%{error: "Search query 'q' must be at least 2 characters"})
  end

  def search(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Missing required 'q' query parameter"})
  end

  # Shared query logic — JOINs legal_register for law title and year
  defp query_definitions(conn, where_clause, params) do
    case Repo.query(
           """
           SELECT ld.term, ld.term_welsh, ld.definition, ld.scope,
                  ld.law_name, ld.section_id, ld.references_other_law,
                  lr.title_en, lr.year
           FROM legislative_definitions ld
           JOIN legal_register lr ON lr.name = ld.law_name
           WHERE 1=1 #{where_clause}
           ORDER BY lr.year DESC, ld.term
           """,
           params
         ) do
      {:ok, %{rows: rows}} ->
        definitions =
          Enum.map(rows, fn [term, term_welsh, definition, scope, law_name, section_id,
                             references_other_law, title_en, year] ->
            %{
              term: term,
              term_welsh: term_welsh,
              definition: definition,
              scope: scope,
              law_name: law_name,
              section_id: section_id,
              references_other_law: references_other_law,
              law_title: title_en,
              year: year
            }
          end)

        json(conn, %{data: definitions, count: length(definitions)})

      {:error, err} ->
        conn
        |> put_status(500)
        |> json(%{error: "Query failed: #{inspect(err)}"})
    end
  end

  defp parse_integer(nil, default), do: default
  defp parse_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp parse_integer(val, _default) when is_integer(val), do: val
end
