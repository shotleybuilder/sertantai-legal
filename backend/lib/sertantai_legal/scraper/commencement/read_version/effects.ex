defmodule SertantaiLegal.Scraper.Commencement.ReadVersion.Effects do
  @moduledoc """
  The version of the code one commencement read path depends on
  (`SourceVersion`): the feed's coming-into-force effects (`Effects`): `feed_commencement`. Exactly the files its entry (`effects.ex`)
  reaches, to the store (`CommencementReadStampsTest`), listed by name, never
  by folder, so a fix to another read path, or a tool module added beside
  it, leaves its rules current (the Commencement reader staleness session).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/effects.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
    )
end
