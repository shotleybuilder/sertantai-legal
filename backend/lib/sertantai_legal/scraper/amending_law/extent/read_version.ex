defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion do
  @moduledoc """
  The version of the code a law's extent reading depends on (`SourceVersion`):
  the extent reader, its catalogue classes (`Extent.Patterns`) and the
  document readers they use — never the amendment reader, so a change to it
  leaves `Extent.ReadCache` warm (run time 2026-10-26: the read pass re-read
  every law's extent after each reader change, 40% of a write pass).
  `VersionCoverageTest` holds it to every module its files reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/extent/*.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/*.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
