defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion.Document do
  @moduledoc """
  The version of the code a law's document reading depends on
  (`SourceVersion`): `Extent.Reader.withheld/1`'s reach — the statements
  read, the catalogue's classes of the law's sentences and the bounds
  their unread ones withhold (`Patterns.classes/2`, `Extent.Unread`), and
  the document helpers they use. `Extent.ReadCache` is keyed on it, with
  the catalogue's own code (`ReadVersion.Catalogue`); the stored rules'
  stamp is `Extent.ReadVersion`, which holds it and the powers' placement.
  `ExtentReadStampsTest` holds it to exactly `Extent.Reader`'s reach (the
  Extent reader stamps session).
  """

  @patterns ~w(
    lib/sertantai_legal/scraper/amending_law/doc.ex
    lib/sertantai_legal/scraper/amending_law/doc/list_items.ex
    lib/sertantai_legal/scraper/amending_law/extent.ex
    lib/sertantai_legal/scraper/amending_law/extent/amended_excepted.ex
    lib/sertantai_legal/scraper/amending_law/extent/amends.ex
    lib/sertantai_legal/scraper/amending_law/extent/application.ex
    lib/sertantai_legal/scraper/amending_law/extent/applies.ex
    lib/sertantai_legal/scraper/amending_law/extent/asides.ex
    lib/sertantai_legal/scraper/amending_law/extent/change_target.ex
    lib/sertantai_legal/scraper/amending_law/extent/credit.ex
    lib/sertantai_legal/scraper/amending_law/extent/default.ex
    lib/sertantai_legal/scraper/amending_law/extent/excepted.ex
    lib/sertantai_legal/scraper/amending_law/extent/excepting.ex
    lib/sertantai_legal/scraper/amending_law/extent/exception_list.ex
    lib/sertantai_legal/scraper/amending_law/extent/forms.ex
    lib/sertantai_legal/scraper/amending_law/extent/item_exceptions.ex
    lib/sertantai_legal/scraper/amending_law/extent/list_items.ex
    lib/sertantai_legal/scraper/amending_law/extent/lists.ex
    lib/sertantai_legal/scraper/amending_law/extent/lookup.ex
    lib/sertantai_legal/scraper/amending_law/extent/makes_following.ex
    lib/sertantai_legal/scraper/amending_law/extent/named.ex
    lib/sertantai_legal/scraper/amending_law/extent/nested_locators.ex
    lib/sertantai_legal/scraper/amending_law/extent/own_paragraph.ex
    lib/sertantai_legal/scraper/amending_law/extent/part_lead.ex
    lib/sertantai_legal/scraper/amending_law/extent/parts.ex
    lib/sertantai_legal/scraper/amending_law/extent/patterns.ex
    lib/sertantai_legal/scraper/amending_law/extent/places.ex
    lib/sertantai_legal/scraper/amending_law/extent/qualified_items.ex
    lib/sertantai_legal/scraper/amending_law/extent/reader.ex
    lib/sertantai_legal/scraper/amending_law/extent/rows.ex
    lib/sertantai_legal/scraper/amending_law/extent/same.ex
    lib/sertantai_legal/scraper/amending_law/extent/same_exceptions.ex
    lib/sertantai_legal/scraper/amending_law/extent/schedule_rest.ex
    lib/sertantai_legal/scraper/amending_law/extent/schedule_words.ex
    lib/sertantai_legal/scraper/amending_law/extent/statements.ex
    lib/sertantai_legal/scraper/amending_law/extent/subdivisions.ex
    lib/sertantai_legal/scraper/amending_law/extent/targeted.ex
    lib/sertantai_legal/scraper/amending_law/extent/units.ex
    lib/sertantai_legal/scraper/amending_law/extent/unread.ex
    lib/sertantai_legal/scraper/amending_law/ref_list.ex
    lib/sertantai_legal/scraper/amending_law/schedule_refs.ex
    lib/sertantai_legal/scraper/amending_law/sub_path.ex
    lib/sertantai_legal/scraper/application_clause.ex
    lib/sertantai_legal/scraper/commencement/clml_ref.ex
    lib/sertantai_legal/scraper/lat_parser/xml.ex
    lib/sertantai_legal/scraper/law_start/sentences.ex
    lib/sertantai_legal/scraper/territory.ex
  )

  @doc "The files this stamp lists, for the stamps that hold it (`Extent.ReadVersion`)."
  @spec patterns() :: [String.t()]
  def patterns, do: @patterns

  use SertantaiLegal.Scraper.SourceVersion, patterns: @patterns
end
