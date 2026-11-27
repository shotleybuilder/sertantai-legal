defmodule SertantaiLegal.Scraper.Amendment.CatalogueVersion do
  @moduledoc """
  The version of the code an amending law's catalogue reading depends on
  (`SourceVersion`): what the catalogue's reading reaches
  (`Amendment.CatalogueRead`: the catalogue's classes and examples, the
  reader they run and the document), by name. `CatalogueRead` keys its
  `CatalogueCache` on it, so a change to any of them reads every amending
  law again. `AmendmentReadStampsTest` holds it to exactly that reach (the
  Amending-law reader stamps session, 2026-11-26; before it, globs).
  """

  @patterns ~w(
    lib/sertantai_legal/scraper/amending_law/defined_terms.ex
    lib/sertantai_legal/scraper/amending_law/doc.ex
    lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
    lib/sertantai_legal/scraper/amending_law/enacted.ex
    lib/sertantai_legal/scraper/amending_law/locator.ex
    lib/sertantai_legal/scraper/amending_law/operation.ex
    lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
    lib/sertantai_legal/scraper/amending_law/text.ex
    lib/sertantai_legal/scraper/amendment/catalogue_read.ex
    lib/sertantai_legal/scraper/amendment/law_doc.ex
    lib/sertantai_legal/scraper/amendment/patterns.ex
    lib/sertantai_legal/scraper/amendment/patterns/example.ex
    lib/sertantai_legal/scraper/amendment/reader.ex
    lib/sertantai_legal/scraper/amendment/reader/brackets.ex
    lib/sertantai_legal/scraper/amendment/reader/clauses.ex
    lib/sertantai_legal/scraper/amendment/reader/commencing.ex
    lib/sertantai_legal/scraper/amendment/reader/eu_citation.ex
    lib/sertantai_legal/scraper/amendment/reader/eu_spelling.ex
    lib/sertantai_legal/scraper/amendment/reader/law_named.ex
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
end
