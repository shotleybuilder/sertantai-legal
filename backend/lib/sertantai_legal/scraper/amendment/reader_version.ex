defmodule SertantaiLegal.Scraper.Amendment.ReaderVersion do
  @moduledoc """
  The version of the code an amending law's stored rules depend on
  (amendment-rules AR-04, `SourceVersion`): what the read pass's reading
  reaches (`Amendment.ReadLaw`: the provisions read, the reader, the rule
  and the amending-law document readers they use), by name. The read pass
  records it in each amending law's index (`Amendment.Index`); rules read
  by older code are stale, and the read pass re-reads them.

  Never the read pass's orchestration, the store, the index or the checks,
  so an edit to those stales no rule. `AmendmentReadStampsTest` holds it
  to exactly `ReadLaw`'s reach (the Amending-law reader stamps session,
  2026-11-26; before it, globs that missed `ReadLaw`, `ProvisionRead`,
  `LawDoc` and `AmendingLaw.Enacted`).
  """

  @patterns ~w(
    lib/sertantai_legal/scraper/amending_law/defined_terms.ex
    lib/sertantai_legal/scraper/amending_law/doc.ex
    lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
    lib/sertantai_legal/scraper/amending_law/enacted.ex
    lib/sertantai_legal/scraper/amending_law/locator.ex
    lib/sertantai_legal/scraper/amending_law/operation.ex
    lib/sertantai_legal/scraper/amending_law/pointer.ex
    lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
    lib/sertantai_legal/scraper/amending_law/text.ex
    lib/sertantai_legal/scraper/amending_law/listed_places.ex
    lib/sertantai_legal/scraper/amendment/law_doc.ex
    lib/sertantai_legal/scraper/amendment/provision_read.ex
    lib/sertantai_legal/scraper/amendment/read_law.ex
    lib/sertantai_legal/scraper/amendment/reader.ex
    lib/sertantai_legal/scraper/amendment/reader/amendment_table.ex
    lib/sertantai_legal/scraper/amendment/reader/brackets.ex
    lib/sertantai_legal/scraper/amendment/reader/clauses.ex
    lib/sertantai_legal/scraper/amendment/reader/commencing.ex
    lib/sertantai_legal/scraper/amendment/reader/eu_citation.ex
    lib/sertantai_legal/scraper/amendment/reader/eu_spelling.ex
    lib/sertantai_legal/scraper/amendment/reader/law_named.ex
    lib/sertantai_legal/scraper/amendment/reader/eu_dated_title.ex
    lib/sertantai_legal/scraper/amendment/reader/new_numbers.ex
    lib/sertantai_legal/scraper/amendment/reader/provision_table.ex
    lib/sertantai_legal/scraper/amendment/reader/repeal_table.ex
    lib/sertantai_legal/scraper/amendment/reader/savings.ex
    lib/sertantai_legal/scraper/amendment/reader/scope.ex
    lib/sertantai_legal/scraper/amendment/reader/targets.ex
    lib/sertantai_legal/scraper/amendment/reader/whole_law.ex
    lib/sertantai_legal/scraper/amendment/rule.ex
    lib/sertantai_legal/scraper/lat_parser/xml.ex
    lib/sertantai_legal/scraper/lat_ref.ex
    lib/sertantai_legal/scraper/territory.ex
  )

  use SertantaiLegal.Scraper.SourceVersion, patterns: @patterns

  @doc "The files this stamp lists."
  @spec patterns() :: [String.t()]
  def patterns, do: @patterns

  @doc """
  Where a read path ends, for the stamps' tests: the store, the index, the
  read pass and the stamps themselves, which shape no reading.
  """
  @spec boundaries() :: [String.t()]
  def boundaries,
    do: ~w(
      lib/sertantai_legal/scraper/amendment/store.ex
      lib/sertantai_legal/scraper/amendment/index.ex
      lib/sertantai_legal/scraper/amendment/read_pass.ex
      lib/sertantai_legal/scraper/amendment/reader_version.ex
      lib/sertantai_legal/scraper/amendment/catalogue_version.ex
      lib/sertantai_legal/scraper/catalogue_cache.ex
    )
end
