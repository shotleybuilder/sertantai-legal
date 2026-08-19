defmodule SertantaiLegal.Scraper.RootResolver do
  @moduledoc """
  Links cross-reference definitions to their root (originating) definitions.

  A cross-ref definition like "has the meaning given in section 126(1) of the
  Scotland Act 1998" gets linked to the Scotland Act 1998's own definition of
  the same term via the `definition_links` junction table.

  Orchestrates four sub-modules:
  - `Indexes` — builds in-memory lookup indexes from the DB
  - `CitationExtractor` — pure citation extraction from definition text
  - `Matcher` — pure resolution logic using indexes
  - `Persister` — batch writes to DB

  Designed to be re-run as more parent laws get their definitions parsed.

  ## Usage

      # Resolve all unlinked cross-refs
      RootResolver.resolve_all()

      # Resolve for a single term (testing)
      RootResolver.resolve_all(term: "scotland")

      # Re-resolve everything (after parsing more parent laws)
      RootResolver.resolve_all(force: true)

      # Dry run — returns results without writing
      RootResolver.resolve_all(dry_run: true)
  """

  alias SertantaiLegal.Scraper.RootResolver.{Indexes, Matcher, Persister}

  require Logger

  @missing_parents_path "data/root_resolver_missing_parents.txt"

  @type result :: %{
          resolved: non_neg_integer(),
          citation_only: non_neg_integer(),
          internal: non_neg_integer(),
          unresolved: non_neg_integer(),
          missing_parents: non_neg_integer()
        }

  @doc """
  Resolve cross-reference definitions to their roots.

  ## Options

    * `:term` — resolve a single term (for testing)
    * `:limit` — process at most N definitions
    * `:force` — re-resolve even if already linked
    * `:dry_run` — return results without writing to DB
  """
  @spec resolve_all(keyword()) :: {:ok, result()}
  def resolve_all(opts \\ []) do
    title_index = Indexes.build_title_index()
    citation_index = Indexes.build_citation_index()
    def_index = Indexes.build_definition_index()
    sibling_index = Indexes.build_sibling_index()
    enacted_by_index = Indexes.build_enacted_by_index()

    Logger.info(
      "[RootResolver] Title index: #{map_size(title_index)} laws, " <>
        "Citation index: #{map_size(citation_index)} laws, " <>
        "Definition index: #{map_size(def_index)} entries, " <>
        "Sibling index: #{map_size(sibling_index)} sections, " <>
        "Enacted-by index: #{map_size(enacted_by_index)} SIs"
    )

    defs = Indexes.fetch_cross_refs(opts)
    Logger.info("[RootResolver] Definitions to resolve: #{length(defs)}")

    grouped =
      defs
      |> Enum.map(
        &Matcher.resolve_one(
          &1,
          title_index,
          citation_index,
          def_index,
          sibling_index,
          enacted_by_index
        )
      )
      |> Enum.group_by(fn {status, _} -> status end)

    resolved = Map.get(grouped, :resolved, [])
    citation_only = Map.get(grouped, :citation_only, [])
    internal = Map.get(grouped, :internal, [])
    unresolved = Map.get(grouped, :unresolved, [])

    counts = %{
      resolved: length(resolved),
      citation_only: length(citation_only),
      internal: length(internal),
      unresolved: length(unresolved)
    }

    Logger.info(
      "[RootResolver] Results — resolved: #{counts.resolved}, " <>
        "citation_only: #{counts.citation_only}, " <>
        "internal: #{counts.internal}, " <>
        "unresolved: #{counts.unresolved}"
    )

    missing_parents = Persister.collect_missing_parents(citation_only)
    write_missing_parents(missing_parents)

    unless Keyword.get(opts, :dry_run, false) do
      Persister.apply_updates(resolved ++ citation_only)
      Logger.info("[RootResolver] Updates applied")
    end

    {:ok, Map.put(counts, :missing_parents, length(missing_parents))}
  end

  # Delegate public pure functions for backwards compatibility with existing tests
  defdelegate resolve_pronoun_ref(definition, law_name, section_id, sibling_index),
    to: Matcher

  defdelegate extract_eu_law_name(citation),
    to: SertantaiLegal.Scraper.RootResolver.CitationExtractor

  @spec write_missing_parents([String.t()]) :: :ok
  defp write_missing_parents([]), do: :ok

  defp write_missing_parents(missing) do
    path = Path.join(File.cwd!(), @missing_parents_path)
    File.write!(path, Enum.join(missing, "\n") <> "\n")

    Logger.info(
      "[RootResolver] Wrote #{length(missing)} missing parent laws to #{@missing_parents_path}" <>
        " — run: mix definitions.backfill --file #{@missing_parents_path} --force"
    )

    :ok
  end
end
