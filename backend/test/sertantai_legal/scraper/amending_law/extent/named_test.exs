defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.NamedTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Named, Units}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  defp p2s(id, subs),
    do:
      ~s(<P1 id="#{id}">) <>
        Enum.map_join(subs, fn {n, text} ->
          ~s(<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{text}</Text></P2para></P2>)
        end) <> "</P1>"

  defp named(law, text) do
    doc = ExtentDoc.doc(law, ExtentDoc.p1("section-9", text))
    Named.named(Units.unit_sentences(doc), doc)
  end

  test "named provisions' own extent: also, only, not, named" do
    assert named(
             "UK_ukpga_1999_22",
             "This Act extends to England and Wales. Sections 32 to 34 and 73(2) extend to Scotland. Section 74 extends to Northern Ireland only. Sections 17 and 27 do not extend to Wales."
           ) == [
             {:named, "S", ["s.32..s.34", "s.73(2)"]},
             {:only, "NI", ["s.74"]},
             {:not, "W", ["s.17", "s.27"]}
           ]
  end

  test "never another law's, a mention, a qualified or excepted extent" do
    for text <- [
          "Sections 128(4) and 132(3) of that Act shall continue to extend to Scotland.",
          "Sections 1 and 2 above, and Schedule 1 to this Act (except paragraph 12), shall not extend to Northern Ireland."
        ] do
      assert named("UK_ukpga_2000_1", text) == [], text
    end
  end

  test "a statement qualified after its places is withheld, never dropped (CV-S05 seed 22)" do
    assert named(
             "UK_ukpga_2000_1",
             "Section 1(2) and Schedule 1 extend to Northern Ireland so far as they amend the House of Commons Disqualification Act 1975."
           ) == [{:unread, nil, ["s.1(2)", "sch.1"]}]
  end

  test "never a provision named in a bracketed description (NEW-C)" do
    assert named(
             "UK_ukpga_2013_32",
             "Paragraph 25 (amendment to section 24A of the Nuclear Installations Act 1965 as it has effect in England and Wales and Scotland) extends to England and Wales and Scotland only."
           ) == []

    assert named("UK_ukpga_2013_32", "Section 73(2) (powers) extends to Scotland only.") ==
             [{:only, "S", ["s.73(2)"]}]
  end

  test "a Chapter of this Part (NEW-A)" do
    p1 = &ExtentDoc.p1/2

    doc =
      ExtentDoc.doc(
        "UK_ukpga_2015_15",
        ~s(<Part id="part-3"><Chapter id="part-3-chapter-3">#{p1.("section-83", "One.")}#{p1.("section-84", "Two.")}</Chapter><Chapter id="part-3-chapter-4">#{p1.("section-99", "Chapter 3 of this Part extends only to England and Wales.")}</Chapter></Part>)
      )

    assert Named.named(Units.unit_sentences(doc), doc) == [{:only, "E+W", ["s.83", "s.84"]}]
  end

  test "the kind: not, only, also, else named" do
    assert Named.named_kind(%{
             "not" => "",
             "only" => "only ",
             "only2" => "",
             "also" => "",
             "also2" => ""
           }) ==
             :only

    assert Named.named_kind(%{
             "not" => "",
             "only" => "",
             "only2" => "",
             "also" => "",
             "also2" => ""
           }) ==
             :named
  end

  describe "named statements read whole" do
    test "the saving in \"The repeal by this Act of … and the corresponding saving in paragraph 2 of Schedule 2 …\" (ukpga 1980/58 s.41)" do
      e =
        read(
          "UK_ukpga_1980_58",
          p1(
            "section-41",
            "The repeal by this Act of section 14(1) of the Limitation Act 1963 and the corresponding saving in paragraph 2 of Schedule 2 to this Act shall extend to Northern Ireland, but otherwise this Act does not extend to Scotland or to Northern Ireland."
          )
        )

      assert {"NI", ["sch.2.para.2"]} in rows(e, :named)
    end

    test "\"extends to other parts of the United Kingdom\" (ukpga 1978/29 s.110)" do
      e =
        read(
          "UK_ukpga_1978_29",
          p1(
            "section-110",
            "Paragraph 3 of Schedule 10 extends to other parts of the United Kingdom."
          )
        )

      assert {"E+W+S+NI", ["sch.10.para.3"]} in rows(e, :named)
    end

    test "\"… and those in Part III of Schedule 1 to Scotland only\" (ukpga 1990/11 s.7)" do
      e =
        read(
          "UK_ukpga_1990_11",
          p1(
            "section-7",
            "The repeals in Part II of Schedule 1 extend to England and Wales only and those in Part III of Schedule 1 to Scotland only."
          )
        )

      assert {"E+W", ["sch.1.pt.II"]} in rows(e, :only)
      assert {"S", ["sch.1.pt.III"]} in rows(e, :only)
    end

    test "\"Subsections (5) to (7) above shall not extend to Scotland\" (ukpga 1987/43 s.5(8))" do
      e =
        read(
          "UK_ukpga_1987_43",
          p2s("section-5", [
            {"5", "Words."},
            {"8", "Subsections (5) to (7) above shall not extend to Scotland."}
          ])
        )

      assert {"S", ["s.5(5)", "s.5(6)", "s.5(7)"]} in rows(e, :not)
    end

    test "\"… and subsection (2) of that section extends to Scotland only\" (ukpga 2009/26 s.115)" do
      e =
        read(
          "UK_ukpga_2009_26",
          p1(
            "section-115",
            "Subsections (1) and (3) to (5) of section 105 extend to Scotland and Northern Ireland and subsection (2) of that section extends to Scotland only."
          )
        )

      assert {"S", ["s.105(2)"]} in rows(e, :only)
      assert "s.105(3)" in refs(e, :named, "S+NI")
    end

    test "\"subsections (1) to (4) of this section shall be construed … do not extend to Northern Ireland\" is no statement (ukpga 1963/11 s.22)" do
      e =
        read(
          "UK_ukpga_1963_11",
          p1(
            "section-22",
            "In the application of this section to Northern Ireland—a “enactment” includes any enactment of the Parliament of Northern Ireland; andc subject to the preceding provisions of this subsection, subsections (1) to (4) of this section shall be construed as they are construed in their application to England and Wales, notwithstanding that the Land Compensation Act 1961 does not extend to Northern Ireland."
          )
        )

      assert refs(e, :not, "NI") == []
    end
  end
end
