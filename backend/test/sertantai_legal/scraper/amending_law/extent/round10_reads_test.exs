defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round10ReadsTest do
  @moduledoc """
  The extent reader's misread found by the round 9 agent check (seed 14)
  and the doubtful and side readings it noted, each on its law's real
  wording (CV-S05 round 10).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)

  defp p2s(id, texts),
    do:
      ~s|<P1 id="#{id}"><P1para>| <>
        Enum.map_join(texts, fn {n, t} ->
          ~s|<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{t}</Text></P2para></P2>|
        end) <> "</P1para></P1>"

  defp part(n, sections),
    do: ~s(<Part id="part-#{n}">#{Enum.map_join(sections, &p1("section-#{&1}", "Words."))}</Part>)

  test "NEW-1: a commencement's \"This Act, except— …\" is no extent; \"so far as it makes the following provision— …\" read (Police Reform Act 2002 s.108)" do
    e =
      read(
        "UK_ukpga_2002_30",
        part(1, [10]) <>
          part(5, 78..79) <>
          ~s(<Part id="part-7">) <>
          p1("section-82", "Words.") <>
          p2s("section-108", [
            {2,
             "This Act, except—a the provisions specified in subsection (3), andb the provisions to which subsections (4) and (5) apply, shall come into force on such day as the Secretary of State may by order appoint."},
            {6, "Subject to subsections (7) to (9), this Act extends to England and Wales only."},
            {7,
             "This Act extends to the United Kingdom so far as it makes the following provision—za the provision contained in paragraph 19F of Schedule 3 (and any interpretative or other supplementary provision as it has effect for the purposes of that provision);a the provision contained in Part 5;b the provision contained in section 82;c . . . . . .d the provision contained in section 103(6);e . . . . ."},
            {10,
             "The amendments and repeals made by this Act—a in section 96 of the Road Traffic Regulation Act 1984 (c. 27) (traffic wardens), do not extend to Scotland."}
          ]) <> "</Part>"
      )

    assert e.default == "E+W"

    assert {:named, "E+W+S+NI", ["sch.3.para.19F", "s.78", "s.79", "s.82", "s.103(6)"]} in e.lists

    assert Extent.of(e, "s.78") == "E+W+S+NI"
    assert Extent.of(e, "s.10") == "E+W"
  end

  test "\"Part 2 (…), excluding section 35 but including Schedules 1 to 9, extends to England and Wales only\" (Civil Partnership Act 2004 s.262(1))" do
    e =
      read(
        "UK_ukpga_2004_33",
        part(2, 34..36) <>
          ~s(<Part id="part-8">) <>
          p1(
            "section-262",
            "Part 2 (civil partnership: England and Wales), excluding section 35 but including Schedules 1 to 9, extends to England and Wales only."
          ) <> "</Part>"
      )

    assert {:only, "E+W", ["s.34", "s.36" | schedules]} =
             Enum.find(e.lists, &match?({:only, _, _}, &1))

    assert schedules == Enum.map(1..9, &"sch.#{&1}")
    assert Extent.of(e, "s.35") == nil
  end

  test "a lettered item's bare paragraph is the Schedule named before it (SI 2014/469 art.3(5)(d))" do
    e =
      read(
        "UK_uksi_2014_469",
        p1(
          "article-3",
          "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that—c the amendments made by paragraphs 182(2) and (4) of that Schedule apply in relation to England only;d the amendments made by paragraph 182(3) and (5) apply in relation to Wales only."
        )
      )

    assert {:applies, "W", ["sch.3.para.182(3)", "sch.3.para.182(5)"]} in e.applies
  end

  test "\"In section 31— (a) subsections (1) and (2) extend …\" (LRRA 2006 s.34(2))" do
    e =
      read(
        "UK_ukpga_2006_51",
        p1("section-31", "Words.") <>
          p2s("section-34", [
            {2,
             "In section 31—a subsections (1) and (2) extend to England and Wales only;b subsection (3) extends to Northern Ireland only."},
            {3,
             "The repeals in the Schedule have the same extent as the enactments to which they relate."}
          ])
      )

    assert {:only, "E+W", ["s.31(1)", "s.31(2)"]} in e.lists
    assert {:only, "NI", ["s.31(3)"]} in e.lists
  end
end
