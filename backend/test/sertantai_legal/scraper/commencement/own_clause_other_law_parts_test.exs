defmodule SertantaiLegal.Scraper.Commencement.OwnClauseOtherLawPartsTest do
  @moduledoc """
  Another law's provisions named in a commencement statement are never the
  law's own: another Act's Part ("Part 3 of the Regulatory Enforcement and
  Sanctions Act 2008": the Flood and Water Management Act 2010
  s.49(3)(f)), an Act whose title has an apostrophe ("sections 37 and 133
  of the Magistrates’ Courts Act 1980": the Criminal Justice Act 1988
  s.171(5)) and a Schedule to an Act named by its year ("Paragraph 24 of
  Schedule 22 to the 2020 Act": SI 2022/500 reg.4).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LawStart.Provisions

  defp rows(ids, parts),
    do:
      Enum.map(ids, &%{section_id: "UK_x:" <> &1, text: "", part: nil, chapter: nil}) ++
        Enum.map(parts, &%{section_id: "UK_x:s.9#{&1}", text: "", part: &1, chapter: nil})

  defp refs(text, ids, parts \\ []),
    do: Provisions.refs_in(text, rows(ids, parts), "UK_x:s.49")

  test "another Act's Part in a qualifier is not the law's own Part (2010 c.29 s.49(3)(f))" do
    assert refs(
             "section 37, so far as it relates to orders made by a Minister of the Crown under Part 3 of the Regulatory Enforcement and Sanctions Act 2008",
             ~w[s.37],
             ~w[3]
           ) == ~w[s.37]
  end

  test "the law's own Part stays its own" do
    assert refs("section 37 and Part 3", ~w[s.37], ~w[3]) == ~w[s.37 pt.3]
  end

  test "sections of an Act with an apostrophe in its title are that Act's (1988 c.33 s.171(5))" do
    assert refs(
             "sections 37 and 133 of the Magistrates’ Courts Act 1980",
             ~w[s.37 s.133]
           ) == []

    assert refs(
             "sections 171 and 368 of and Schedule 1 to the Criminal Procedure (Scotland) Act 1975",
             ~w[s.171 s.368 sch.1.para.1]
           ) == []
  end

  test "a Schedule to an Act named by its year is that Act's (SI 2022/500 reg.4)" do
    assert refs(
             "Paragraph 24 of Schedule 22 to the 2020 Act (amendments to the general limit on magistrates’ court’s power to impose imprisonment or detention in a young offender institution)",
             ~w[sch.22.para.24 reg.4]
           ) == []
  end

  test "a Schedule to this Act stays its own" do
    assert refs("paragraph 24 of Schedule 22 to this Act", ~w[sch.22.para.24]) ==
             ~w[sch.22.para.24]
  end
end
