defmodule SertantaiLegal.Scraper.LabelVersion do
  @moduledoc """
  The version of the code a law's change register and label timeline depend
  on (lat-refactor LR-25, `SourceVersion`): the collectors, the amending-law
  readers, the commencement ruleset (its readers and evaluator) and the
  projection. Each `labels_refreshed` lat_event records it,
  so a law whose labels were built by older code shows as stale (`mix
  lat.stale`) and `mix lat.relabel` rebuilds it without a re-parse. The
  parse's own code is `ParserVersion`.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/change_collector.ex
      lib/sertantai_legal/scraper/change_collector/*.ex
      lib/sertantai_legal/scraper/amending_law/*.ex
      lib/sertantai_legal/scraper/amendment/*.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/*.ex
      lib/sertantai_legal/scraper/commencement/*.ex
      lib/sertantai_legal/scraper/effect_facts.ex
      lib/sertantai_legal/scraper/effect_kind.ex
      lib/sertantai_legal/scraper/label_projection.ex
      lib/sertantai_legal/scraper/label_timeline.ex
      lib/sertantai_legal/scraper/label_refresh.ex
      mix.lock
    )
end
