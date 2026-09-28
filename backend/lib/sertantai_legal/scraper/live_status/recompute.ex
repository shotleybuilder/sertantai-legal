defmodule SertantaiLegal.Scraper.LiveStatus.Recompute do
  @moduledoc """
  Corpus recompute of `live`, `live_description` and `live_evidence` from the
  stored revocation rows (`🔻_rescinded_by_stats_per_law`), with no re-scrape.

  **Guard** — `live` changes where the old rule (`legacy_live/1`, the
  pre-2026-09-28 `Amending.determine_live_status`, plus the metadata
  title / doc-status override) reproduces the law's current `live` and the new
  rule (`LiveStatus.decide/2`) differs, or where **both rules agree** on a value
  different from the current one: the current value then came from elsewhere
  (legacy import) and the data contradicts it (Jason, 2026-09-28: FEPA 1985 was
  Revoked though every rule reads Part revoked). Only when the two rules
  disagree with each other and with the current value is it a `conflict`,
  kept for review, with its description following the kept `live`.

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

    @type action :: :change | :conflict | :needs_application | :describe | :same
    @type t :: %__MODULE__{}
  end

  @doc """
  Every UK law's outcome; `:same` rows need no write. `overrides:
  %{name => %{stats: map | nil, geo_extent: String.t() | nil}}` previews
  planned data (e.g. `EffectsBackfill.plan/1`) without writing it.
  """
  @spec plan(keyword()) :: [Change.t()]
  def plan(opts \\ []) do
    trust? = Keyword.get(opts, :trust_revoker_extent, false)
    overrides = Keyword.get(opts, :overrides, %{})
    names = Keyword.get(opts, :names)

    {filter, params} = if names, do: {"AND name = ANY($1)", [names]}, else: {"", []}

    %{rows: rows} =
      Repo.query!(
        """
        SELECT name, title_en, type_code, geo_extent, live, live_description, document_status,
               "🔻_rescinded_by_stats_per_law", coalesce(is_making, false),
               application_clause, application_regions, application_source,
               geo_extent_source, coalesce(enacted_by, '{}')
        FROM legal_register WHERE country = 'uk' #{filter} ORDER BY name
        """,
        params,
        timeout: :infinity
      )

    laws =
      Enum.map(rows, fn [n, t, ty, e, l, d, ds, st, m, ac, ar, as, es, eb] ->
        %{
          name: n,
          title: t,
          type: ty,
          extent: e,
          live: l,
          desc: d,
          doc_status: ds,
          stats: st,
          is_making: m,
          application: application(ac, ar, as),
          clause_read: ac != nil,
          text_repealed: (ac || %{})["text_repealed"] == true,
          extent_source: es,
          enacted_by: eb
        }
      end)

    revokers = if names, do: revokers_of(laws), else: all_revokers()
    parents = parent_extents(laws, names)

    laws
    |> Enum.map(&override(&1, overrides))
    |> Enum.map(&outcome(&1, revokers, parents, trust?))
  end

  @doc """
  Re-decide one law's live status and write it (guarded as `plan/1`). Called
  after its LAT persist refreshes extent and application (`ExtentBackfill`).
  """
  @spec refresh(String.t()) :: %{atom() => non_neg_integer()}
  def refresh(law_name), do: [names: [law_name]] |> plan() |> write()

  @doc "Write every non-`:same` outcome, after snapshotting to `snapshot_table`."
  @spec apply!([Change.t()], String.t()) :: %{atom() => non_neg_integer()}
  def apply!(changes, snapshot_table) do
    {:ok, counts} =
      Repo.transaction(
        fn ->
          Repo.query!(
            "CREATE TABLE #{snapshot_table} AS SELECT id, country, name, live, live_description, live_from_changes, live_evidence, now() AS snapshot_at FROM legal_register WHERE country = 'uk'",
            [],
            timeout: :infinity
          )

          write(changes)
        end,
        timeout: :infinity
      )

    counts
  end

  # Write every non-`:same` outcome (no snapshot).
  defp write(changes) do
    todo = Enum.reject(changes, &(&1.action == :same))

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

    Enum.frequencies_by(todo, & &1.action)
  end

  # A record_change_log entry for a `live` change only (descriptions are derived).
  defp change_entry(%Change{action: :change} = c) do
    {:ok, entry} =
      ChangeLogger.build_change_entry(%{live: c.live}, %{live: c.new_live}, "live_recompute",
        source: "live_status"
      )

    reason =
      if c.evidence["replaced_legacy_live"],
        do:
          "live status parse fix 2026-09-28: #{c.kind}; old and new rules agree, legacy value replaced",
        else: "live status parse fix 2026-09-28: #{c.kind}"

    Map.put(entry, "reason", reason)
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

  # Replace stored stats / extent with planned values (nil = keep stored)
  defp override(law, overrides) do
    case Map.get(overrides, law.name) do
      nil -> law
      o -> %{law | extent: o[:geo_extent] || law.extent, stats: o[:stats] || law.stats}
    end
  end

  defp application(clause, fractalaw, source), do: law_application(clause, fractalaw, source)

  @doc """
  A law's application regions (E/W/S/NI) for `LiveStatus`: its own
  `application_clause` (legal), else fractalaw's `application_regions` when
  they rest on text or title (not an extent fallback); else nil.
  """
  @spec law_application(map() | nil, [String.t()] | nil, String.t() | nil) ::
          [String.t()] | nil
  def law_application(%{"regions" => [_ | _] = regions}, _fractalaw, _source), do: regions

  def law_application(_clause, [_ | _] = fractalaw, source)
      when source in ["text_clause", "title"],
      do: fractalaw |> Enum.join("+") |> String.replace("_", " ") |> nations()

  def law_application(_clause, _fractalaw, _source), do: nil

  defp nations(joined) do
    up = String.upcase(joined)

    [{"ENGLAND", "E"}, {"WALES", "W"}, {"SCOTLAND", "S"}, {"NORTHERN IRELAND", "NI"}]
    |> Enum.filter(fn {n, _} -> String.contains?(up, n) end)
    |> Enum.map(&elem(&1, 1))
    |> case do
      [] -> nil
      r -> r
    end
  end

  # --- per law ---

  defp outcome(law, revokers, parents, trust?) do
    rows = LiveStatus.rows_from_stats(law.stats)
    metadata = metadata_source(law.title, law.doc_status)
    live = law.live

    base = %{name: law.name, title: law.title, live: live, is_making: law.is_making}

    cond do
      metadata != nil ->
        decision = LiveStatus.from_metadata(elem(metadata, 0), elem(metadata, 1))
        finish(base, live, decision, @live_revoked, nil)

      rows != [] ->
        decision =
          LiveStatus.decide(rows, %{
            law_type: law.type,
            law_extent: law.extent,
            law_title: law.title,
            law_application: law.application,
            law_clause_read: law.clause_read,
            law_text_repealed: law.text_repealed,
            law_extent_source: law.extent_source,
            parent_regions: parent_regions(law.enacted_by, parents),
            revokers: revokers,
            trust_revoker_extent: trust?
          })

        finish(base, live, decision, legacy_live(rows), decision.live)

      true ->
        describe_only(base, live, law.desc)
    end
  end

  defp finish(base, live, decision, old_rule, from_changes) do
    {action, new_live, description, evidence} =
      cond do
        live == decision.live ->
          {:describe, live, decision.description, decision.evidence}

        decision.evidence["application_unknown"] == true ->
          kept = LiveStatus.from_live(live)

          {:needs_application, live, kept.description,
           Map.merge(decision.evidence, %{"live_kept" => true, "decided_live" => decision.live})}

        live == old_rule ->
          {:change, decision.live, decision.description, decision.evidence}

        # Both rules give the same answer from the same rows: the current
        # value came from elsewhere (legacy import) and is replaced.
        old_rule == decision.live ->
          {:change, decision.live, decision.description,
           Map.put(decision.evidence, "replaced_legacy_live", live)}

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

  @doc """
  Regions (E/W/S/NI) of a law's enabling Acts with a sourced extent, from
  `%{name => {geo_extent, geo_extent_source}}`; nil when none.
  """
  @spec parent_regions([String.t()], map()) :: [String.t()] | nil
  def parent_regions(enacted_by, extents) do
    enacted_by
    |> Enum.flat_map(fn p ->
      case Map.get(extents, p) do
        {extent, source} when source not in [nil, ""] -> LiveStatus.regions(extent) || []
        _ -> []
      end
    end)
    |> Enum.uniq()
    |> case do
      [] -> nil
      r -> r
    end
  end

  defp parent_extents(laws, names) do
    {filter, params} =
      if names,
        do: {"AND name = ANY($1)", [laws |> Enum.flat_map(& &1.enacted_by) |> Enum.uniq()]},
        else: {"", []}

    %{rows: rows} =
      Repo.query!(
        "SELECT name, geo_extent, geo_extent_source FROM legal_register WHERE country = 'uk' #{filter}",
        params,
        timeout: :infinity
      )

    Map.new(rows, fn [n, e, s] -> {n, {e, s}} end)
  end

  defp revokers_of(laws) do
    laws
    |> Enum.flat_map(&LiveStatus.rows_from_stats(&1.stats))
    |> Enum.map(& &1.by)
    |> LiveStatus.Revokers.load()
  end

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
