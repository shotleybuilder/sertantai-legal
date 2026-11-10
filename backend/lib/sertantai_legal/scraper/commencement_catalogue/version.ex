defmodule SertantaiLegal.Scraper.CommencementCatalogue.Version do
  @moduledoc """
  The version of the code a law's commencement-catalogue reading depends
  on (`SourceVersion`, #195): the own-clause reader, the leftovers and the
  sentence patterns, the law reading that joins them
  (`CommencementCatalogue.LawRead`), the examples read alone (`LawScan`) and what they reach. The reading's
  `CatalogueCache` is keyed on it, so a change to any of them reads every
  law again; `VersionCoverageTest` holds it to every module its files
  reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/commencement/leftovers.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/order_patterns.ex
      lib/sertantai_legal/scraper/commencement/own_clause.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/sentence_patterns.ex
      lib/sertantai_legal/scraper/commencement_catalogue/law_read.ex
      lib/sertantai_legal/scraper/commencement_catalogue/law_scan.ex
      lib/sertantai_legal/scraper/commencement_catalogue/version.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/clause.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/provisions.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
