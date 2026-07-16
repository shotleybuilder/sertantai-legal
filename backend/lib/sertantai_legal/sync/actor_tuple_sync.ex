defmodule SertantaiLegal.Sync.ActorTupleSync do
  @moduledoc """
  Syncs the Actor Tuples table to Baserow.

  Creates a normalised table of (actor, position, drrp_type) tuples
  derived from the actors struct on LAT provisions. Each LAT row links
  to its matching tuples via a many-to-many linked record field.

  This preserves the actor↔DRRP relationship that flat multi-select
  columns lose — enabling queries like "Employer Duties".

  ## Row budget

  Tuples are bounded by the actual combinations in the corpus, not the
  theoretical cross-product. Typically 300-600 for a full register.
  """

  alias SertantaiLegal.Repo

  require Logger

  @doc """
  Extract distinct (actor, position, drrp_type) tuples for an org's register.

  Options:
  - `:governed_only` — exclude Gvt/EU/Crown/HM actors (default: true)
  - `:canonical_only` — exclude invented labels (default: true)
  """
  def extract_tuples(org_id, opts \\ []) do
    governed_only = Keyword.get(opts, :governed_only, true)
    canonical_only = Keyword.get(opts, :canonical_only, true)

    gov_filter =
      if governed_only do
        "AND a->>'label' NOT LIKE 'Gvt:%' AND a->>'label' NOT LIKE 'EU:%' AND a->>'label' NOT IN ('Crown', 'HM Forces')"
      else
        ""
      end

    canonical_filter =
      if canonical_only do
        "AND a->>'label_source' = 'canonical'"
      else
        ""
      end

    {:ok, org_bin} = Ecto.UUID.dump(org_id)

    query = """
    SELECT DISTINCT
      a->>'label' as actor,
      a->>'position' as position,
      dt as drrp_type
    FROM legal_articles la
    JOIN org_applicabilities oa ON oa.law_name = la.law_name
      AND oa.organization_id = $1
      AND oa.status = 'yes',
    unnest(la.actors) a,
    unnest(la.drrp_types) dt
    WHERE a->>'position' IS NOT NULL AND a->>'position' != ''
      #{gov_filter}
      #{canonical_filter}
    ORDER BY actor, drrp_type, position
    """

    case Repo.query(query, [org_bin]) do
      {:ok, %{rows: rows}} ->
        tuples =
          Enum.map(rows, fn [actor, position, drrp_type] ->
            %{actor: actor, position: position, drrp_type: drrp_type}
          end)

        {:ok, tuples}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build the Baserow field specs for the Actor Tuples table.
  """
  def field_specs(tuples) do
    actors = tuples |> Enum.map(& &1.actor) |> Enum.uniq() |> Enum.sort()
    positions = tuples |> Enum.map(& &1.position) |> Enum.uniq() |> Enum.sort()
    drrp_types = tuples |> Enum.map(& &1.drrp_type) |> Enum.uniq() |> Enum.sort()

    [
      %{
        name: "Actor",
        type: "single_select",
        opts: %{
          "select_options" => Enum.map(actors, &%{"value" => &1, "color" => "light-gray"})
        }
      },
      %{
        name: "Position",
        type: "single_select",
        opts: %{
          "select_options" => Enum.map(positions, &%{"value" => &1, "color" => "light-gray"})
        }
      },
      %{
        name: "DRRP_Type",
        type: "single_select",
        opts: %{
          "select_options" => Enum.map(drrp_types, &%{"value" => &1, "color" => "light-gray"})
        }
      },
      %{name: "_source_id", type: "text"}
    ]
  end

  @doc """
  Format tuples as Baserow rows.

  The `_source_id` is a composite key: "actor|position|drrp_type"
  """
  def format_rows(tuples) do
    Enum.map(tuples, fn t ->
      # Sanitise pipe from actor labels (safe delimiter for composite key)
      safe_actor = String.replace(t.actor, "|", "_")
      source_id = "#{safe_actor}|#{t.position}|#{t.drrp_type}"

      %{
        "Name" => source_id,
        "Actor" => t.actor,
        "Position" => t.position,
        "DRRP_Type" => t.drrp_type,
        "_source_id" => source_id
      }
    end)
  end

  @doc """
  For each LAT provision, find the matching tuple row IDs.

  Returns a map of `%{section_id => [tuple_external_row_ids]}`.
  """
  def match_provisions_to_tuples(lat_rows, tuples, tuple_mappings) do
    # Build lookup: "actor|position|drrp_type" → external_row_id
    tuple_lookup =
      Map.new(tuple_mappings, fn m ->
        {m.source_id, m.external_row_id}
      end)

    # For each LAT row, find its matching tuples
    Map.new(lat_rows, fn lat ->
      actors = lat[:actors] || lat.actors || []
      drrp_types = lat[:drrp_types] || lat.drrp_types || []

      matching_ids =
        for a <- actors,
            dt <- drrp_types,
            label = a["label"] || a[:label],
            position = a["position"] || a[:position],
            source = a["label_source"] || a[:label_source],
            label != nil and position != nil and source == "canonical",
            key = "#{label}|#{position}|#{dt}",
            ext_id = Map.get(tuple_lookup, key),
            ext_id != nil do
          ext_id
        end
        |> Enum.uniq()

      section_id = lat[:section_id] || lat.section_id
      {section_id, matching_ids}
    end)
  end
end
