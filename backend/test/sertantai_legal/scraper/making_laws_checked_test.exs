defmodule SertantaiLegal.Scraper.MakingLawsCheckedTest do
  @moduledoc """
  The checked laws of the Making laws step (Maritime Safety, 2026-11-04;
  Environmental Protection, 2026-11-08; Fire and OH&S, 2026-11-13): every live law of each family whose verdict a human review or fractalaw's
  DRRP enrichment decided, plus one wrong estimate found by reading the
  text. The classifier must agree with each, read from the local CLML
  store (`mix lat.making_laws --fetch` holds them). Frozen for the step.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore
  alias SertantaiLegal.Scraper.MakingLaws

  # the store is off in tests (config/test.exs): read the local one by name
  @root "data/cache/clml"

  # {law, verdict, decided by}
  @checked [
    {"UK_ukpga_1995_21", :making, :enrichment},
    {"UK_ukpga_1997_28", :making, :enrichment},
    {"UK_uksi_1997_2962", :making, :enrichment},
    {"UK_uksi_2002_1587", :making, :enrichment},
    {"UK_uksi_2006_2183", :making, :enrichment},
    {"UK_uksi_2006_2184", :making, :enrichment},
    {"UK_uksi_2007_3075", :making, :enrichment},
    {"UK_uksi_2007_3077", :making, :enrichment},
    {"UK_uksi_2007_3100", :making, :enrichment},
    {"UK_uksi_2008_2165", :not_making, :enrichment},
    {"UK_uksi_2008_2166", :not_making, :enrichment},
    {"UK_uksi_2010_330", :making, :enrichment},
    {"UK_uksi_2010_332", :making, :enrichment},
    {"UK_uksi_2016_1026", :making, :enrichment},
    {"UK_uksi_2023_787", :making, :enrichment},
    {"UK_uksi_2026_194", :making, :review},
    {"UK_uksi_2026_234", :not_making, :review},
    {"UK_uksi_2026_258", :not_making, :review},
    {"UK_uksi_2026_260", :not_making, :review},
    # its review said not making; corrected to making on its own duties
    # (reg. 5(1) "must ensure that every EPIRB … is registered"; Jason 2026-11-04)
    {"UK_uksi_2026_306", :making, :review},
    {"UK_uksi_2026_348", :not_making, :review},
    {"UK_uksi_2026_430", :making, :review},
    # amending only; its legacy duty types said making
    {"UK_uksi_2003_1636", :not_making, :law_text},
    # Environmental Protection (2026-11-08): the family's review and
    # enrichment verdicts
    {"UK_anaw_2016_3", :making, :enrichment},
    {"UK_asc_2023_2", :making, :enrichment},
    {"UK_asp_2005_15", :making, :enrichment},
    {"UK_asp_2024_13", :making, :enrichment},
    {"UK_asp_2026_6", :making, :review},
    {"UK_eudr_2004_35", :making, :enrichment},
    {"UK_eudr_2008_105", :making, :enrichment},
    {"UK_eudr_2011_92", :making, :enrichment},
    {"UK_eur_2012_649", :making, :enrichment},
    {"UK_nisr_2003_97", :making, :enrichment},
    {"UK_nisr_2006_321", :making, :enrichment},
    {"UK_nisr_2011_239", :making, :enrichment},
    {"UK_nisr_2011_240", :making, :enrichment},
    {"UK_ssi_1999_1", :making, :enrichment},
    {"UK_ssi_2004_520", :making, :enrichment},
    {"UK_ssi_2009_266", :making, :enrichment},
    {"UK_ssi_2014_4", :making, :enrichment},
    {"UK_ssi_2015_214", :not_making, :enrichment},
    {"UK_ssi_2015_383", :making, :enrichment},
    {"UK_ssi_2017_101", :making, :enrichment},
    {"UK_ssi_2018_219", :making, :enrichment},
    {"UK_ssi_2021_410", :making, :enrichment},
    {"UK_ssi_2026_145", :making, :review},
    {"UK_ssi_2026_165", :not_making, :review},
    {"UK_ssi_2026_172", :not_making, :review},
    {"UK_ssi_2026_75", :making, :review},
    {"UK_ukpga_1990_43", :making, :enrichment},
    {"UK_ukpga_1995_25", :making, :enrichment},
    {"UK_ukpga_2005_16", :making, :enrichment},
    {"UK_ukpga_2006_16", :making, :enrichment},
    {"UK_ukpga_2021_30", :making, :enrichment},
    {"UK_uksi_2003_1848", :making, :enrichment},
    {"UK_uksi_2004_1490", :making, :enrichment},
    {"UK_uksi_2004_1656", :making, :enrichment},
    {"UK_uksi_2005_1806", :making, :enrichment},
    {"UK_uksi_2006_2989", :making, :enrichment},
    {"UK_uksi_2008_663", :making, :enrichment},
    {"UK_uksi_2009_995", :making, :enrichment},
    {"UK_uksi_2010_1157", :making, :enrichment},
    {"UK_uksi_2010_1433", :making, :enrichment},
    {"UK_uksi_2011_696", :making, :review},
    {"UK_uksi_2015_168", :making, :enrichment},
    {"UK_uksi_2015_1947", :making, :enrichment},
    {"UK_uksi_2015_810", :making, :enrichment},
    {"UK_uksi_2016_1154", :making, :enrichment},
    {"UK_uksi_2017_1177", :not_making, :enrichment},
    {"UK_uksi_2018_1227", :not_making, :enrichment},
    {"UK_uksi_2018_800", :making, :enrichment},
    {"UK_uksi_2020_206", :making, :enrichment},
    {"UK_uksi_2020_594", :not_making, :enrichment},
    {"UK_uksi_2020_971", :making, :enrichment},
    {"UK_uksi_2021_1309", :not_making, :enrichment},
    {"UK_uksi_2023_982", :making, :enrichment},
    {"UK_wsi_2009_995", :making, :enrichment},
    {"UK_wsi_2010_1820", :not_making, :enrichment},
    {"UK_wsi_2010_1821", :making, :enrichment},
    {"UK_wsi_2012_1903", :making, :enrichment},
    {"UK_wsi_2026_103", :making, :review},
    {"UK_wsi_2026_105", :making, :review},
    {"UK_wsi_2026_21", :not_making, :review},
    {"UK_wsi_2026_71", :not_making, :review},
    # its review says making and holds (a designation, which the rule can't
    # see; Jason 2026-11-08, Decision 1): the text alone reads changes only
    {"UK_ssi_2026_57", :not_making, :law_text},
    # its enrichment said making; reviewed to not making on its text, the
    # modifications of EPA 1990 Part 2A only (Jason 2026-11-08, Decision 2)
    {"UK_uksi_2006_2988", :not_making, :review},
    # Fire and OH&S (2026-11-13): the round's review and enrichment verdicts
    {"UK_apni_1969_6", :making, :enrichment},
    {"UK_apni_1970_10", :making, :enrichment},
    {"UK_asp_2005_5", :making, :enrichment},
    {"UK_eudr_1999_92", :making, :enrichment},
    {"UK_eudr_2008_68", :making, :enrichment},
    {"UK_eudr_2014_34", :making, :enrichment},
    {"UK_nisi_1983_150", :making, :enrichment},
    {"UK_nisi_1992_1728", :making, :enrichment},
    {"UK_nisi_2006_1254", :making, :enrichment},
    {"UK_nisr_1991_509", :making, :enrichment},
    {"UK_nisr_1995_340", :making, :enrichment},
    {"UK_nisr_1995_345", :making, :enrichment},
    {"UK_nisr_1996_228", :making, :enrichment},
    {"UK_nisr_1996_262", :making, :enrichment},
    {"UK_nisr_1997_195", :making, :enrichment},
    {"UK_nisr_2003_152", :making, :enrichment},
    {"UK_nisr_2004_63", :making, :enrichment},
    {"UK_nisr_2006_204", :making, :enrichment},
    {"UK_nisr_2006_205", :making, :enrichment},
    {"UK_nisr_2006_425", :making, :enrichment},
    {"UK_nisr_2010_325", :making, :enrichment},
    {"UK_nisr_2010_59", :making, :enrichment},
    {"UK_nisr_2014_224", :making, :enrichment},
    {"UK_nisr_2016_266", :making, :enrichment},
    {"UK_nisr_2016_427", :making, :enrichment},
    {"UK_nisr_2017_90", :making, :enrichment},
    {"UK_ssi_2006_456", :making, :enrichment},
    {"UK_ukpga_1875_17", :making, :enrichment},
    {"UK_ukpga_1883_3", :making, :enrichment},
    {"UK_ukpga_1969_10", :making, :enrichment},
    {"UK_ukpga_1971_61", :making, :enrichment},
    {"UK_ukpga_1987_12", :making, :enrichment},
    {"UK_ukpga_1992_15", :making, :enrichment},
    {"UK_ukpga_1998_33", :making, :enrichment},
    {"UK_ukpga_2004_21", :making, :enrichment},
    {"UK_ukpga_2010_11", :making, :enrichment},
    {"UK_uksi_1989_1671", :making, :enrichment},
    {"UK_uksi_1989_635", :making, :enrichment},
    {"UK_uksi_1989_971", :making, :enrichment},
    {"UK_uksi_1990_304", :making, :enrichment},
    {"UK_uksi_1995_738", :making, :enrichment},
    {"UK_uksi_1995_743", :making, :enrichment},
    {"UK_uksi_1996_2535", :making, :enrichment},
    {"UK_uksi_1996_551", :making, :enrichment},
    {"UK_uksi_1996_913", :making, :enrichment},
    {"UK_uksi_1998_2451", :making, :enrichment},
    {"UK_uksi_1999_2024", :making, :enrichment},
    {"UK_uksi_2002_2665", :making, :enrichment},
    {"UK_uksi_2002_2776", :making, :enrichment},
    {"UK_uksi_2003_1082", :making, :enrichment},
    {"UK_uksi_2004_2304", :not_making, :enrichment},
    {"UK_uksi_2005_1541", :making, :enrichment},
    {"UK_uksi_2005_3117", :making, :enrichment},
    {"UK_uksi_2010_471", :making, :enrichment},
    {"UK_uksi_2014_1637", :making, :enrichment},
    {"UK_uksi_2014_1638", :making, :enrichment},
    {"UK_uksi_2014_1639", :making, :enrichment},
    {"UK_uksi_2014_3248", :making, :enrichment},
    {"UK_uksi_2015_1553", :making, :enrichment},
    {"UK_uksi_2015_385", :making, :enrichment},
    {"UK_uksi_2015_398", :making, :enrichment},
    {"UK_uksi_2015_966", :making, :enrichment},
    {"UK_uksi_2016_1107", :making, :enrichment},
    {"UK_uksi_2016_315", :not_making, :enrichment},
    {"UK_uksi_2016_588", :making, :enrichment},
    {"UK_uksi_2016_721", :making, :enrichment},
    {"UK_uksi_2018_139", :not_making, :enrichment},
    {"UK_uksi_2022_547", :making, :enrichment},
    {"UK_wsi_2012_1085", :making, :enrichment},
    {"UK_wsi_2026_64", :not_making, :review},
    # its review says making and holds (the Framework's effect, which the
    # rule can't see; Jason 2026-11-13, Decision 2): the text alone reads none
    {"UK_uksi_2012_1886", nil, :law_text},
    # its enrichment said empowering; reviewed to making on its live duties,
    # reg. 5A(1) "shall not advertise … unless" (Jason 2026-11-13, Decision 3)
    {"UK_nisr_2009_273", :making, :review},
    # its one "requirement" is an exemption ("a fire certificate shall not …
    # be required"); reviewed to not making (Jason 2026-11-13, Decision 4)
    {"UK_uksi_1989_76", :making, :law_text},
    # a saving read through its list items; an aside of two parts: not making
    {"UK_ssi_2006_475", :not_making, :law_text},
    {"UK_uksi_1974_2013", :not_making, :law_text},
    # a designation: an offshore safety zone established (Jason 2026-11-13,
    # Decision 1)
    {"UK_uksi_2014_1253", :making, :law_text},
    {"UK_uksi_2007_1017", :making, :law_text}
  ]

  for {law, verdict, by} <- @checked do
    test "#{law} is #{verdict} (#{by})" do
      law = unquote(law)
      result = MakingLaws.classify(Doc.new(law, ClmlStore.law_docs(law, root: @root)))
      assert result.verdict == unquote(verdict), "#{law}: #{result.reason}"
    end
  end
end
