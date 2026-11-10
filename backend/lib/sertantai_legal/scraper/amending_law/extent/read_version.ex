defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion do
  @moduledoc """
  The version of the code a law's extent reading depends on (`SourceVersion`):
  the extent reader, its catalogue classes (`Extent.Patterns`) and the
  document readers they use — never the amendment reader, so a change to it
  leaves `Extent.ReadCache` warm (run time 2026-10-26: the read pass re-read
  every law's extent after each reader change, 40% of a write pass).
  `VersionCoverageTest` holds it to every module its files reach: the
  commencement effects, evaluator, `LatRef` and the changes feed since
  `LawStart.Input` (2026-11-07, #192).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/extent/*.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/effects.ex
      lib/sertantai_legal/scraper/commencement/evaluator.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/*.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/territory.ex
    ),
    # the step's check (its tallies reach the change vocabulary's measures)
    # and its family gate (the commencement gate's statuses), never what an
    # extent reading depends on
    except: ~w(
      lib/sertantai_legal/scraper/amending_law/extent/check.ex
      lib/sertantai_legal/scraper/amending_law/extent/withheld.ex
    )
end
