defmodule SertantaiLegal.Scraper.CommencementCatalogue.Version do
  @moduledoc """
  The version of the code a law's commencement-catalogue reading depends
  on (`SourceVersion`, #195): the own-clause reader, the leftovers, the
  misreads, the sentence patterns and the ref reader they share
  (`TextRefs`) — never the order reading, so an order fix keeps the cache — the law reading that joins them
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
      lib/sertantai_legal/scraper/amending_law/listed_places.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/doc_rows.ex
      lib/sertantai_legal/scraper/commencement/leftover_gate.ex
      lib/sertantai_legal/scraper/commencement/leftovers.ex
      lib/sertantai_legal/scraper/commencement/reach_groups.ex
      lib/sertantai_legal/scraper/commencement/review/misreads.ex
      lib/sertantai_legal/scraper/commencement/text/asides.ex
      lib/sertantai_legal/scraper/commencement/text/schedule_parts.ex
      lib/sertantai_legal/scraper/commencement/text/sibling.ex
      lib/sertantai_legal/scraper/commencement/own_clause.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/sentence_patterns.ex
      lib/sertantai_legal/scraper/commencement/text_refs.ex
      lib/sertantai_legal/scraper/commencement_catalogue/law_read.ex
      lib/sertantai_legal/scraper/commencement_catalogue/law_scan.ex
      lib/sertantai_legal/scraper/commencement_catalogue/merge_read.ex
      lib/sertantai_legal/scraper/commencement_catalogue/version.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/clause.ex
      lib/sertantai_legal/scraper/law_start/clause/named_days.ex
      lib/sertantai_legal/scraper/law_start/clause/relative_days.ex
      lib/sertantai_legal/scraper/law_start/clause/staged.ex
      lib/sertantai_legal/scraper/law_start/clause/tail.ex
      lib/sertantai_legal/scraper/law_start/clause/written_dates.ex
      lib/sertantai_legal/scraper/law_start/sentences.ex
      lib/sertantai_legal/scraper/law_start/completing.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/eu_words.ex
      lib/sertantai_legal/scraper/law_start/provisions.ex
      lib/sertantai_legal/scraper/law_start/provisions/clause_sentences.ex
      lib/sertantai_legal/scraper/law_start/provisions/countries.ex
      lib/sertantai_legal/scraper/law_start/provisions/exceptions.ex
      lib/sertantai_legal/scraper/law_start/provisions/mentioned.ex
      lib/sertantai_legal/scraper/law_start/provisions/open_items.ex
      lib/sertantai_legal/scraper/law_start/provisions/ref_lists.ex
      lib/sertantai_legal/scraper/law_start/provisions/refs.ex
      lib/sertantai_legal/scraper/law_start/provisions/rest.ex
      lib/sertantai_legal/scraper/law_start/provisions/sentence.ex
      lib/sertantai_legal/scraper/law_start/provisions/subjects.ex
      lib/sertantai_legal/scraper/law_start/provisions/tables.ex
      lib/sertantai_legal/scraper/law_start/provisions/treatment.ex
      lib/sertantai_legal/scraper/law_start/provisions/words.ex
      lib/sertantai_legal/scraper/law_start/list_items.ex
      lib/sertantai_legal/scraper/law_start/nested_items.ex
      lib/sertantai_legal/scraper/law_start/pointing_back.ex
      lib/sertantai_legal/scraper/law_start/number_words.ex
      lib/sertantai_legal/scraper/law_start/statements.ex
      lib/sertantai_legal/scraper/law_start/territorial.ex
      lib/sertantai_legal/scraper/law_start/that_day.ex
      lib/sertantai_legal/scraper/law_start/purpose_stages.ex
      lib/sertantai_legal/scraper/law_start/that_provision.ex
      lib/sertantai_legal/scraper/law_start/item_subject.ex
      lib/sertantai_legal/scraper/law_start/made_condition.ex
      lib/sertantai_legal/scraper/law_start/own_days.ex
      lib/sertantai_legal/scraper/law_start/laid_day.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
