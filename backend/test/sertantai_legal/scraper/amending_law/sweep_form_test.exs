defmodule SertantaiLegal.Scraper.AmendingLaw.SweepFormTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.SweepForm

  # the forms reviewed with Jason (CV-S05a, 2026-10-26), a real sentence each
  @cases [
    {"read:same_extent_of",
     "The extent of any amendment, repeal or revocation made by this Act is the same as that of the enactment amended, repealed or revoked."},
    {"read:same_extent",
     "An amendment, repeal or revocation made by this Act has the same extent in the United Kingdom as the enactment amended, repealed or revoked."},
    {"read:exception",
     "Subsection (1) does not apply to section 59(3), 90, 91, 100, 101, 102, 103, 104, 105, 106 or 109."},
    {"read:exception",
     "Subsection (3) does not apply to—a Part 5 of Schedule 13, or section 20 so far as relating to that Part;b section 26(2)."},
    {"read:also_there",
     "The amendment by this Act of any enactment extending to Northern Ireland also extends there."},
    {"read:lettered", "This Act extends only to—a England and Wales, andb Scotland."},
    {"read:application", "Regulation 44 applies to Scotland only."},
    {"read:application", "This paragraph applies in relation to England only."},
    {"read:application",
     "The following regulations do not apply in relation to Wales— a regulation 19; b regulation 30."},
    {"count:qualified",
     "Section 158 above extends—a to Scotland, so far as it relates to courts-martial; andb to Northern Ireland."},
    {"count:qualified",
     "This paragraph applies in Northern Ireland where—a a medicinal product has undergone the controls."},
    {"count:outside_gb",
     "These Regulations apply outside Great Britain as sections 1 to 59 and 80 to 82 of the Health and Safety at Work etc. Act 1974 apply."},
    {"noise:outside_uk",
     "Her Majesty may by Order in Council provide for any of the provisions of this Act to extend to the Isle of Man."},
    {"noise:instruction", "For subsection (2), as it extends to Northern Ireland, substitute—."},
    {"noise:modification",
     "Subsection (4) above has effect in relation to Wales as if the words from “and where” to the end were omitted."},
    {"noise:procedure",
     "Subsection (2) does not apply to regulations which apply only in relation to England."},
    {"noise:cases",
     "These Regulations do not apply to water which is intended for sale in bottles."},
    {"noise:commencement",
     "Subject to paragraph (3), these Regulations come into force on exit day."}
  ]

  test "each reviewed form" do
    for {form, s} <- @cases, do: assert(SweepForm.form(s) == form, "#{form}: #{s}")
  end

  test "read?/1: only a read form is a miss" do
    assert SweepForm.read?("read:application")
    refute SweepForm.read?("count:qualified")
    refute SweepForm.read?("noise:other")
  end
end
