defmodule SertantaiLegal.Scraper.MakingLawsCheckedTest do
  @moduledoc """
  The checked laws of the Making laws step (Maritime Safety, 2026-11-04):
  every live law of the family whose verdict a human review or fractalaw's
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
    {"UK_uksi_2026_306", :not_making, :review},
    {"UK_uksi_2026_348", :not_making, :review},
    {"UK_uksi_2026_430", :making, :review},
    # amending only; its legacy duty types said making
    {"UK_uksi_2003_1636", :not_making, :law_text}
  ]

  # its review says not making; its text: "must ensure that every EPIRB …
  # is registered" (reg. 5(1)) — Jason decides (session, Decision 1)
  @to_decide ["UK_uksi_2026_306"]

  for {law, verdict, by} <- @checked do
    if law in @to_decide, do: @tag(:pending)

    test "#{law} is #{verdict} (#{by})" do
      law = unquote(law)
      result = MakingLaws.classify(Doc.new(law, ClmlStore.law_docs(law, root: @root)))
      assert result.verdict == unquote(verdict), "#{law}: #{result.reason}"
    end
  end
end
