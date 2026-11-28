defmodule SertantaiLegal.Scraper.Commencement.ReadVersion.Orders do
  @moduledoc """
  The version of the code one commencement read path depends on
  (`SourceVersion`): the commencement orders' text (`OrderRead`): `order_date`, `order_schedule`. Exactly the files its entry (`order_read.ex`)
  reaches, to the store (`CommencementReadStampsTest`), listed by name, never
  by folder, so a fix to another read path, or a tool module added beside
  it, leaves its rules current (the Commencement reader staleness session).
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/amending_law/defined_terms.ex
      lib/sertantai_legal/scraper/amending_law/doc.ex
      lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
      lib/sertantai_legal/scraper/amending_law/text.ex
      lib/sertantai_legal/scraper/amending_law/listed_places.ex
      lib/sertantai_legal/scraper/commencement/authority.ex
      lib/sertantai_legal/scraper/commencement/clml_ref.ex
      lib/sertantai_legal/scraper/commencement/order.ex
      lib/sertantai_legal/scraper/commencement/order/appointed_for.ex
      lib/sertantai_legal/scraper/commencement/order/brackets.ex
      lib/sertantai_legal/scraper/commencement/order/dates.ex
      lib/sertantai_legal/scraper/commencement/order/entries.ex
      lib/sertantai_legal/scraper/commencement/order/held_as.ex
      lib/sertantai_legal/scraper/commencement/order/identity.ex
      lib/sertantai_legal/scraper/commencement/order/items.ex
      lib/sertantai_legal/scraper/commencement/order/last_item_limit.ex
      lib/sertantai_legal/scraper/commencement/order/other_law.ex
      lib/sertantai_legal/scraper/commencement/order/purposes.ex
      lib/sertantai_legal/scraper/commencement/order/related_list.ex
      lib/sertantai_legal/scraper/commencement/order/repeal_lists.ex
      lib/sertantai_legal/scraper/commencement/order/schedule_date.ex
      lib/sertantai_legal/scraper/commencement/order/schedule_lists.ex
      lib/sertantai_legal/scraper/commencement/order/schedule_tables.ex
      lib/sertantai_legal/scraper/commencement/order/section_heads.ex
      lib/sertantai_legal/scraper/commencement/order/statements.ex
      lib/sertantai_legal/scraper/commencement/order/territory.ex
      lib/sertantai_legal/scraper/commencement/order/whole_act.ex
      lib/sertantai_legal/scraper/commencement/order/words.ex
      lib/sertantai_legal/scraper/commencement/order_read.ex
      lib/sertantai_legal/scraper/commencement/ref_context.ex
      lib/sertantai_legal/scraper/commencement/rule.ex
      lib/sertantai_legal/scraper/commencement/text/asides.ex
      lib/sertantai_legal/scraper/commencement/text/schedule_parts.ex
      lib/sertantai_legal/scraper/commencement/text/sibling.ex
      lib/sertantai_legal/scraper/commencement/text_refs.ex
      lib/sertantai_legal/scraper/lat_parser/xml.ex
      lib/sertantai_legal/scraper/lat_ref.ex
      lib/sertantai_legal/scraper/law_start.ex
      lib/sertantai_legal/scraper/law_start/clause.ex
      lib/sertantai_legal/scraper/law_start/clause/named_days.ex
      lib/sertantai_legal/scraper/law_start/clause/relative_days.ex
      lib/sertantai_legal/scraper/law_start/clause/staged.ex
      lib/sertantai_legal/scraper/law_start/clause/tail.ex
      lib/sertantai_legal/scraper/law_start/clause/written_dates.ex
      lib/sertantai_legal/scraper/law_start/eu.ex
      lib/sertantai_legal/scraper/law_start/made_condition.ex
      lib/sertantai_legal/scraper/law_start/own_days.ex
      lib/sertantai_legal/scraper/law_start/purpose_stages.ex
      lib/sertantai_legal/scraper/law_start/schedule_table.ex
      lib/sertantai_legal/scraper/law_start/sentences.ex
      lib/sertantai_legal/scraper/territory.ex
    )
end
