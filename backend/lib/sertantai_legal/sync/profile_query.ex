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
  def query_lat(lrt_ids) when is_list(lrt_ids) do
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
            :sort_key
          ]),
        order_by: [l.law_name, l.sort_key]
      )

    {:ok, Repo.all(query)}
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

  defp apply_checkpoint(query, nil), do: query

  defp apply_checkpoint(query, %DateTime{} = checkpoint) do
    where(query, [u], u.updated_at > ^checkpoint)
  end
end
