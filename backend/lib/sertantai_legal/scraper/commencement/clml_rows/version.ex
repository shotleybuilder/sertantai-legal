defmodule SertantaiLegal.Scraper.Commencement.ClmlRows.Version do
  @moduledoc """
  The version of the code a law's CLML rows depend on (`SourceVersion`):
  the rows (`DocRows`), the id reader (`ClmlRef`), the document and what
  they reach. `ClmlRows` keys its cache on it, so a reader fix — an order,
  an own clause or a sentence — keeps every law's rows; `VersionCoverageTest`
  holds it to every module its files reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/clml_rows.ex
      lib/sertantai_legal/scraper/commencement/clml_rows/version.ex
      lib/sertantai_legal/scraper/commencement/doc_rows.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
