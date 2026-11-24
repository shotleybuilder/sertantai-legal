defmodule SertantaiLegal.Scraper.Commencement.ReadVersion.Clause do
  @moduledoc """
  The version of the code one commencement read path depends on
  (`SourceVersion`): own and amending laws' commencement clauses (`OwnRead`, `AmendingRead`): every treatment but the orders' and the feed's. Exactly the files its entry (`own_read.ex`, `amending_read.ex`)
  reaches, to the store (`CommencementReadStampsTest`), listed by name, never
  by folder, so a fix to another read path, or a tool module added beside
  it, leaves its rules current (the Commencement reader staleness session).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
      lib/sertantai_legal/scraper/commencement/amending_read.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/doc_rows.ex
      lib/sertantai_legal/scraper/commencement/effects.ex
      lib/sertantai_legal/scraper/commencement/evaluator.ex
      lib/sertantai_legal/scraper/commencement/own_clause.ex
      lib/sertantai_legal/scraper/commencement/own_read.ex
      lib/sertantai_legal/scraper/commencement/part_scope.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/schedule_effect.ex
      lib/sertantai_legal/scraper/commencement/text/asides.ex
      lib/sertantai_legal/scraper/commencement/text/schedule_parts.ex
      lib/sertantai_legal/scraper/commencement/text/sibling.ex
      lib/sertantai_legal/scraper/commencement/text_refs.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/lat_scope.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/clause.ex
      lib/sertantai_legal/scraper/law_start/clause/named_days.ex
      lib/sertantai_legal/scraper/law_start/clause/relative_days.ex
      lib/sertantai_legal/scraper/law_start/clause/staged.ex
      lib/sertantai_legal/scraper/law_start/clause/tail.ex
      lib/sertantai_legal/scraper/law_start/clause/written_dates.ex
      lib/sertantai_legal/scraper/law_start/completing.ex
      lib/sertantai_legal/scraper/law_start/date_of_enactment.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/eu_words.ex
      lib/sertantai_legal/scraper/law_start/input.ex
      lib/sertantai_legal/scraper/law_start/item_subject.ex
      lib/sertantai_legal/scraper/law_start/laid_day.ex
      lib/sertantai_legal/scraper/law_start/list_items.ex
      lib/sertantai_legal/scraper/law_start/made_condition.ex
      lib/sertantai_legal/scraper/law_start/nested_items.ex
      lib/sertantai_legal/scraper/law_start/number_words.ex
      lib/sertantai_legal/scraper/law_start/own_days.ex
      lib/sertantai_legal/scraper/law_start/pointing_back.ex
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
      lib/sertantai_legal/scraper/law_start/purpose_stages.ex
      lib/sertantai_legal/scraper/law_start/schedule_clause.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/law_start/sentences.ex
      lib/sertantai_legal/scraper/law_start/statements.ex
      lib/sertantai_legal/scraper/law_start/territorial.ex
      lib/sertantai_legal/scraper/law_start/that_day.ex
      lib/sertantai_legal/scraper/law_start/that_provision.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
