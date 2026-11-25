defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion do
  @moduledoc """
  The version of the code a law's stored extent rules depend on
  (`SourceVersion`), stamped on each `extent_rules` row (#193): the
  document reading (`ReadVersion.Document`, `Extent.Reader`'s reach) and
  the placement of an SI's powers and a silent Act's stated extent
  (`Extent.Powers`, `Extent.StatedExtent`), with the powers parser whose
  cached provisions they place (`EnablingCache.ParserVersion`) — what
  `Extent.Write` stores.
  Never the catalogue's own code (`ReadVersion.Catalogue`), the store,
  the cache or the step's tools, so an edit to those stales no reading;
  never the amendment reader. `ExtentReadStampsTest` holds it to exactly
  what `Extent.Reader` and `Extent.Powers` reach, and the parser's files (the Extent reader stamps
  session; before it, `extent/*.ex` by glob: any edit there staled every
  reading and every build).
  """

  alias __MODULE__.Document
  alias SertantaiLegal.Scraper.EnactedBy.EnablingCache.ParserVersion

  @placement ~w(
    lib/sertantai_legal/scraper/amending_law/extent/powers.ex
    lib/sertantai_legal/scraper/amending_law/extent/stated_extent.ex
  )

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: Document.patterns() ++ @placement ++ ParserVersion.patterns()

  @doc """
  Where a read path ends, for the coverage tests: the store, the write,
  the cache and the stamps themselves, which shape no reading.
  """
  @spec boundaries() :: [String.t()]
  def boundaries,
    do: ~w(
      lib/sertantai_legal/scraper/amending_law/extent/store.ex
      lib/sertantai_legal/scraper/amending_law/extent/write.ex
      lib/sertantai_legal/scraper/amending_law/extent/read_cache.ex
      lib/sertantai_legal/scraper/amending_law/extent/read_version.ex
      lib/sertantai_legal/scraper/amending_law/extent/read_version/document.ex
      lib/sertantai_legal/scraper/amending_law/extent/read_version/catalogue.ex
    )
end
