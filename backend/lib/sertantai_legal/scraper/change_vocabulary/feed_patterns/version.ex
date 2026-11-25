defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns.Version do
  @moduledoc """
  The version of the code a law's feed-catalogue scan depends on
  (`SourceVersion`, #195): the catalogue's classes (`FeedPatterns`), the
  law scan and its read, the feed reader and what they reach.
  `FeedPatterns.LawRead` keys its `CatalogueCache` on it, so a change to
  any of them scans every law again; `VersionCoverageTest` holds it to
  every module its files reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/extent/change_target.ex
      lib/sertantai_legal/scraper/amending_law/extent/lookup.ex
      lib/sertantai_legal/scraper/amending_law/extent/rows.ex
      lib/sertantai_legal/scraper/amending_law/pointer.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/change_vocabulary/claim.ex
      lib/sertantai_legal/scraper/change_vocabulary/effect_verb.ex
      lib/sertantai_legal/scraper/change_vocabulary/feed_patterns.ex
      lib/sertantai_legal/scraper/change_vocabulary/feed_patterns/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting_siblings.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting_span.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_annex.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_group.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_maker.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_paragraph.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_part.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_range.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_for.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_removed.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/note_law.ex
      lib/sertantai_legal/scraper/change_vocabulary/ref.ex
      lib/sertantai_legal/scraper/commencement/evaluator.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/authority.ex
      lib/sertantai_legal/scraper/commencement/text_refs.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/order/*.ex
      lib/sertantai_legal/scraper/commencement/text/*.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/ref_context.ex
      lib/sertantai_legal/scraper/effect_facts.ex
      lib/sertantai_legal/scraper/effect_index.ex
      lib/sertantai_legal/scraper/effect_kind.ex
      lib/sertantai_legal/scraper/effect_target.ex
      lib/sertantai_legal/scraper/effect_territory.ex
      lib/sertantai_legal/scraper/in_force_qualifier.ex
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
      lib/sertantai_legal/scraper/law_start/made_condition.ex
      lib/sertantai_legal/scraper/law_start/own_days.ex
      lib/sertantai_legal/scraper/law_start/laid_day.ex
      lib/sertantai_legal/scraper/law_start/purpose_stages.ex
      lib/sertantai_legal/scraper/law_start/that_provision.ex
      lib/sertantai_legal/scraper/law_start/item_subject.ex
      lib/sertantai_legal/scraper/law_start/pointing_back.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/eu_words.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/feed_cache.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/feed_version.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
