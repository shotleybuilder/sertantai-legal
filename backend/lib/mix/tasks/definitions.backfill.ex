defmodule Mix.Tasks.Definitions.Backfill do
  @shortdoc "Backfill definitions by fetching body XML and running the parser"

  @moduledoc """
  Fetches body XML from legislation.gov.uk for laws that need definition parsing,
  runs the DefinitionParser, and upserts results into legislative_definitions.

  Respects `definitions_parsed_at` — skips laws already parsed unless `--force` is given.
  Rate-limited to avoid overloading legislation.gov.uk (2s between requests).

  ## Usage

      mix definitions.backfill [options]

  ## Options

    * `--scope unparsed` — Laws not yet parsed for definitions (default)
    * `--scope csv` — Re-parse laws with CSV-imported definitions (scope backfill)
    * `--scope all` — All making laws not fully revoked
    * `--family FAMILY` — Filter by family (e.g. "OH&S")
    * `--law LAW_NAME` — Parse a single law (for testing)
    * `--limit N` — Process at most N laws
    * `--dry-run` — Show which laws would be processed, don't fetch or write
    * `--force` — Ignore definitions_parsed_at, re-parse even if already done

  ## Examples

      # Parse a single law (test)
      mix definitions.backfill --law UK_uksi_1992_3004

      # Backfill first 10 unparsed making laws
      mix definitions.backfill --limit 10

      # Re-parse CSV-imported laws for scope improvement
      mix definitions.backfill --scope csv --limit 50

      # Full backfill (will take ~1.5 hours at 2s rate limit)
      mix definitions.backfill --scope unparsed
  """

  use Mix.Task

  @requirements ["app.start"]

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.DefinitionParser
  alias SertantaiLegal.Scraper.DefinitionPersister
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          scope: :string,
          family: :string,
          law: :string,
          limit: :integer,
          dry_run: :boolean,
          force: :boolean
        ],
        aliases: [n: :limit, l: :law, f: :family]
      )

    scope = Keyword.get(opts, :scope, "unparsed")
    family = Keyword.get(opts, :family)
    single_law = Keyword.get(opts, :law)
    limit = Keyword.get(opts, :limit)
    dry_run? = Keyword.get(opts, :dry_run, false)
    force? = Keyword.get(opts, :force, false)

    laws = fetch_target_laws(scope, family, single_law, limit, force?)

    Mix.shell().info("""

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      Definition Backfill
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      Scope: #{scope}#{if family, do: " (family: #{family})", else: ""}
      Laws to process: #{length(laws)}
      Mode: #{if dry_run?, do: "DRY RUN", else: "LIVE"}
      Force re-parse: #{force?}
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    """)

    if dry_run? do
      for {name, type_code} <- Enum.take(laws, 20) do
        Mix.shell().info("  #{name} (#{type_code})")
      end

      if length(laws) > 20 do
        Mix.shell().info("  ... +#{length(laws) - 20} more")
      end
    else
      process_laws(laws)
    end
  end

  defp fetch_target_laws(scope, family, single_law, limit, force?) do
    cond do
      single_law ->
        # Single law mode
        case Repo.query(
               "SELECT name, type_code FROM legal_register WHERE name = $1",
               [single_law]
             ) do
          {:ok, %{rows: [[name, type_code]]}} -> [{name, type_code}]
          _ -> Mix.raise("Law not found: #{single_law}")
        end

      true ->
        {where, params} = build_query(scope, family, force?)

        sql = """
        SELECT lr.name, lr.type_code
        FROM legal_register lr
        WHERE #{where}
        ORDER BY lr.name
        #{if limit, do: "LIMIT #{limit}", else: ""}
        """

        case Repo.query(sql, params) do
          {:ok, %{rows: rows}} ->
            Enum.map(rows, fn [name, type_code] -> {name, type_code} end)

          {:error, err} ->
            Mix.raise("Query failed: #{inspect(err)}")
        end
    end
  end

  defp build_query("unparsed", family, force?) do
    base = "lr.is_making = true AND lr.live != '❌ Revoked / Repealed / Abolished'"

    base =
      if force?,
        do: base,
        else: base <> " AND lr.definitions_parsed_at IS NULL"

    if family do
      {base <> " AND lr.family ILIKE $1", ["%" <> family <> "%"]}
    else
      {base, []}
    end
  end

  defp build_query("csv", family, force?) do
    base =
      "EXISTS (SELECT 1 FROM legislative_definitions ld WHERE ld.law_name = lr.name AND ld.source = 'csv_import')"

    base =
      if force?,
        do: base,
        else: base <> " AND lr.definitions_parsed_at IS NULL"

    if family do
      {base <> " AND lr.family ILIKE $1", ["%" <> family <> "%"]}
    else
      {base, []}
    end
  end

  defp build_query("all", family, force?) do
    base = "lr.is_making = true AND lr.live != '❌ Revoked / Repealed / Abolished'"

    base =
      if force?,
        do: base,
        else: base <> " AND lr.definitions_parsed_at IS NULL"

    if family do
      {base <> " AND lr.family ILIKE $1", ["%" <> family <> "%"]}
    else
      {base, []}
    end
  end

  defp process_laws(laws) do
    total = length(laws)

    stats =
      laws
      |> Enum.with_index(1)
      |> Enum.reduce(%{success: 0, no_defs: 0, errors: 0, total_defs: 0}, fn {{name, type_code},
                                                                                idx},
                                                                               stats ->
        [_, _tc, year, number] = String.split(name, "_", parts: 4)
        path = "/#{type_code}/#{year}/#{number}/body/data.xml"

        result =
          case Client.fetch_xml(path) do
            {:ok, xml} ->
              definitions =
                DefinitionParser.parse(xml, %{law_name: name, type_code: type_code})

              if definitions == [] do
                IO.write("  [#{idx}/#{total}] #{name} — no definitions\r")
                {:ok, 0}
              else
                case DefinitionPersister.persist(definitions, name) do
                  {:ok, %{upserted: count}} ->
                    IO.write(
                      "  [#{idx}/#{total}] #{name} — #{count} definitions (#{length(definitions)} parsed)\r"
                    )

                    {:ok, count}

                  {:error, reason} ->
                    Mix.shell().info(
                      "  [#{idx}/#{total}] #{name} — persist error: #{reason}"
                    )

                    :error
                end
              end

            {:error, code, msg} ->
              Mix.shell().info("  [#{idx}/#{total}] #{name} — fetch error: #{code} #{msg}")
              :error
          end

        # Mark as parsed regardless of result (prevents retry loop)
        Repo.query(
          "UPDATE legal_register SET definitions_parsed_at = NOW() WHERE name = $1",
          [name]
        )

        case result do
          {:ok, count} when count > 0 ->
            %{stats | success: stats.success + 1, total_defs: stats.total_defs + count}

          {:ok, 0} ->
            %{stats | no_defs: stats.no_defs + 1}

          :error ->
            %{stats | errors: stats.errors + 1}
        end
      end)

    Mix.shell().info("""

    ── Backfill Complete ──────────────────────────
    Laws processed:      #{total}
    With definitions:    #{stats.success}
    No definitions:      #{stats.no_defs}
    Errors:              #{stats.errors}
    Total defs upserted: #{stats.total_defs}
    """)
  end
end
