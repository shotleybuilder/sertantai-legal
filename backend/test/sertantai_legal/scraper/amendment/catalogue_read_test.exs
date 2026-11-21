defmodule SertantaiLegal.Scraper.Amendment.CatalogueReadTest do
  @moduledoc """
  An amending law's reading for the amendment catalogue, kept between runs
  (Catalogues Across the Workflow, 2026-11-21: the catalogue parsed every
  amending law every run).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{CatalogueRead, Reader}

  @clean_air Reader.law_ref("UK_ukpga_1956_52", "Clean Air Act", "s")

  defp doc,
    do:
      Doc.new("UK_ukpga_1968_62", [
        ~s|<Legislation><Primary><Body><P1 id="section-1"><P1para><Text>In this Act “<Term id="t">the principal Act</Term>” means the Clean Air Act 1956.</Text></P1para></P1><P1 id="section-5"><P1para><Text>In section 7 of the principal Act for "five" substitute "six".</Text></P1para></P1><P1 id="section-6"><P1para><Text>In section 8 of the principal Act for "one" substitute "two".</Text></P1para></P1></Body></Primary></Legislation>|
      ])

  test "each provision pointed to classed, in order; a pattern's example from its first provision only" do
    read =
      CatalogueRead.from_doc(
        doc(),
        %{"UK_ukpga_1956_52" => [{:section, "5", []}, {:section, "6", []}]},
        %{"UK_ukpga_1956_52" => @clean_air}
      )

    assert read.held

    assert [{"UK_ukpga_1956_52", "section-5", key}, {"UK_ukpga_1956_52", "section-6", key}] =
             read.units

    assert [^key] = Map.keys(read.examples)
  end

  @tag :tmp_dir
  test "a law not held is read once, then from the cache", %{tmp_dir: dir} do
    assert {%{held: false}, :read} =
             CatalogueRead.amending("UK_uksi_1800_99999", %{}, %{}, dir: dir)

    assert {%{held: false}, :hit} =
             CatalogueRead.amending("UK_uksi_1800_99999", %{}, %{}, dir: dir)
  end

  @tag :tmp_dir
  test "an amending law that raises leaves nothing in the cache", %{tmp_dir: dir} do
    # (a law in scope with no ref given: the reading cannot start)
    assert catch_error(
             CatalogueRead.amending("UK_uksi_1800_99999", %{"UK_x" => []}, %{}, dir: dir)
           )

    assert File.ls!(dir) == []
  end
end
