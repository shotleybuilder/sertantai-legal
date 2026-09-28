defmodule SertantaiLegal.Scraper.LiveStatus.Recompute do
  @moduledoc """
  Corpus recompute of `live`, `live_description` and `live_evidence` from the
  stored revocation rows (`🔻_rescinded_by_stats_per_law`), with no re-scrape.

  **Guard** — `live` changes only where the old rule (`legacy_live/1`, the
  pre-2026-09-28 `Amending.determine_live_status`, plus the metadata
  title / doc-status override) reproduces the law's current `live` and the new
  rule (`LiveStatus.decide/2`) differs. That isolates exactly this fix: a law
  whose status came from elsewhere (legacy import, EU law, manual edit) keeps
  its `live`; when the new rule disagrees with it the row is a `conflict` for
  review, and its description follows the kept `live`.

  Laws without stored rows keep `live` and `live_evidence`; only a description
  that contradicts `live` (legacy "Current legislation" on a Revoked law) is
  replaced with a neutral one.

  `plan/0` is read-only. `apply!/1` snapshots the four columns first.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeLogger
  alias SertantaiLegal.Scraper.LiveStatus

  @live_in_force "✔ In force"
  @live_part_revoked "⭕ Part Revocation / Repeal"
  @live_revoked "❌ Revoked / Repealed / Abolished"

  defmodule Change do
    @moduledoc "One law's recompute outcome."
    @enforce_keys [:name, :action, :live, :new_live, :description, :evidence]
    defstruct [
      :name,
      :title,
      :action,
      :live,
      :old_rule_live,
      :new_live,
      :kind,
      :description,
      :evidence,
      :live_from_changes,
      :is_making,
      keep_evidence: false
    ]

    @type action :: :change | :conflict | :describe | :same
    @type t :: %__MODULE__{}
  end

  @doc "Every UK law's outcome; `:same` rows need no write."
  @spec plan(keyword()) :: [Change.t()]
  def plan(opts \\ []) do
    trust? = Keyword.get(opts, :trust_revoker_extent, false)

    %{rows: rows} =
      Repo.query!(
        """
        SELECT name, title_en, type_code, geo_extent, live, live_description, document_status,
               "🔻_rescinded_by_stats_per_law", live_evidence, coalesce(is_making, false)
        FROM legal_register WHERE country = 'uk' ORDER BY name
        """,
        [],
        timeout: :infinity
      )

    revokers = all_revokers()
    Enum.map(rows, &outcome(&1, revokers, trust?))
  end

  @doc "Write every non-`:same` outcome, after snapshotting to `snapshot_table`."
  @spec apply!([Change.t()], String.t()) :: %{atom() => non_neg_integer()}
  def apply!(changes, snapshot_table) do
    todo = Enum.reject(changes, &(&1.action == :same))

    Repo.transaction(
      fn ->
        Repo.query!(
          "CREATE TABLE #{snapshot_table} AS SELECT id, country, name, live, live_description, live_from_changes, live_evidence, now() AS snapshot_at FROM legal_register WHERE country = 'uk'",
          [],
          timeout: :infinity
        )

        for c <- todo do
          log_entry = change_entry(c)

          Repo.query!(
            """
            UPDATE legal_register
            SET live = $2, live_description = $3,
                live_evidence = CASE WHEN $6 THEN live_evidence ELSE $4 END,
                live_from_changes = coalesce($5, live_from_changes),
                record_change_log = CASE WHEN $7::jsonb IS NULL THEN record_change_log
                                         ELSE coalesce(record_change_log, '{}') || $7::jsonb END
            WHERE country = 'uk' AND name = $1
            """,
            [
              c.name,
              c.new_live,
              c.description,
              c.evidence,
              c.live_from_changes,
              c.keep_evidence,
              log_entry
            ]
          )
        end
      end,
      timeout: :infinity
    )

    todo |> Enum.frequencies_by(& &1.action)
  end

  # A record_change_log entry for a `live` change only (descriptions are derived).
  defp change_entry(%Change{action: :change} = c) do
    {:ok, entry} =
      ChangeLogger.build_change_entry(%{live: c.live}, %{live: c.new_live}, "live_recompute",
        source: "live_status"
      )

    Map.put(entry, "reason", "live status parse fix 2026-09-28: #{c.kind}")
  end

  defp change_entry(_), do: nil

  @doc """
  The old rule, reproduced for the guard: any repeal/revoke row whose target
  is a whole instrument (or "in full") revokes; revocation rows without one
  part-revoke; none leaves the law in force.
  """
  @spec legacy_live([LiveStatus.row()]) :: String.t()
  def legacy_live(rows) do
    revocations =
      Enum.filter(rows, fn r ->
        a = norm(r.affect)
        String.contains?(a, "repeal") or String.contains?(a, "revoke") or a in ["rev", "rep"]
      end)

    cond do
      revocations == [] -> @live_in_force
      Enum.any?(revocations, &legacy_whole?/1) -> @live_revoked
      true -> @live_part_revoked
    end
  end

  # --- per law ---

  defp outcome(
         [name, title, type, extent, live, desc, doc_status, stats, _ev, making],
         revokers,
         trust?
       ) do
    rows = LiveStatus.rows_from_stats(stats)
    metadata = metadata_source(title, doc_status)

    base = %{name: name, title: title, live: live, is_making: making}

    cond do
      metadata != nil ->
        decision = LiveStatus.from_metadata(elem(metadata, 0), elem(metadata, 1))
        finish(base, live, decision, @live_revoked, nil)

      rows != [] ->
        decision =
          LiveStatus.decide(rows, %{
            law_type: type,
            law_extent: extent,
            law_title: title,
            revokers: revokers,
            trust_revoker_extent: trust?
          })

        finish(base, live, decision, legacy_live(rows), decision.live)

      true ->
        describe_only(base, live, desc)
    end
  end

  defp finish(base, live, decision, old_rule, from_changes) do
    {action, new_live, description, evidence} =
      cond do
        live == decision.live ->
          {:describe, live, decision.description, decision.evidence}

        live == old_rule ->
          {:change, decision.live, decision.description, decision.evidence}

        true ->
          kept = LiveStatus.from_live(live)

          {:conflict, live, kept.description,
           Map.merge(decision.evidence, %{"live_kept" => true, "decided_live" => decision.live})}
      end

    struct!(
      Change,
      Map.merge(base, %{
        action: action,
        old_rule_live: old_rule,
        new_live: new_live,
        kind: decision.kind,
        description: description,
        evidence: evidence,
        live_from_changes: from_changes
      })
    )
  end

  defp describe_only(base, live, desc) do
    action = if contradicts?(live, desc), do: :describe, else: :same
    description = if action == :describe, do: neutral(live), else: desc

    struct!(
      Change,
      Map.merge(base, %{
        action: action,
        new_live: live,
        description: description,
        evidence: nil,
        keep_evidence: true
      })
    )
  end

  # --- helpers ---

  defp all_revokers do
    %{rows: rows} =
      Repo.query!(
        "SELECT name, geo_extent, md_date FROM legal_register WHERE country = 'uk'",
        [],
        timeout: :infinity
      )

    Map.new(rows, fn [n, e, d] -> {n, %{extent: e, date: d}} end)
  end

  defp metadata_source(title, doc_status) do
    t = String.downcase(title || "")

    cond do
      Regex.match?(~r/\(repealed\b/, t) -> {:title, "Repealed"}
      Regex.match?(~r/\(revoked\b/, t) -> {:title, "Revoked"}
      String.downcase(doc_status || "") == "repealed" -> {:doc_status, "Repealed"}
      String.downcase(doc_status || "") == "revoked" -> {:doc_status, "Revoked"}
      true -> nil
    end
  end

  @doc "Does a (legacy) description contradict `live`?"
  @spec contradicts?(String.t() | nil, String.t() | nil) :: boolean()
  def contradicts?(live, desc) do
    d = norm(desc)

    cond do
      d == "" -> false
      live == @live_revoked -> Regex.match?(~r/current|revised|in force/, d)
      live in [@live_in_force, @live_part_revoked] -> Regex.match?(~r/revoked|repealed/, d)
      true -> false
    end
  end

  defp neutral(@live_revoked), do: "Revoked (source not recorded)"
  defp neutral(live), do: LiveStatus.from_live(live).description

  @whole_targets ~w(regulations act order rules scheme measure charter byelaws instrument)
  defp legacy_whole?(%{affect: affect, target: target}) do
    a = norm(affect)
    t = norm(target)
    whole_target? = t == "" or t in @whole_targets or String.contains?(t, "whole instrument")

    cond do
      String.contains?(a, "in full") -> true
      String.contains?(a, "in part") or String.contains?(a, "except") -> false
      Regex.match?(~r/words |word |entry |entries |comma /, a) -> false
      String.contains?(a, "power to") -> false
      a in ["rev", "rep"] -> whole_target?
      String.contains?(a, "repeal") or String.contains?(a, "revoke") -> whole_target?
      true -> false
    end
  end

  defp norm(nil), do: ""
  defp norm(s), do: s |> String.downcase() |> String.trim()
end
