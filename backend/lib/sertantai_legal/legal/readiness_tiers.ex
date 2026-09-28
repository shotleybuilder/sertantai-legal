defmodule SertantaiLegal.Legal.ReadinessTiers do
  @moduledoc """
  The enrichment readiness tiers (session 2026-09-27-enrichment-readiness),
  worked in order:

  - **Tier 0** — QQ's legal register: laws QQ's organisation marks `yes` in
    `org_applicabilities` (compliance's table, shared dev DB).
  - **Tier 1** — key families (occupational safety, fire, environmental
    protection, …), excluding Tier 0, sub-batched by family cluster
    (`tier1_clusters/0`). The family list is the Tier 1 session's draft,
    pending Jason's confirmation.
  - **Tier 2** — everything else.

  `tier_sql/0` is a SQL `CASE` over `legal_register r` giving the batch label
  (`"0"`, `"1a"`…`"1e"`, `"2"`), for use in other queries.
  """

  @qq_org "QQ"

  # {label, description, family regex (PostgreSQL, matched against r.family)}
  @tier1_clusters [
    {"1a", "OH&S + FIRE", "(OH&S|FIRE)"},
    {"1b", "Waste + Water", "(WASTE$|WATER & WASTEWATER)"},
    {"1c", "Environmental protection, pollution, air, noise",
     "(ENVIRONMENTAL PROTECTION|POLLUTION|AIR QUALITY|NOISE)"},
    {"1d", "Climate change + nuclear", "(CLIMATE CHANGE|NUCLEAR & RADIOLOGICAL)"},
    {"1e", "Public and transport safety",
     "(PUBLIC: Building Safety|PUBLIC: Consumer / Product Safety|TRANSPORT: (Rail|Road|Air|Maritime) Safety)"}
  ]

  @doc "Tier 1 family clusters: `{label, description, family regex}`."
  @spec tier1_clusters() :: [{String.t(), String.t(), String.t()}]
  def tier1_clusters, do: @tier1_clusters

  @doc """
  SQL expression (over `legal_register r`) giving a law's tier batch label:
  `"0"`, a Tier 1 cluster label, or `"2"`.
  """
  @spec tier_sql() :: String.t()
  def tier_sql do
    clusters =
      Enum.map_join(@tier1_clusters, "\n", fn {label, _, regex} ->
        "WHEN r.family ~ '#{regex}' THEN '#{label}'"
      end)

    """
    CASE
      WHEN EXISTS (
        SELECT 1 FROM org_applicabilities a JOIN organizations o ON o.id = a.organization_id
        WHERE o.name = '#{@qq_org}' AND a.status = 'yes' AND a.law_name = r.name
      ) THEN '0'
      #{clusters}
      ELSE '2'
    END
    """
  end
end
