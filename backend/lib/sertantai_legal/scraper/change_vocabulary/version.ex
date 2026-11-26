defmodule SertantaiLegal.Scraper.ChangeVocabulary.Version do
  @moduledoc """
  The version of the code the change register `provision_changes` depends
  on (CV-04, `SourceVersion`): the changes stage — the vocabulary, its
  readers, the merge, the evidence and the readers of the law text they
  use; exactly the files a build reaches (`StageSplitTest`, #194), so an
  edit to the label fold (`FoldVersion`), a measure or a step's check
  leaves stored changes current. Stamped on each stored change and on each
  `changes_built` lat_event, so changes built by older code show as stale.
  Another stamp the build reaches (a reader's `ReadVersion`) is compared,
  never run, so it is left out: a reader's file list moves only its own
  stamp (`StageSplitTest`). Of the extent reader, only the struct and its
  lookups and the store's reads, by name: the build reads stored readings,
  never a law's text (the Extent reader stamps session). Of the
  Amending-law reader, only the rule, the store's reads and the index's
  (whether a stored reading is current), by name: the build reads stored
  rules, never an amending law's text (the Amending-law reader stamps
  session, 2026-11-26).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/change_vocabulary.ex
      lib/sertantai_legal/scraper/change_vocabulary/build.ex
      lib/sertantai_legal/scraper/change_vocabulary/change.ex
      lib/sertantai_legal/scraper/change_vocabulary/claim.ex
      lib/sertantai_legal/scraper/change_vocabulary/effect_verb.ex
      lib/sertantai_legal/scraper/change_vocabulary/evidence.ex
      lib/sertantai_legal/scraper/change_vocabulary/feed_savings.ex
      lib/sertantai_legal/scraper/change_vocabulary/feed_uris.ex
      lib/sertantai_legal/scraper/change_vocabulary/merge.ex
      lib/sertantai_legal/scraper/change_vocabulary/parts.ex
      lib/sertantai_legal/scraper/change_vocabulary/placement.ex
      lib/sertantai_legal/scraper/change_vocabulary/primary.ex
      lib/sertantai_legal/scraper/change_vocabulary/qualification.ex
      lib/sertantai_legal/scraper/change_vocabulary/ref.ex
      lib/sertantai_legal/scraper/change_vocabulary/store.ex
      lib/sertantai_legal/scraper/change_vocabulary/version.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/amending_law/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/merge/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/store/*.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/pointer.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/amending_law/extent/lookup.ex
      lib/sertantai_legal/scraper/amending_law/extent/change_target.ex
      lib/sertantai_legal/scraper/amending_law/extent/rows.ex
      lib/sertantai_legal/scraper/amending_law/extent/store.ex
      lib/sertantai_legal/scraper/amendment/index.ex
      lib/sertantai_legal/scraper/amendment/rule.ex
      lib/sertantai_legal/scraper/amendment/store.ex
      lib/sertantai_legal/scraper/commencement/*.ex
      lib/sertantai_legal/scraper/commencement/text/*.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/law_territory.ex
      lib/sertantai_legal/scraper/territory.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/**/*.ex
      lib/sertantai_legal/scraper/change_digest.ex
      lib/sertantai_legal/scraper/effect_facts.ex
      lib/sertantai_legal/scraper/effect_index.ex
      lib/sertantai_legal/scraper/effect_kind.ex
      lib/sertantai_legal/scraper/effect_target.ex
      lib/sertantai_legal/scraper/effect_territory.ex
      lib/sertantai_legal/scraper/in_force_qualifier.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
    ),
    # what no build reaches (`StageSplitTest`): the old collector and
    # dater (`OldPathFenceTest`), the readers' checks and catalogues, the read passes that store readings (stamped by their own
    # versions, #193) and the checks that draw samples (2026-11-05,
    # 2026-11-06, #194)
    except: ~w(
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/authority.ex
      lib/sertantai_legal/scraper/commencement/amending.ex
      lib/sertantai_legal/scraper/commencement/amending_picks.ex
      lib/sertantai_legal/scraper/commencement/amending_read.ex
      lib/sertantai_legal/scraper/commencement/check.ex
      lib/sertantai_legal/scraper/commencement/clml_rows.ex
      lib/sertantai_legal/scraper/commencement/family_leftovers.ex
      lib/sertantai_legal/scraper/commencement/held_amenders.ex
      lib/sertantai_legal/scraper/commencement/leftover_gate.ex
      lib/sertantai_legal/scraper/commencement/leftovers.ex
      lib/sertantai_legal/scraper/commencement/order_leftovers.ex
      lib/sertantai_legal/scraper/commencement/order/held_as.ex
      lib/sertantai_legal/scraper/commencement/order_read.ex
      lib/sertantai_legal/scraper/commencement/order_patterns.ex
      lib/sertantai_legal/scraper/commencement/orders.ex
      lib/sertantai_legal/scraper/commencement/own_read.ex
      lib/sertantai_legal/scraper/commencement/part_scope.ex
      lib/sertantai_legal/scraper/commencement/reach_groups.ex
      lib/sertantai_legal/scraper/commencement/sentence_patterns.ex
    ),
    # the libraries that shape what is read (XML parsing, the stored
    # caches' JSON), not the whole mix.lock: another dependency's bump
    # leaves stored changes current (run time 2026-10-26)
    deps: ~w(sweet_xml jason)
end
