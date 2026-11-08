defmodule SertantaiLegal.Scraper.ChangeVocabulary.Version do
  @moduledoc """
  The version of the code the change register `provision_changes` depends
  on (CV-04, `SourceVersion`): the changes stage — the vocabulary, its
  readers, the merge, the evidence and the readers of the law text they
  use; exactly the files a build reaches (`StageSplitTest`, #194), so an
  edit to the label fold (`FoldVersion`), a measure or a step's check
  leaves stored changes current. Stamped on each stored change and on each
  `changes_built` lat_event, so changes built by older code show as stale.
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
      lib/sertantai_legal/scraper/amending_law/*.ex
      lib/sertantai_legal/scraper/amending_law/extent/*.ex
      lib/sertantai_legal/scraper/amendment/*.ex
      lib/sertantai_legal/scraper/amendment/reader/*.ex
      lib/sertantai_legal/scraper/commencement/*.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/law_territory.ex
      lib/sertantai_legal/scraper/territory.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/*.ex
      lib/sertantai_legal/scraper/change_digest.ex
      lib/sertantai_legal/scraper/effect_facts.ex
      lib/sertantai_legal/scraper/effect_index.ex
      lib/sertantai_legal/scraper/effect_kind.ex
      lib/sertantai_legal/scraper/effect_target.ex
      lib/sertantai_legal/scraper/effect_territory.ex
      lib/sertantai_legal/scraper/in_force_qualifier.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/change_collector/record.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
    ),
    # what no build reaches (`StageSplitTest`): the readers' checks and
    # catalogues, the read passes that store readings (stamped by their own
    # versions, #193) and the checks that draw samples (2026-11-05,
    # 2026-11-06, #194)
    except: ~w(
      lib/sertantai_legal/scraper/amending_law/sweep_form.ex
      lib/sertantai_legal/scraper/amending_law/extent/check.ex
      lib/sertantai_legal/scraper/amending_law/extent/withheld.ex
      lib/sertantai_legal/scraper/amendment/check_sample.ex
      lib/sertantai_legal/scraper/amendment/check_strata.ex
      lib/sertantai_legal/scraper/amendment/disagreement.ex
      lib/sertantai_legal/scraper/amendment/enacted_fetch.ex
      lib/sertantai_legal/scraper/amendment/pattern_source.ex
      lib/sertantai_legal/scraper/amendment/patterns.ex
      lib/sertantai_legal/scraper/amendment/read_pass.ex
      lib/sertantai_legal/scraper/amendment/read_report.ex
      lib/sertantai_legal/scraper/commencement/check.ex
      lib/sertantai_legal/scraper/commencement/family_leftovers.ex
      lib/sertantai_legal/scraper/commencement/leftovers.ex
      lib/sertantai_legal/scraper/commencement/order_patterns.ex
      lib/sertantai_legal/scraper/commencement/orders.ex
      lib/sertantai_legal/scraper/commencement/sentence_patterns.ex
    ),
    # the libraries that shape what is read (XML parsing, the stored
    # caches' JSON), not the whole mix.lock: another dependency's bump
    # leaves stored changes current (run time 2026-10-26)
    deps: ~w(sweet_xml jason)
end
