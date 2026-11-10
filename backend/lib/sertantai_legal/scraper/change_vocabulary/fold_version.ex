defmodule SertantaiLegal.Scraper.ChangeVocabulary.FoldVersion do
  @moduledoc """
  The version of the code a switched law's label timeline depends on
  (#194, `SourceVersion`): the labels stage — the fold (`Fold`, `Label`),
  the switch's timeline from stored changes (`LabelSwitch`,
  `LabelSource`, `LabelPeriods`, `KnownLimits`) and the readers of the
  law's own text the fold shares with the build (`Readers.Markup`'s facts,
  `LawTerritory`); exactly the files the timeline's path reaches
  (`StageSplitTest`). Its boundaries are the stores: the changes it reads
  (`Store`, decoded by `Store.Codec`) are the build's output, fingerprinted
  by their digest, and the timeline's write (`LabelTimeline`) is storage.

  `LabelRefresh` records it on each switched law's `labels_refreshed`
  event, so labels folded by older code show as stale (`LabelStaleness`,
  `:fold_version`), while a fold-only edit leaves every built change
  current (`ChangeVocabulary.Version` holds none of these files but the
  shared ones).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/change_vocabulary/fold.ex
      lib/sertantai_legal/scraper/change_vocabulary/label.ex
      lib/sertantai_legal/scraper/change_vocabulary/label/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/label_periods.ex
      lib/sertantai_legal/scraper/change_vocabulary/label_source.ex
      lib/sertantai_legal/scraper/change_vocabulary/label_switch.ex
      lib/sertantai_legal/scraper/change_vocabulary/known_limits.ex
      lib/sertantai_legal/scraper/change_vocabulary/windsor.ex
      lib/sertantai_legal/scraper/change_vocabulary/change.ex
      lib/sertantai_legal/scraper/change_vocabulary/claim.ex
      lib/sertantai_legal/scraper/change_vocabulary/evidence.ex
      lib/sertantai_legal/scraper/change_vocabulary/ref.ex
      lib/sertantai_legal/scraper/change_vocabulary/store.ex
      lib/sertantai_legal/scraper/change_vocabulary/store/codec.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/markup/*.ex
      lib/sertantai_legal/scraper/change_vocabulary/readers/note_law.ex
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/*.ex
      lib/sertantai_legal/scraper/amending_law/pointer.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/change_digest.ex
      lib/sertantai_legal/scraper/effect_index.ex
      lib/sertantai_legal/scraper/effect_target.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/clause.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/law_territory.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/territory.ex
    ),
    deps: ~w(sweet_xml jason)

  @doc """
  The stores the labels stage reads from or writes to without depending on
  their code: the build's own staleness fingerprints and version (the
  changes come fingerprinted by their digest) and the timeline's write.
  """
  @spec boundaries() :: [String.t()]
  def boundaries,
    do: ~w(
      lib/sertantai_legal/scraper/change_vocabulary/store/inputs.ex
      lib/sertantai_legal/scraper/change_vocabulary/version.ex
      lib/sertantai_legal/scraper/label_timeline.ex
    )
end
