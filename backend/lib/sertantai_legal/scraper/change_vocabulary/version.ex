defmodule SertantaiLegal.Scraper.ChangeVocabulary.Version do
  @moduledoc """
  The version of the code the change register `provision_changes` depends
  on (CV-04, `SourceVersion`): the vocabulary, its readers and the
  readers of the law text they use — every module they reach that shapes
  what they read (`VersionCoverageTest`; the LawStart readers were missing
  until 2026-10-25). Stamped on each stored change and on
  each `changes_built` lat_event, so changes built by older code show as
  stale.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/change_vocabulary.ex
      lib/sertantai_legal/scraper/change_vocabulary/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/*.ex
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
    # the libraries that shape what is read (XML parsing, the stored
    # caches' JSON), not the whole mix.lock: another dependency's bump
    # leaves stored changes current (run time 2026-10-26)
    deps: ~w(sweet_xml jason)
end
