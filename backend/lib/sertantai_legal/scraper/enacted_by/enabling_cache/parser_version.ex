defmodule SertantaiLegal.Scraper.EnactedBy.EnablingCache.ParserVersion do
  @moduledoc """
  The version of the code an SI's cached enabling provisions depend on
  (`SourceVersion`): the introduction's parse (`EnactedBy.IntroductionXml`),
  the powers parser (`EnactedBy.EnablingProvisions`) and the cache that
  joins them to the register's titles (`EnactedBy.EnablingCache`). Each
  cache entry records it, so an entry parsed by older code is re-parsed
  from the introduction held, never fetched; `Extent.ReadVersion` holds
  its files, so the SIs' stored powers go stale with it (the Extent reader
  stamps session; until then the parser was in no stamp, and a change to
  it was found by a diff by hand). `ExtentReadStampsTest` holds it to
  exactly what those files reach.
  """

  @patterns ~w(
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_provisions.ex
    lib/sertantai_legal/scraper/enacted_by/introduction_xml.ex
  )

  @doc "The files this stamp lists, for the stamps that hold it (`Extent.ReadVersion`)."
  @spec patterns() :: [String.t()]
  def patterns, do: @patterns

  use SertantaiLegal.Scraper.SourceVersion, patterns: @patterns
end
