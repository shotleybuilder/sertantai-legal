defmodule SertantaiLegal.Scraper.Commencement.Order.HeldAsTest do
  @moduledoc """
  An order is read only from its own document (LAT Change Pipeline, step
  Commencement reader). legislation.gov.uk answers a request for the UK SI
  2005/423 with the Welsh SI 2005/423 (the Countryside and Rights of Way
  Act 2000 (Commencement No. 6) (Wales) Order 2005), so the store holds the
  Welsh order under both names. Read as the UK SI, it gave the CROW Act's
  rules a second source, `UK_uksi_2005_423`, and the extended golden's RTRA
  1984 s.1A(b), s.1(6B) a commencing law that does not exist.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Order.HeldAs

  defp xml(type),
    do:
      ~s(<Legislation xmlns:ukm="http://www.legislation.gov.uk/namespaces/metadata"><ukm:Metadata><ukm:SecondaryMetadata><ukm:DocumentClassification><ukm:DocumentMainType Value="#{type}"/></ukm:DocumentClassification></ukm:SecondaryMetadata></ukm:Metadata></Legislation>)

  test "the Welsh order held under the UK SI's name is not the UK SI (SI 2005/423)" do
    refute HeldAs.itself?("UK_uksi_2005_423", xml("WelshStatutoryInstrument"))
    assert HeldAs.itself?("UK_wsi_2005_423", xml("WelshStatutoryInstrument"))
  end

  test "each instrument type is held as itself" do
    assert HeldAs.itself?("UK_uksi_2010_2169", xml("UnitedKingdomStatutoryInstrument"))
    assert HeldAs.itself?("UK_ssi_2003_206", xml("ScottishStatutoryInstrument"))
    assert HeldAs.itself?("UK_nisr_2016_332", xml("NorthernIrelandStatutoryRule"))
    refute HeldAs.itself?("UK_ssi_2003_206", xml("UnitedKingdomStatutoryInstrument"))
  end

  test "a type it does not know, or no type stated, is never refused" do
    assert HeldAs.itself?("UK_uksro_1946_100", xml("UnitedKingdomStatutoryRuleOrOrder"))
    assert HeldAs.itself?("UK_uksi_2010_2169", "<Legislation/>")
  end
end
