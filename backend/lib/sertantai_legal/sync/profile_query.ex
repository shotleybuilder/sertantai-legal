defmodule SertantaiLegal.Sync.ProfileQuery do
  @moduledoc """
  Builds SQL queries from a sync profile's filter criteria.

  Produces the set of LRT IDs (and optionally LAT rows) that match
  a profile's family + geo + function + fitness filters.
  """

  import Ecto.Query

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.FieldTiers

  @doc """
  Query LRT rows matching the given profile, selecting only columns
  allowed by the field tier. Returns `{:ok, [%{column => value}]}`.

  Options:
    - `:checkpoint` — only rows with updated_at > checkpoint (for delta sync)
  """
  def query_lrt(profile, field_tier, opts \\ []) do
    columns = FieldTiers.columns(field_tier)
    # Always include updated_at for checkpoint tracking
    select_columns = Enum.uniq(columns ++ [:updated_at])
    checkpoint = Keyword.get(opts, :checkpoint)
    organization_id = Keyword.get(opts, :organization_id)

    query =
      from(u in "uk_lrt",
        select: map(u, ^select_columns)
      )
      |> apply_family_filter(profile.families)
      |> apply_geo_filter(profile.geo_regions)
      |> apply_function_filter(profile.function_filter)
      |> apply_live_filter(profile.live_filter)
      |> apply_fitness_filter(:fitness_person, profile.fitness_person)
      |> apply_fitness_filter(:fitness_process, profile.fitness_process)
      |> apply_fitness_filter(:fitness_place, profile.fitness_place)
      |> apply_fitness_filter(:fitness_plant, profile.fitness_plant)
      |> apply_fitness_filter(:fitness_sector, profile.fitness_sector)
      |> apply_applicability_filter(organization_id)
      |> apply_checkpoint(checkpoint)
      |> order_by([u], [u.family, u.year, u.name])

    {:ok, Repo.all(query)}
  end

  @doc """
  Count LRT rows matching the profile (for preview / cached count).
  """
  def count_lrt(profile) do
    query =
      from(u in "uk_lrt", select: count(u.id))
      |> apply_family_filter(profile.families)
      |> apply_geo_filter(profile.geo_regions)
      |> apply_function_filter(profile.function_filter)
      |> apply_live_filter(profile.live_filter)
      |> apply_fitness_filter(:fitness_person, profile.fitness_person)
      |> apply_fitness_filter(:fitness_process, profile.fitness_process)
      |> apply_fitness_filter(:fitness_place, profile.fitness_place)
      |> apply_fitness_filter(:fitness_plant, profile.fitness_plant)
      |> apply_fitness_filter(:fitness_sector, profile.fitness_sector)

    Repo.one(query)
  end

  @doc """
  Query LAT rows for the given LRT IDs. Returns `{:ok, [map]}`.
  """
  def query_lat(lrt_ids, opts \\ []) when is_list(lrt_ids) do
    section_types = Keyword.get(opts, :section_types)
    drrp_filter = Keyword.get(opts, :drrp_types)

    query =
      from(l in "lat",
        where: l.law_id in ^lrt_ids,
        select:
          map(l, [
            :section_id,
            :law_name,
            :law_id,
            :section_type,
            :text,
            :part,
            :chapter,
            :provision,
            :paragraph,
            :depth,
            :position,
            :language,
            :sort_key,
            :drrp_types,
            :governed_actors,
            :actors,
            :duty_sub_type,
            :clause_refined
          ]),
        order_by: [l.law_name, l.sort_key]
      )
      |> apply_section_type_filter(section_types)
      |> apply_drrp_filter(drrp_filter)

    {:ok, Repo.all(query)}
  end

  @doc """
  Query LAT rows aggregated at the provision level (Goldilocks model).

  Groups all children (sub_articles, paragraphs, sub_paragraphs) under their
  parent provision number. Each result row is one complete, self-contained
  obligation with full concatenated text and union of DRRP/actor classifications.

  Options:
    - `:drrp_types` — only include provisions where at least one child has matching DRRP type
  """
  def query_lat_aggregated(lrt_ids, opts \\ []) when is_list(lrt_ids) do
    drrp_types = Keyword.get(opts, :drrp_types)

    drrp_clause =
      if drrp_types do
        "AND EXISTS (
          SELECT 1 FROM lat child
          WHERE child.law_id = la.law_id AND child.provision = la.provision
            AND child.drrp_types && $2
        )"
      else
        ""
      end

    sql = """
    SELECT
      la.law_name,
      la.law_id,
      la.provision,
      la.law_name || ':' ||
        CASE
          WHEN la.law_name LIKE 'UK_ukpga%' OR la.law_name LIKE 'UK_ukla%' OR la.law_name LIKE 'UK_anaw%' OR la.law_name LIKE 'UK_asc%' THEN 's.'
          WHEN la.law_name LIKE 'UK_eur%' OR la.law_name LIKE 'UK_eudr%' OR la.law_name LIKE 'UK_eudn%' THEN 'art.'
          ELSE 'reg.'
        END
        || la.provision AS section_id,
      string_agg(
        CASE
          WHEN la.section_type IN ('article', 'section') AND (la.text IS NULL OR la.text = '') THEN NULL
          WHEN la.section_type IN ('article', 'section') THEN
            coalesce(la.text, '')
          WHEN la.section_type IN ('sub_article', 'sub_section') THEN
            E'\n' || coalesce(la.provision, '') || '(' || coalesce(
              (regexp_match(la.section_id, '\\(([^)]+)\\)$'))[1],
              ''
            ) || ') ' || coalesce(la.text, '')
          WHEN la.section_type = 'paragraph' THEN
            E'\n  (' || coalesce(la.paragraph, '') || ') ' || coalesce(la.text, '')
          WHEN la.section_type = 'sub_paragraph' THEN
            '    (' || coalesce(la.sub_paragraph, '') || ') ' || coalesce(la.text, '')
          ELSE coalesce(la.text, '')
        END,
        E'\\n' ORDER BY la.sort_key
      ) AS text,
      (SELECT array_agg(DISTINCT dt)
        FROM lat c, unnest(c.drrp_types) dt
        WHERE c.law_id = la.law_id AND c.provision = la.provision AND dt IS NOT NULL
      ) AS drrp_types,
      (SELECT array_agg(DISTINCT label) FROM (
        -- Primary: actors struct (position=active, canonical only)
        SELECT a->>'label' as label
        FROM lat c, unnest(c.actors) a
        WHERE c.law_id = la.law_id AND c.provision = la.provision
          AND a->>'position' = 'active'
          AND a->>'label' IS NOT NULL
          AND a->>'label_source' = 'canonical'
        UNION
        -- Fallback: flat governed_actors for provisions without actors struct
        SELECT ga as label
        FROM lat c, unnest(c.governed_actors) ga
        WHERE c.law_id = la.law_id AND c.provision = la.provision
          AND (c.actors IS NULL OR array_length(c.actors, 1) IS NULL)
          AND ga IS NOT NULL
      ) sub) AS governed_actors,
      (SELECT array_agg(DISTINCT c.duty_sub_type) FROM lat c
        WHERE c.law_id = la.law_id AND c.provision = la.provision
          AND c.duty_sub_type IS NOT NULL
      ) AS duty_sub_type,
      count(*) AS child_count
    FROM lat la
    WHERE la.law_id = ANY($1)
      AND la.provision IS NOT NULL
      #{drrp_clause}
    GROUP BY la.law_name, la.law_id, la.provision
    ORDER BY la.law_name, min(la.sort_key)
    """

    params =
      if drrp_types do
        [lrt_ids, drrp_types]
      else
        [lrt_ids]
      end

    case Repo.query(sql, params) do
      {:ok, %{columns: cols, rows: rows}} ->
        result =
          Enum.map(rows, fn row ->
            cols
            |> Enum.zip(row)
            |> Map.new(fn {col, val} -> {String.to_atom(col), val} end)
          end)

        {:ok, result}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Count LAT rows for the given LRT IDs (for preview).
  """
  def count_lat(lrt_ids) when is_list(lrt_ids) do
    from(l in "lat", where: l.law_id in ^lrt_ids, select: count(l.section_id))
    |> Repo.one()
  end

  # ── Filter builders ───────────────────────────────────────────────

  defp apply_family_filter(query, families) when is_list(families) and families != [] do
    where(query, [u], u.family in ^families)
  end

  defp apply_family_filter(query, _), do: query

  defp apply_geo_filter(query, nil), do: query
  defp apply_geo_filter(query, []), do: query

  defp apply_geo_filter(query, regions) when is_list(regions) do
    where(query, [u], fragment("? && ?", u.geo_region, ^regions))
  end

  defp apply_function_filter(query, nil), do: query
  defp apply_function_filter(query, filter) when filter == %{}, do: query

  defp apply_function_filter(query, %{"is_making" => true}) do
    where(query, [u], u.is_making == true)
  end

  defp apply_function_filter(query, %{"is_making" => false}) do
    where(query, [u], u.is_making == false or is_nil(u.is_making))
  end

  defp apply_function_filter(query, _), do: query

  defp apply_live_filter(query, nil), do: query
  defp apply_live_filter(query, []), do: query

  defp apply_live_filter(query, statuses) when is_list(statuses) do
    where(query, [u], u.live in ^statuses)
  end

  defp apply_fitness_filter(query, _column, nil), do: query
  defp apply_fitness_filter(query, _column, []), do: query

  defp apply_fitness_filter(query, column, values) when is_list(values) do
    where(query, [u], fragment("? && ?", field(u, ^column), ^values))
  end

  defp apply_applicability_filter(query, nil), do: query

  defp apply_applicability_filter(query, organization_id) do
    from(u in query,
      inner_join: oa in "org_applicabilities",
      on:
        oa.law_name == u.name and
          oa.organization_id == type(^organization_id, Ecto.UUID),
      where: oa.status == "yes"
    )
  end

  defp apply_section_type_filter(query, nil), do: query
  defp apply_section_type_filter(query, []), do: query

  defp apply_section_type_filter(query, types) when is_list(types) do
    type_strings = Enum.map(types, &to_string/1)
    where(query, [l], l.section_type in ^type_strings)
  end

  defp apply_drrp_filter(query, nil), do: query
  defp apply_drrp_filter(query, []), do: query

  defp apply_drrp_filter(query, types) when is_list(types) do
    # Filter to provisions where drrp_types array overlaps with the given types
    where(query, [l], fragment("? && ?", l.drrp_types, ^types))
  end

  defp apply_checkpoint(query, nil), do: query

  defp apply_checkpoint(query, %DateTime{} = checkpoint) do
    where(query, [u], u.updated_at > ^checkpoint)
  end
end
