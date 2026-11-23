defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion do
  @moduledoc """
  The version of the code a law's extent reading depends on (`SourceVersion`):
  the extent reader, its catalogue classes (`Extent.Patterns`) and the
  document readers they use — never the amendment reader, so a change to it
  leaves `Extent.ReadCache` warm (run time 2026-10-26: the read pass re-read
  every law's extent after each reader change, 40% of a write pass).
  `CommencementReadStampsTest` holds it to exactly what its files reach:
  none of the commencement readers, only the ref and sentence helpers they
  share (`ClmlRef`, `LawStart.Sentences`; the Commencement reader staleness
  session).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    # its own folder, and outside it each file it reaches, by name
    # (`CommencementReadStampsTest`: exactly its reach)
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/extent.ex
      lib/sertantai_legal/scraper/amending_law/extent/*.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
      lib/sertantai_legal/scraper/amending_law/ref_list.ex
      lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
      lib/sertantai_legal/scraper/amending_law/sub_path.ex
      lib/sertantai_legal/scraper/application_clause.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/law_start/sentences.ex
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
