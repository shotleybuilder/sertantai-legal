defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion.Catalogue do
  @moduledoc """
  The version of the extent catalogue's own code (`SourceVersion`): the
  example and pattern keys (`Patterns.Example`) and the sweep of sentences
  the catalogue misses (`Extent.Sweep`) — what `Extent.ReadCache` keeps
  beside the reading and no stored rule depends on. The cache is keyed on
  it and `ReadVersion.Document`, so an edit here cools the cache and stales
  nothing stored. `ExtentReadStampsTest`: these files and the document
  reading are exactly what they reach (the Extent reader stamps session).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/extent/patterns/example.ex
      lib/sertantai_legal/scraper/amending_law/extent/sweep.ex
    )
end
