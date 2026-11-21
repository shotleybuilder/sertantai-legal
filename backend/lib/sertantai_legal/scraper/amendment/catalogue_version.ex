defmodule SertantaiLegal.Scraper.Amendment.CatalogueVersion do
  @moduledoc """
  The version of the code an amending law's catalogue reading depends on
  (`SourceVersion`): the reading (`Amendment.CatalogueRead`), the
  catalogue's classes and examples (`Amendment.Patterns`), the reader they
  run and the document. `CatalogueRead` keys its `CatalogueCache` on it, so
  a change to any of them reads every amending law again; `VersionCoverageTest`
  holds it to every module its files reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amendment/catalogue_read.ex
      lib/sertantai_legal/scraper/amendment/catalogue_version.ex
      lib/sertantai_legal/scraper/amendment/patterns.ex
      lib/sertantai_legal/scraper/amendment/patterns/*.ex
      lib/sertantai_legal/scraper/amendment/law_doc.ex
      lib/sertantai_legal/scraper/amending_law/enacted.ex
      lib/sertantai_legal/scraper/amendment/reader.ex
      lib/sertantai_legal/scraper/amendment/reader/*.ex
      lib/sertantai_legal/scraper/amendment/rule.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/locator.ex
      lib/sertantai_legal/scraper/amending_law/operation.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
