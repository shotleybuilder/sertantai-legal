defmodule SertantaiLegal.Scraper.Amendment.ReaderVersion do
  @moduledoc """
  The version of the code an amending law's stored rules depend on
  (amendment-rules AR-04, `SourceVersion`): the reader, the rule, and the
  amending-law document readers it uses. The read pass records it in each
  amending law's index (`Amendment.Index`); rules read by older code are
  stale — the read pass re-reads them, and the collector reads the document
  instead until it does.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amendment/reader.ex
      lib/sertantai_legal/scraper/amendment/reader/*.ex
      lib/sertantai_legal/scraper/amendment/rule.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/amending_law/operation.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/locator.ex
      lib/sertantai_legal/scraper/amending_law/pointer.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
