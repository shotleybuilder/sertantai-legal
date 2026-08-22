defmodule SertantaiLegalWeb.DefinitionsAdminController do
  use SertantaiLegalWeb, :controller

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.RootResolver
  alias SertantaiLegal.Scraper.RootResolver.Diagnostic

  require Logger

  @moduledoc """
  Admin API for definition resolution management.

  Authenticated endpoints for viewing stats, running diagnostics,
  triggering parse and resolve operations.

  ## Endpoints

    * `GET /api/admin/definitions/stats` — per-family resolution stats
    * `GET /api/admin/definitions/diagnostic` — run diagnostic, return findings
    * `POST /api/admin/definitions/parse` — trigger definition parsing
    * `POST /api/admin/definitions/resolve` — trigger root resolver
  """

  # ── Stats ────────────────────────────────────────────────────────

  @family_stats_sql """
  WITH def_counts AS (
    SELECT
      lr.family,
      COUNT(*) AS total_defs,
      COUNT(*) FILTER (WHERE ld.references_other_law = true AND ld.citation = false) AS cross_refs,
      COUNT(*) FILTER (WHERE ld.citation = true) AS citation_defs,
      COUNT(*) FILTER (WHERE ld.references_other_law = false AND ld.citation = false) AS substantive_defs
    FROM legislative_definitions ld
    JOIN legal_register lr ON lr.name = ld.law_name
    WHERE lr.family IS NOT NULL
    GROUP BY lr.family
  ),
  linked_counts AS (
    SELECT
      lr.family,
      COUNT(DISTINCT dl.child_definition_id) AS linked
    FROM definition_links dl
    JOIN legislative_definitions ld ON ld.id = dl.child_definition_id
    JOIN legal_register lr ON lr.name = ld.law_name
    WHERE lr.family IS NOT NULL
      AND ld.references_other_law = true
      AND ld.citation = false
    GROUP BY lr.family
  ),
  citation_resolved AS (
    SELECT
      lr.family,
      COUNT(*) AS citation_resolved
    FROM legislative_definitions ld
    JOIN legal_register lr ON lr.name = ld.law_name
    WHERE ld.references_other_law = true
      AND ld.citation = false
      AND lr.family IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM definition_links dl WHERE dl.child_definition_id = ld.id)
      AND ld.referenced_law_citation IS NOT NULL
    GROUP BY lr.family
  )
  SELECT
    dc.family,
    dc.total_defs,
    dc.cross_refs,
    COALESCE(lc.linked, 0)::int AS linked,
    COALESCE(cr.citation_resolved, 0)::int AS citation_resolved,
    dc.citation_defs,
    dc.substantive_defs
  FROM def_counts dc
  LEFT JOIN linked_counts lc ON lc.family = dc.family
  LEFT JOIN citation_resolved cr ON cr.family = dc.family
  ORDER BY dc.family
  """

  @totals_sql """
  SELECT
    COUNT(*) AS total_defs,
    COUNT(*) FILTER (WHERE ld.references_other_law = true AND ld.citation = false) AS cross_refs,
    COUNT(*) FILTER (WHERE ld.citation = true) AS citation_defs,
    (SELECT COUNT(DISTINCT dl.child_definition_id)
     FROM definition_links dl
     JOIN legislative_definitions d ON d.id = dl.child_definition_id
     WHERE d.references_other_law = true AND d.citation = false) AS linked
  FROM legislative_definitions ld
  """

  @doc "GET /api/admin/definitions/stats — per-family resolution stats with totals."
  def stats(conn, _params) do
    with {:ok, %{rows: family_rows, columns: cols}} <- Repo.query(@family_stats_sql),
         {:ok, %{rows: [totals_row]}} <- Repo.query(@totals_sql) do
      families =
        Enum.map(family_rows, fn row ->
          map = Enum.zip(cols, row) |> Map.new()
          cross_refs = map["cross_refs"]
          linked = map["linked"]
          citation_resolved = map["citation_resolved"]
          effective = linked + citation_resolved

          effective_pct =
            if cross_refs > 0, do: Float.round(100.0 * effective / cross_refs, 1), else: 100.0

          %{
            family: map["family"],
            total_defs: map["total_defs"],
            cross_refs: cross_refs,
            linked: linked,
            citation_resolved: citation_resolved,
            effective: effective,
            effective_pct: effective_pct,
            unlinked: cross_refs - linked,
            citation_defs: map["citation_defs"],
            substantive_defs: map["substantive_defs"]
          }
        end)

      [total_defs, cross_refs, citation_defs, linked] = totals_row

      json(conn, %{
        totals: %{
          total_defs: total_defs,
          cross_refs: cross_refs,
          linked: linked,
          citation_defs: citation_defs
        },
        families: families
      })
    else
      {:error, err} ->
        conn |> put_status(500) |> json(%{error: "Stats query failed: #{inspect(err)}"})
    end
  end

  # ── Diagnostic ───────────────────────────────────────────────────

  @ceiling_categories [
    :parent_revoked,
    :parent_not_in_lrt,
    :internal_ref,
    :international_convention
  ]

  @doc "GET /api/admin/definitions/diagnostic — run diagnostic, return classified findings."
  def diagnostic(conn, params) do
    opts = if family = params["family"], do: [family: family], else: []

    case Diagnostic.run(opts) do
      {:ok, findings} ->
        summary = Diagnostic.summarise(findings)

        # Split by_category into actionable vs ceiling
        {actionable, ceiling} =
          summary.by_category
          |> Enum.split_with(fn {cat, _} -> cat not in @ceiling_categories end)

        actionable_total = actionable |> Enum.map(&elem(&1, 1)) |> Enum.sum()
        ceiling_total = ceiling |> Enum.map(&elem(&1, 1)) |> Enum.sum()

        findings_json =
          Enum.map(findings, fn f ->
            %{
              definition_id: encode_uuid(f.definition_id),
              law_name: f.law_name,
              term: f.term,
              category: f.category,
              citation: f.citation,
              target_law: f.target_law,
              nearest_term: f.nearest_term,
              detail: f.detail
            }
          end)

        json(conn, %{
          summary: %{
            total: summary.total,
            citation_resolved: summary.citation_resolved,
            genuinely_unresolved: summary.genuinely_unresolved,
            actionable: actionable_total,
            ceiling: ceiling_total,
            by_category: atomize_keys(summary.by_category),
            by_family: map_family_categories(summary.by_family),
            top_parents:
              Enum.map(summary.top_parents, fn {law, count} -> %{law_name: law, count: count} end)
          },
          findings: findings_json
        })
    end
  end

  # ── Parse ────────────────────────────────────────────────────────

  @doc "POST /api/admin/definitions/parse — trigger definition parsing for a law or family."
  def parse(conn, %{"law_name" => law_name}) when is_binary(law_name) do
    caller = self()

    Task.start(fn ->
      sandbox_allow(caller)
      Logger.info("[DefinitionsAdmin] Parsing definitions for #{law_name}")

      try do
        parse_single_law(law_name)
      rescue
        e ->
          Logger.error("[DefinitionsAdmin] Parse failed for #{law_name}: #{Exception.message(e)}")
      end
    end)

    json(conn, %{status: "started", scope: "law", law_name: law_name})
  end

  def parse(conn, %{"family" => family}) when is_binary(family) do
    caller = self()

    Task.start(fn ->
      sandbox_allow(caller)
      Logger.info("[DefinitionsAdmin] Parsing definitions for family #{family}")

      try do
        parse_family(family)
      rescue
        e -> Logger.error("[DefinitionsAdmin] Family parse failed: #{Exception.message(e)}")
      end
    end)

    json(conn, %{status: "started", scope: "family", family: family})
  end

  def parse(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{error: "Provide 'law_name' or 'family' in request body"})
  end

  # ── Resolve ──────────────────────────────────────────────────────

  @doc "POST /api/admin/definitions/resolve — trigger root resolver."
  def resolve(conn, params) do
    force = params["force"] == true
    caller = self()

    Task.start(fn ->
      sandbox_allow(caller)
      Logger.info("[DefinitionsAdmin] Starting resolve_all (force: #{force})")

      try do
        {:ok, result} = RootResolver.resolve_all(force: force)

        Logger.info(
          "[DefinitionsAdmin] Resolve complete — " <>
            "resolved: #{result.resolved}, citation_only: #{result.citation_only}, " <>
            "internal: #{result.internal}, unresolved: #{result.unresolved}"
        )
      rescue
        e -> Logger.error("[DefinitionsAdmin] Resolve failed: #{Exception.message(e)}")
      end
    end)

    json(conn, %{status: "started", force: force})
  end

  # ── Private ──────────────────────────────────────────────────────

  defp parse_single_law(law_name) do
    alias SertantaiLegal.Scraper.{DefinitionParser, DefinitionPersister}
    alias SertantaiLegal.Scraper.LegislationGovUk.Client

    # Look up type_code from legal_register
    case Repo.query("SELECT type_code FROM legal_register WHERE name = $1", [law_name]) do
      {:ok, %{rows: [[type_code]]}} ->
        path =
          law_name
          |> String.replace_prefix("UK_", "")
          |> String.replace("_", "/")

        case Client.fetch_xml("/#{path}/body/data.xml") do
          {:ok, xml} ->
            defs = DefinitionParser.parse(xml, %{law_name: law_name, type_code: type_code})
            Logger.info("[DefinitionsAdmin] Parsed #{length(defs)} definitions from #{law_name}")

            if defs != [] do
              {:ok, result} = DefinitionPersister.persist(defs, law_name)
              Logger.info("[DefinitionsAdmin] Upserted: #{result.upserted}")
            end

            Repo.query(
              "UPDATE legal_register SET definitions_parsed_at = NOW() WHERE name = $1",
              [law_name]
            )

          {:error, status, body} ->
            Logger.warning("[DefinitionsAdmin] Fetch failed for #{law_name}: #{status} #{body}")
        end

      {:ok, %{rows: []}} ->
        Logger.warning("[DefinitionsAdmin] Law #{law_name} not found in legal_register")

      {:error, err} ->
        Logger.error("[DefinitionsAdmin] DB error looking up #{law_name}: #{inspect(err)}")
    end
  end

  defp parse_family(family) do
    case Repo.query(
           """
           SELECT name FROM legal_register
           WHERE family = $1 AND is_making = true
             AND live != '❌ Revoked / Repealed / Abolished'
             AND definitions_parsed_at IS NULL
           ORDER BY name
           """,
           [family]
         ) do
      {:ok, %{rows: rows}} ->
        law_names = Enum.map(rows, fn [name] -> name end)
        Logger.info("[DefinitionsAdmin] #{length(law_names)} unparsed laws in #{family}")

        Enum.each(law_names, fn law_name ->
          parse_single_law(law_name)
          # Rate limit to avoid overloading legislation.gov.uk
          Process.sleep(2_000)
        end)

      {:error, err} ->
        Logger.error("[DefinitionsAdmin] Family query failed: #{inspect(err)}")
    end
  end

  # Convert raw binary UUID (16 bytes from Ecto) to string format
  defp encode_uuid(<<_::128>> = bin) do
    case Ecto.UUID.cast(bin) do
      {:ok, str} -> str
      :error -> Base.encode16(bin, case: :lower)
    end
  end

  defp encode_uuid(str) when is_binary(str), do: str

  defp atomize_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp map_family_categories(by_family) do
    Map.new(by_family, fn {family, cats} ->
      {family, atomize_keys(cats)}
    end)
  end

  # In test mode, allow the spawned Task to use the caller's sandbox connection.
  # In prod/dev, this is a no-op.
  if Mix.env() == :test do
    defp sandbox_allow(caller) do
      Ecto.Adapters.SQL.Sandbox.allow(Repo, caller, self())
    end
  else
    defp sandbox_allow(_caller), do: :ok
  end
end
