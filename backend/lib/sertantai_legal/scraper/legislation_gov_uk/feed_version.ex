defmodule SertantaiLegal.Scraper.LegislationGovUk.FeedVersion do
  @moduledoc """
  The version of the code a law's parsed changes-feed effects depend on
  (`ChangesFeed` and what it reaches; `VersionCoverageTest`): the key of
  `FeedCache`, so effects parsed by older code are parsed again.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
    )
end
