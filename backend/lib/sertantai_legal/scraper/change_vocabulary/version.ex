defmodule SertantaiLegal.Scraper.ChangeVocabulary.Version do
  @moduledoc """
  The version of the code the change register `provision_changes` depends
  on (CV-04, `SourceVersion`): the vocabulary, its readers and the
  readers of the law text they use. Stamped on each stored change and on
  each `changes_built` lat_event, so changes built by older code show as
  stale.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/change_vocabulary.ex
      lib/sertantai_legal/scraper/change_vocabulary/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/*.ex
      lib/sertantai_legal/scraper/amending_law/*.ex
      lib/sertantai_legal/scraper/amending_law/extent/*.ex
      lib/sertantai_legal/scraper/amendment/*.ex
      lib/sertantai_legal/scraper/commencement/*.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/law_territory.ex
      lib/sertantai_legal/scraper/territory.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      mix.lock
    )
end
