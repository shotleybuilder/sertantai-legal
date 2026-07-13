defmodule SertantaiLegal.Sync.ChangeDetector do
  @moduledoc """
  Detects changes in the legal landscape that affect customer registers.

  Runs after a validated scrape session or enrichment batch to generate
  change detection events (`law_status_changed`, `new_law_available`,
  `match_score_changed`) in the `applicability_events` audit trail.

  ## Change categories detected

  1. **Law status changes** — laws in a customer's register that have been
     repealed, part-revoked, commenced, or superseded since the last check.

  2. **New law availability** — new Making laws that match a customer's
     screening profile but aren't in their register yet.

  3. **Match score changes** — DRRP/fitness enrichment changes that affect
     how well a law matches a customer's profile.

  ## Materiality auto-classification

  - `major` — full/part repeal, new Making law, duty holder change
  - `moderate` — DRRP actor change, family reclassification
  - `minor` — fitness change only, cosmetic status update
  - `informational` — metadata only (title, description)

  ## Review due dates (auto-set by materiality)

  - Major: 30 days
  - Moderate: 60 days
  - Minor: 90 days
  - Informational: none
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Sync.ApplicabilityEvent

  require Logger

  @doc """
  Trigger change detection asynchronously for all orgs.

  Called automatically when a scrape session completes. Safe to call
  multiple times — detection is idempotent.
  """
  def trigger_async(opts \\ []) do
    Task.start(fn ->
      Logger.info("[ChangeDetector] Running change detection for all orgs")
      {:ok, results} = detect_all(opts)

      total =
        Enum.reduce(results, %{status_changes: 0, new_laws: 0, score_changes: 0}, fn {_org,
                                                                                      counts},
                                                                                     acc ->
          %{
            status_changes: acc.status_changes + counts.status_changes,
            new_laws: acc.new_laws + counts.new_laws,
            score_changes: acc.score_changes + counts.score_changes
          }
        end)

      Logger.info(
        "[ChangeDetector] Complete: #{map_size(results)} orgs, " <>
          "#{total.status_changes} status changes, " <>
          "#{total.new_laws} new laws, " <>
          "#{total.score_changes} score changes"
      )

      # Generate summaries and notify (email stub)
      if total.status_changes + total.new_laws + total.score_changes > 0 do
        SertantaiLegal.Sync.ChangeNotifier.notify_all()
      end
    end)
  end

  @review_due_days %{
    "major" => 30,
    "moderate" => 60,
    "minor" => 90
  }

  # -------------------------------------------------------------------
  # Public API
  # -------------------------------------------------------------------

  @doc """
  Run full change detection for all orgs with active registers.

  Typically called after a scrape session completes validation.
  Returns `{:ok, %{org_id => %{status_changes: n, new_laws: n}}}`.
  """
  def detect_all(opts \\ []) do
    checkpoint = Keyword.get(opts, :since)
    org_ids = active_org_ids()

    results =
      Enum.reduce(org_ids, %{}, fn org_id, acc ->
        case detect_for_org(org_id, since: checkpoint) do
          {:ok, counts} ->
            Map.put(acc, org_id, counts)

          {:error, reason} ->
            Logger.error("Change detection failed for org #{org_id}: #{inspect(reason)}")
            acc
        end
      end)

    {:ok, results}
  end

  @doc """
  Run change detection for a single org.

  Options:
  - `:since` — only detect changes after this timestamp (default: check all register laws)

  Returns `{:ok, %{status_changes: n, new_laws: n, score_changes: n}}`.
  """
  def detect_for_org(org_id, opts \\ []) do
    checkpoint = Keyword.get(opts, :since)

    with {:ok, status_changes} <- detect_status_changes(org_id, checkpoint),
         {:ok, new_laws} <- detect_new_laws(org_id),
         {:ok, score_changes} <- detect_score_changes(org_id, checkpoint) do
      {:ok,
       %{
         status_changes: length(status_changes),
         new_laws: length(new_laws),
         score_changes: length(score_changes)
       }}
    end
  end

  # -------------------------------------------------------------------
  # Status changes — laws in register whose `live` status changed
  # -------------------------------------------------------------------

  @doc """
  Detect laws in the org's register whose enforcement status changed.

  Compares `uk_lrt.live` against what was last recorded. Generates
  `law_status_changed` events with appropriate materiality.
  """
  def detect_status_changes(org_id, checkpoint \\ nil) do
    query = """
    SELECT u.name, u.title_en, u.live, u.live_description,
           oa.status as register_status
    FROM org_applicabilities oa
    JOIN uk_lrt u ON u.name = oa.law_name
    WHERE oa.organization_id = $1
      AND oa.status = 'yes'
      AND (u.live LIKE '%evok%' OR u.live LIKE '%epeal%' OR u.live LIKE '%bolish%'
           OR u.live LIKE '%Part%' OR u.live LIKE '%Prospective%')
      AND NOT EXISTS (
        SELECT 1 FROM applicability_events ae
        WHERE ae.organization_id = $1
          AND ae.law_name = u.name
          AND ae.event = 'law_status_changed'
          AND ae.metadata->>'live_status' = u.live
      )
    """

    params = [uuid!(org_id)]

    query =
      if checkpoint do
        query <> "\n  AND u.updated_at > $2"
      else
        query
      end

    params = if checkpoint, do: params ++ [checkpoint], else: params

    case Repo.query(query, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        events =
          rows
          |> Enum.map(&row_to_map(columns, &1))
          |> Enum.map(&log_status_change(org_id, &1))
          |> Enum.filter(&match?({:ok, _}, &1))

        {:ok, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -------------------------------------------------------------------
  # New laws — Making laws matching profile, not in register
  # -------------------------------------------------------------------

  @doc """
  Detect new Making laws that match the org's screening profile
  but aren't yet in their register.

  Uses the same DRRP + fitness scoring logic as the auto-screener.
  """
  def detect_new_laws(org_id) do
    with {:ok, profile} <- fetch_profile(org_id),
         {:ok, families} <- fetch_families(org_id) do
      if families == [] do
        {:ok, []}
      else
        do_detect_new_laws(org_id, profile, families)
      end
    end
  end

  defp do_detect_new_laws(org_id, profile, families) do
    governed = Map.get(profile, :governed_actors, [])
    government = Map.get(profile, :government_actors, [])

    # Combine profile terms for fitness_entities overlap
    profile_entities =
      Enum.concat([
        Map.get(profile, :regions, []),
        Map.get(profile, :locations, []),
        Map.get(profile, :materials, []),
        Map.get(profile, :processes, []),
        Map.get(profile, :sector, [])
      ])

    # Find Making laws in subscribed families, not already in register,
    # not already flagged as new_law_available, with match_score > 0
    query = """
    WITH scored AS (
      SELECT l.name, l.title_en, l.family, l.year, l.live,
             l.duty_holder, l.responsibility_holder,
             l.fitness_entities,
             (
               COALESCE(array_length(
                 ARRAY(SELECT unnest(
                   CASE WHEN l.duty_holder IS NOT NULL
                        THEN ARRAY(SELECT jsonb_array_elements_text(l.duty_holder->'values'))
                        ELSE '{}'::text[] END
                 ) INTERSECT SELECT unnest($3::text[])), 1), 0)
             + COALESCE(array_length(
                 ARRAY(SELECT unnest(
                   CASE WHEN l.responsibility_holder IS NOT NULL
                        THEN ARRAY(SELECT jsonb_array_elements_text(l.responsibility_holder->'values'))
                        ELSE '{}'::text[] END
                 ) INTERSECT SELECT unnest($4::text[])), 1), 0)
             + CASE WHEN $5::text[] != '{}' AND l.fitness_entities IS NOT NULL AND l.fitness_entities && $5::text[] THEN 1 ELSE 0 END
             ) as match_score
      FROM uk_lrt l
      WHERE l.is_making = true
        AND l.family = ANY($2::text[])
        AND (l.live IS NULL OR l.live NOT LIKE '%evok%')
        AND NOT EXISTS (
          SELECT 1 FROM org_applicabilities oa
          WHERE oa.organization_id = $1
            AND oa.law_name = l.name
        )
        AND NOT EXISTS (
          SELECT 1 FROM applicability_events ae
          WHERE ae.organization_id = $1
            AND ae.law_name = l.name
            AND ae.event = 'new_law_available'
        )
    )
    SELECT * FROM scored
    WHERE match_score > 0
    ORDER BY match_score DESC, family, year DESC
    """

    params = [
      uuid!(org_id),
      families,
      governed,
      government,
      profile_entities
    ]

    case Repo.query(query, params) do
      {:ok, %{rows: rows, columns: columns}} ->
        events =
          rows
          |> Enum.map(&row_to_map(columns, &1))
          |> Enum.map(&log_new_law(org_id, &1))
          |> Enum.filter(&match?({:ok, _}, &1))

        {:ok, events}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -------------------------------------------------------------------
  # Score changes — DRRP/fitness enrichment changed for register laws
  # -------------------------------------------------------------------

  @doc """
  Detect laws in the org's register whose DRRP/fitness data changed
  since the last check, potentially affecting match relevance.

  Only flags changes for screener-sourced laws (not manually confirmed).
  """
  def detect_score_changes(org_id, checkpoint \\ nil) do
    unless checkpoint do
      # Without a checkpoint, we can't know what changed
      {:ok, []}
    else
      query = """
      SELECT u.name, u.title_en, u.duty_holder, u.responsibility_holder,
             u.fitness_entities,
             oa.source
      FROM org_applicabilities oa
      JOIN uk_lrt u ON u.name = oa.law_name
      WHERE oa.organization_id = $1
        AND oa.status = 'yes'
        AND u.updated_at > $2
        AND NOT EXISTS (
          SELECT 1 FROM applicability_events ae
          WHERE ae.organization_id = $1
            AND ae.law_name = u.name
            AND ae.event = 'match_score_changed'
            AND ae.inserted_at > $2
        )
      """

      case Repo.query(query, [uuid!(org_id), checkpoint]) do
        {:ok, %{rows: rows, columns: columns}} ->
          events =
            rows
            |> Enum.map(&row_to_map(columns, &1))
            |> Enum.map(&log_score_change(org_id, &1))
            |> Enum.filter(&match?({:ok, _}, &1))

          {:ok, events}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # -------------------------------------------------------------------
  # Event logging helpers
  # -------------------------------------------------------------------

  defp log_status_change(org_id, law) do
    materiality = classify_status_materiality(law["live"])

    ApplicabilityEvent.log(%{
      organization_id: org_id,
      law_name: law["name"],
      event: "law_status_changed",
      actor: "sertantai",
      status_before: "yes",
      status_after: "yes",
      source: "change_detection",
      materiality: materiality,
      review_due_date: review_due_date(materiality),
      metadata: %{
        "live_status" => law["live"],
        "live_description" => law["live_description"],
        "title" => law["title_en"],
        "change_type" => status_change_type(law["live"])
      }
    })
  end

  defp log_new_law(org_id, law) do
    ApplicabilityEvent.log(%{
      organization_id: org_id,
      law_name: law["name"],
      event: "new_law_available",
      actor: "sertantai",
      status_before: nil,
      status_after: "unreviewed",
      source: "change_detection",
      materiality: "major",
      review_due_date: review_due_date("major"),
      metadata: %{
        "title" => law["title_en"],
        "family" => law["family"],
        "year" => law["year"],
        "match_score" => law["match_score"]
      }
    })
  end

  defp log_score_change(org_id, law) do
    # Screener-sourced laws get moderate; manually confirmed get minor
    materiality =
      if law["source"] == "screener", do: "moderate", else: "minor"

    ApplicabilityEvent.log(%{
      organization_id: org_id,
      law_name: law["name"],
      event: "match_score_changed",
      actor: "sertantai",
      status_before: "yes",
      status_after: "yes",
      source: "enrichment",
      materiality: materiality,
      review_due_date: review_due_date(materiality),
      metadata: %{
        "title" => law["title_en"],
        "change_type" => "enrichment_update"
      }
    })
  end

  # -------------------------------------------------------------------
  # Materiality classification
  # -------------------------------------------------------------------

  defp classify_status_materiality(live) when is_binary(live) do
    cond do
      String.contains?(live, "Revok") or String.contains?(live, "Repeal") or
          String.contains?(live, "Abolish") ->
        "major"

      String.contains?(live, "Part") ->
        "major"

      String.contains?(live, "Prospective") ->
        "minor"

      true ->
        "informational"
    end
  end

  defp classify_status_materiality(_), do: "informational"

  defp status_change_type(live) when is_binary(live) do
    cond do
      String.contains?(live, "Revok") -> "revoked"
      String.contains?(live, "Repeal") -> "repealed"
      String.contains?(live, "Abolish") -> "abolished"
      String.contains?(live, "Part") -> "part_revoked"
      String.contains?(live, "Prospective") -> "prospective_repeal"
      true -> "status_change"
    end
  end

  defp status_change_type(_), do: "status_change"

  defp review_due_date(materiality) do
    case Map.get(@review_due_days, materiality) do
      nil -> nil
      days -> Date.add(Date.utc_today(), days)
    end
  end

  # -------------------------------------------------------------------
  # Data helpers
  # -------------------------------------------------------------------

  defp active_org_ids do
    case Repo.query(
           "SELECT DISTINCT organization_id FROM org_applicabilities WHERE status = 'yes'"
         ) do
      {:ok, %{rows: rows}} -> Enum.map(rows, fn [id] -> id end)
      _ -> []
    end
  end

  defp fetch_profile(org_id) do
    case Repo.query(
           """
           SELECT governed_actors, government_actors, locations, materials, processes, sector
           FROM org_screening_profiles
           WHERE organization_id = $1
           """,
           [uuid!(org_id)]
         ) do
      {:ok, %{rows: [[governed, government, locations, materials, processes, sector]]}} ->
        {:ok,
         %{
           governed_actors: governed || [],
           government_actors: government || [],
           locations: locations || [],
           materials: materials || [],
           processes: processes || [],
           sector: sector || []
         }}

      {:ok, %{rows: []}} ->
        {:ok,
         %{
           governed_actors: [],
           government_actors: [],
           locations: [],
           materials: [],
           processes: [],
           sector: []
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_families(org_id) do
    case Repo.query(
           "SELECT families FROM org_entitlements WHERE organization_id = $1",
           [uuid!(org_id)]
         ) do
      {:ok, %{rows: [[families]]}} -> {:ok, families || []}
      {:ok, %{rows: []}} -> {:ok, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp uuid!(id) when is_binary(id) do
    case Ecto.UUID.dump(id) do
      {:ok, bin} -> bin
      :error -> id
    end
  end

  defp uuid!(id), do: id

  defp row_to_map(columns, row) do
    columns
    |> Enum.zip(row)
    |> Map.new()
  end
end
