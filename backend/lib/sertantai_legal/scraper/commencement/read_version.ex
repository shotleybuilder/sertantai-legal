defmodule SertantaiLegal.Scraper.Commencement.ReadVersion do
  @moduledoc """
  The version of the code a stored commencement reading depends on
  (`SourceVersion`, #193): the commencement readers (own clause, orders,
  feed effects, schedule effects), the rule and its store, and what they
  reach. `Commencement.Store` stamps it on each row it writes
  (`commencement_rules.reader_version`), so a build that read rules made by
  older reader code shows as stale (`ChangeStaleness`, `:commencement_reader`)
  instead of looking current after a rebuild. `VersionCoverageTest` holds it
  to every module its files reach.

  Not covered: the input glue in `mix lat.commencement` (which laws, the
  law's rows and `LawStart` input), a known limit; the rows themselves are
  the build's own `:lat_rows` input.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/commencement/*.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/*.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/territory.ex
    ),
    # the step's checks and catalogues: they read the rules, never shape them
    except: ~w(
      lib/sertantai_legal/scraper/commencement/check.ex
      lib/sertantai_legal/scraper/commencement/leftovers.ex
      lib/sertantai_legal/scraper/commencement/family_leftovers.ex
      lib/sertantai_legal/scraper/commencement/order_patterns.ex
      lib/sertantai_legal/scraper/commencement/sentence_patterns.ex
    )
end
