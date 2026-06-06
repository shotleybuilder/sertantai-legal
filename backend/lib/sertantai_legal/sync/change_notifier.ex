defmodule SertantaiLegal.Sync.ChangeNotifier do
  @moduledoc """
  Generates change summaries and notification stubs after change detection.

  Called by `ChangeDetector.trigger_async/1` after detection completes.
  Builds a per-org summary of what changed, logs it, and (when enabled)
  will send email notifications.

  ## Summary format

      %{
        organization_id: "uuid",
        detected_at: ~U[2026-06-06 18:00:00Z],
        counts: %{
          major: 3,
          moderate: 2,
          minor: 5,
          informational: 1,
          total: 11
        },
        by_event: %{
          law_status_changed: 3,
          new_law_available: 7,
          match_score_changed: 1
        },
        overdue: 0,
        top_changes: [%{law_name: "...", title: "...", materiality: "major", event: "..."}]
      }

  ## Email (stub)

  Email sending is not yet wired — `send_email/2` builds the text body
  but logs it instead of sending. When sertantai-hub gains email delivery,
  this module will call the hub's notification endpoint.
  """

  alias SertantaiLegal.Repo

  require Logger

  @doc """
  Generate change summaries for all orgs that have pending changes.

  Returns `{:ok, [summary]}` — one summary per org with pending events.
  """
  def generate_summaries do
    query = """
    SELECT ae.organization_id,
           ae.materiality,
           ae.event,
           COUNT(*) as count
    FROM applicability_events ae
    WHERE ae.decision IS NULL
      AND ae.event IN ('law_status_changed', 'new_law_available', 'match_score_changed')
    GROUP BY ae.organization_id, ae.materiality, ae.event
    ORDER BY ae.organization_id
    """

    case Repo.query(query) do
      {:ok, %{rows: rows}} ->
        summaries =
          rows
          |> Enum.group_by(fn [org_id | _] -> org_id end)
          |> Enum.map(fn {org_id, group_rows} -> build_summary(org_id, group_rows) end)
          |> Enum.filter(fn s -> s.counts.total > 0 end)

        {:ok, summaries}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generate a change summary for a single org.
  """
  def generate_summary(org_id) do
    {:ok, org_id_binary} = Ecto.UUID.dump(org_id)

    query = """
    SELECT $1::uuid as organization_id,
           ae.materiality,
           ae.event,
           COUNT(*) as count
    FROM applicability_events ae
    WHERE ae.organization_id = $1
      AND ae.decision IS NULL
      AND ae.event IN ('law_status_changed', 'new_law_available', 'match_score_changed')
    GROUP BY ae.materiality, ae.event
    """

    case Repo.query(query, [org_id_binary]) do
      {:ok, %{rows: rows}} ->
        {:ok, build_summary(org_id_binary, rows)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Notify all orgs with pending changes.

  Called by `ChangeDetector.trigger_async/1` after detection completes.
  Currently logs summaries and builds email bodies (stub — not sent).
  """
  def notify_all do
    case generate_summaries() do
      {:ok, summaries} ->
        Enum.each(summaries, fn summary ->
          org_id_str = load_uuid(summary.organization_id)

          Logger.info(
            "[ChangeNotifier] Org #{org_id_str}: " <>
              "#{summary.counts.total} pending changes " <>
              "(#{summary.counts.major} major, #{summary.counts.moderate} moderate)"
          )

          # Stub: build email but don't send
          email_body = build_email_body(summary)
          Logger.debug("[ChangeNotifier] Email stub for #{org_id_str}:\n#{email_body}")
        end)

        {:ok, length(summaries)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build an email notification body for a change summary.

  Returns a plain-text email body. Actual sending is not yet implemented —
  this will eventually call sertantai-hub's email delivery endpoint.
  """
  def build_email_body(summary) do
    org_id_str = load_uuid(summary.organization_id)

    subject = change_subject(summary)

    body = """
    Legal Register Changes — Action Required

    #{subject}

    Summary:
    #{if summary.counts.major > 0, do: "  #{summary.counts.major} major change#{plural(summary.counts.major)} (review within 30 days)\n", else: ""}#{if summary.counts.moderate > 0, do: "  #{summary.counts.moderate} moderate change#{plural(summary.counts.moderate)} (review within 60 days)\n", else: ""}#{if summary.counts.minor > 0, do: "  #{summary.counts.minor} minor change#{plural(summary.counts.minor)}\n", else: ""}#{if summary.counts.informational > 0, do: "  #{summary.counts.informational} informational update#{plural(summary.counts.informational)}\n", else: ""}
    Breakdown:
    #{if summary.by_event.law_status_changed > 0, do: "  #{summary.by_event.law_status_changed} law#{plural(summary.by_event.law_status_changed)} repealed or status changed\n", else: ""}#{if summary.by_event.new_law_available > 0, do: "  #{summary.by_event.new_law_available} new law#{plural(summary.by_event.new_law_available)} matching your profile\n", else: ""}#{if summary.by_event.match_score_changed > 0, do: "  #{summary.by_event.match_score_changed} law#{plural(summary.by_event.match_score_changed)} with enrichment updates\n", else: ""}
    #{if summary.overdue > 0, do: "WARNING: #{summary.overdue} change#{plural(summary.overdue)} overdue for review.\n\n", else: ""}Review your changes at: [Changes Dashboard]

    --
    SertantAI Legal Compliance
    Organization: #{org_id_str}
    """

    String.trim(body)
  end

  @doc """
  Generate a short subject line for the change notification email.
  """
  def change_subject(summary) do
    parts = []

    parts =
      if summary.counts.major > 0,
        do: parts ++ ["#{summary.counts.major} major"],
        else: parts

    parts =
      if summary.by_event.new_law_available > 0,
        do: parts ++ ["#{summary.by_event.new_law_available} new matches"],
        else: parts

    total = summary.counts.total

    case parts do
      [] -> "#{total} legal register update#{plural(total)} to review"
      _ -> "#{Enum.join(parts, ", ")} — #{total} total changes to review"
    end
  end

  # -------------------------------------------------------------------
  # Internal
  # -------------------------------------------------------------------

  defp build_summary(org_id, rows) do
    materiality_counts = %{"major" => 0, "moderate" => 0, "minor" => 0, "informational" => 0}

    event_counts = %{
      "law_status_changed" => 0,
      "new_law_available" => 0,
      "match_score_changed" => 0
    }

    {mat_counts, evt_counts} =
      Enum.reduce(rows, {materiality_counts, event_counts}, fn row, {mat, evt} ->
        [_org_id, materiality, event, count] = row
        mat_key = materiality || "informational"

        {Map.update(mat, mat_key, count, &(&1 + count)),
         Map.update(evt, event, count, &(&1 + count))}
      end)

    total = Enum.reduce(mat_counts, 0, fn {_k, v}, acc -> acc + v end)

    %{
      organization_id: org_id,
      detected_at: DateTime.utc_now(),
      counts: %{
        major: mat_counts["major"],
        moderate: mat_counts["moderate"],
        minor: mat_counts["minor"],
        informational: mat_counts["informational"],
        total: total
      },
      by_event: %{
        law_status_changed: evt_counts["law_status_changed"],
        new_law_available: evt_counts["new_law_available"],
        match_score_changed: evt_counts["match_score_changed"]
      },
      overdue: count_overdue(org_id)
    }
  end

  defp count_overdue(org_id) do
    case Repo.query(
           """
           SELECT COUNT(*)
           FROM applicability_events
           WHERE organization_id = $1
             AND decision IS NULL
             AND review_due_date IS NOT NULL
             AND review_due_date < CURRENT_DATE
           """,
           [org_id]
         ) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  end

  defp load_uuid(bin) when is_binary(bin) and byte_size(bin) == 16 do
    case Ecto.UUID.load(bin) do
      {:ok, str} -> str
      _ -> Base.encode16(bin, case: :lower)
    end
  end

  defp load_uuid(str), do: to_string(str)

  defp plural(1), do: ""
  defp plural(_), do: "s"
end
