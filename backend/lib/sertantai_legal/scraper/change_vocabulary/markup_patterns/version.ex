defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupPatterns.Version do
  @moduledoc """
  The version of the code a law's markup-catalogue scan depends on
  (`SourceVersion`, #195): the catalogue's classes (`MarkupPatterns`), the
  law scan and its read, the markup reader and what they reach.
  `MarkupPatterns.LawRead` keys its `CatalogueCache` on it, so a change to
  any of them scans every law again; `VersionCoverageTest` holds it to
  every module its files reach.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/extent/amends.ex
      lib/sertantai_legal/scraper/amending_law/extent/application.ex
      lib/sertantai_legal/scraper/amending_law/extent/applies.ex
      lib/sertantai_legal/scraper/amending_law/extent/asides.ex
      lib/sertantai_legal/scraper/amending_law/extent/change_target.ex
      lib/sertantai_legal/scraper/amending_law/extent/default.ex
      lib/sertantai_legal/scraper/amending_law/extent/excepted.ex
      lib/sertantai_legal/scraper/amending_law/extent/excepting.ex
      lib/sertantai_legal/scraper/amending_law/extent/exception_list.ex
      lib/sertantai_legal/scraper/amending_law/extent/forms.ex
      lib/sertantai_legal/scraper/amending_law/extent/item_exceptions.ex
      lib/sertantai_legal/scraper/amending_law/extent/list_items.ex
      lib/sertantai_legal/scraper/amending_law/extent/lists.ex
      lib/sertantai_legal/scraper/amending_law/extent/lookup.ex
      lib/sertantai_legal/scraper/amending_law/extent/makes_following.ex
      lib/sertantai_legal/scraper/amending_law/extent/named.ex
      lib/sertantai_legal/scraper/amending_law/extent/nested_locators.ex
      lib/sertantai_legal/scraper/amending_law/extent/own_paragraph.ex
      lib/sertantai_legal/scraper/amending_law/extent/part_lead.ex
      lib/sertantai_legal/scraper/amending_law/extent/parts.ex
      lib/sertantai_legal/scraper/amending_law/extent/places.ex
      lib/sertantai_legal/scraper/amending_law/extent/qualified_items.ex
      lib/sertantai_legal/scraper/amending_law/extent/rows.ex
      lib/sertantai_legal/scraper/amending_law/extent/same.ex
      lib/sertantai_legal/scraper/amending_law/extent/schedule_words.ex
      lib/sertantai_legal/scraper/amending_law/extent/statements.ex
      lib/sertantai_legal/scraper/amending_law/extent/targeted.ex
      lib/sertantai_legal/scraper/amending_law/extent/units.ex
      lib/sertantai_legal/scraper/amending_law/pointer.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/change_vocabulary/claim.ex
      lib/sertantai_legal/scraper/change_vocabulary/effect_verb.ex
      lib/sertantai_legal/scraper/change_vocabulary/feed_patterns.ex
      lib/sertantai_legal/scraper/change_vocabulary/markup_patterns.ex
      lib/sertantai_legal/scraper/change_vocabulary/markup_patterns/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_affecting.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_group.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_maker.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/feed_substituted_for.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/note_law.ex
      lib/sertantai_legal/scraper/change_vocabulary/ref.ex
      lib/sertantai_legal/scraper/commencement/evaluator.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
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
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
