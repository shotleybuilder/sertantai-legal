defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round9ReadsTest do
  @moduledoc """
  The extent reader's misreads and silent drops found by the round 8 agent
  check (seed 13), each on its law's real wording (CV-S05 round 9).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Excepting, Units}

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)

  defp part(n, sections),
    do: ~s(<Part id="part-#{n}">#{Enum.map_join(sections, &p1("section-#{&1}", "Words."))}</Part>)

  describe "NEW-2: a Part's extent with its exceptions after it (ERRA 2013 s.102)" do
    defp erra,
      do:
        part(2, 7..8) <>
          part(3, 25..26) <>
          ~s(<Part id="part-6">) <>
          Enum.map_join(91..93, &p1("section-#{&1}", "Words.")) <>
          ~s|<P1 id="section-102"><P1para><P2 id="section-102-3"><Pnumber>3</Pnumber><P2para><Text>Part 2 extends only to England and Wales and Scotland, except that the following provisions of Part 2 extend also to Northern Ireland—a section 8(3);b paragraph 11 of Schedule 1.</Text></P2para></P2><P2 id="section-102-4"><Pnumber>4</Pnumber><P2para><Text>Part 3 extends to England and Wales, Scotland and Northern Ireland, except as follows— (a) paragraphs 15 to 44 of Schedule 6 extend only to England and Wales and Scotland; (b) paragraphs 52 to 68 of that Schedule extend only to England and Wales.</Text></P2para></P2><P2 id="section-102-8"><Pnumber>8</Pnumber><P2para><Text>This Part extends to England and Wales, Scotland and Northern Ireland except that— (a) section 92 extends only to England and Wales and Scotland.</Text></P2para></P2></P1para></P1></Part>|

    test "the lead read for the Part, less the provisions its exceptions set" do
      e = read("UK_ukpga_2013_24", erra())

      assert {:only, "E+W+S", ["s.7", "s.8"]} in e.lists
      assert {:named, "E+W+S+NI", ["s.25", "s.26"]} in e.lists
      assert {:named, "E+W+S+NI", ["s.91", "s.93", "s.102"]} in e.lists
      assert {:only, "E+W", ["sch.6.para.52..sch.6.para.68"]} in e.lists
    end

    test "an exception naming a Schedule paragraph outranks its introducing section's Part" do
      e = %{
        read("UK_ukpga_2013_24", erra())
        | introduced_by: %{"sch.6" => "s.26", "sch.1" => "s.7"}
      }

      assert Extent.of(e, "sch.6.para.15") == "E+W+S"
      assert Extent.of(e, "sch.6.para.1") == "E+W+S+NI"
      assert Extent.of(e, "s.92") == "E+W+S"
      assert Extent.of(e, "s.8(3)") == "E+W+S+NI"
      assert Extent.of(e, "sch.1.para.11") == "E+W+S+NI"
      assert Extent.of(e, "sch.1.para.2") == "E+W+S"
    end

    test "a qualified exception leaves the lead unread" do
      doc =
        ExtentDoc.doc(
          "UK_ukpga_2013_24",
          part(2, 7..8) <>
            p1(
              "section-102",
              "Part 2 extends only to England and Wales and Scotland, except that— (a) section 8 also extends to Northern Ireland so far as it relates to the 1974 Act."
            )
        )

      assert Excepting.leads(Units.unit_sentences(doc), doc) == []
    end

    test "\"of that Schedule\" is the law's own Schedule named before, never another Act's" do
      assert Units.unlettered(
               "(a) paragraphs 1 to 4 of Schedule 6 extend …; (b) paragraph 9 of that Schedule extends …"
             ) =~
               "paragraph 9 of Schedule 6 extends"

      assert Units.unlettered(
               "paragraph 2 of Schedule 2 to the Social Security Act 1975, and paragraph 4 of that Schedule"
             ) =~
               "of that Schedule"
    end

    test "another Act's provisions in a repeals list are never the law's own (s.102(6))" do
      doc =
        ExtentDoc.doc(
          "UK_ukpga_2013_24",
          p1("section-67", "Words.") <>
            p1(
              "section-102",
              "The repeals of the following provisions in Schedule 20 extend to England and Wales only— (a) section 67 of the Agriculture Act 1967, (b) paragraph 32 of Schedule 2 to the Social Security (Consequential Provisions) Act 1975."
            ) <> ~s|<P1 id="schedule-20"><P1para><Text>Repeals.</Text></P1para></P1>|
        )

      s =
        doc
        |> Units.unit_sentences()
        |> Enum.find_value(fn
          {"s.102", s} -> s
          _ -> nil
        end)

      refute "s.67" in Extent.Unread.subject(s, "s.102", doc)
    end
  end

  test "NEW-3: \"with the exception of— … (b) any provision amending … an enactment which does not so extend\" (CPA 1987 s.49(1))" do
    e =
      read(
        "UK_ukpga_1987_43",
        part(1, 1..2) <>
          ~s(<Part id="part-5">) <>
          p1("section-36", "Words.") <>
          p1(
            "section-49",
            "This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1; (b) any provision amending or repealing an enactment which does not so extend; and (c) any other provision so far as it has effect for the purposes of, or in relation to, a provision falling within paragraph (a) or (b) above."
          ) <> "</Part>"
      )

    assert {:same, nil, ["*"]} in e.lists
    assert Extent.of(e, "s.36") == :same
    assert Extent.of(e, "s.1") == "E+W+S"
  end

  test "NEW-4: the clause is the first section stating a default, not a list before it (ukpga 1981/45 ss.31, 32)" do
    e =
      read(
        "UK_ukpga_1981_45",
        part("I", 1..2) <>
          ~s(<Part id="part-II">) <>
          p1("section-30", "Words.") <>
          p1(
            "section-31",
            "The following provisions of this Act do not extend to Scotland, namely— (a) Part I."
          ) <>
          p1("section-32", "It is hereby declared that this Act extends to Northern Ireland.") <>
          "</Part>"
      )

    assert {e.ref, e.default} == {"s.32", "E+W+S+NI"}
    assert {:not, "S", ["s.1", "s.2"]} in e.lists
    assert Extent.of(e, "s.30") == "E+W+S+NI"
  end

  test "NEW-6: \"Any amendment or repeal by this Act of an enactment which extends to … has the same extent as that enactment but, save as aforesaid, …\" (LGA 1985 s.106(2))" do
    e =
      read(
        "UK_ukpga_1985_51",
        p1("section-84", "Words.") <>
          p1(
            "section-106",
            "Any amendment or repeal by this Act of an enactment which extends to Scotland or Northern Ireland has the same extent as that enactment but, save as aforesaid, this Act extends to England and Wales only."
          )
      )

    assert {e.default, e.lists} == {"E+W", [{:same, nil, ["*"]}]}
    assert Extent.of(e, "s.84") == :same
  end

  test "an item led by its qualifier is withheld, never read whole (FRSA 2004 s.63(2), exposed by NEW-1)" do
    e =
      read(
        "UK_ukpga_2004_21",
        Enum.map_join([34, 35, 36, 52, 53, 60], &p1("section-#{&1}", "Words.")) <>
          ~s|<P1 id="section-63"><P1para><P2 id="section-63-1"><Pnumber>1</Pnumber><P2para><Text>Subject to subsection (2), this Act extends to England and Wales only.</Text></P2para></P2><P2 id="section-63-2"><Pnumber>2</Pnumber><P2para><Text>The following provisions also extend to Scotland—a sections 34 to 36;b in so far as relating to sections 26 to 27A of the Fire Services Act 1947 (c. 41), section 52;c in so far as relating to—i sections 46 and 61 of the Reserve and Auxiliary Forces (Protection of Civil Interests) Act 1951 (c. 65),ii the Superannuation Act 1972 (c. 11), section 53(1) and Schedule 1;d section 60.</Text></P2para></P2></P1para></P1>|
      )

    assert {:also, "S", ["s.34..s.36", "s.60"]} in e.lists
    assert {:unread, nil, ["s.52", "s.53(1)", "sch.1"]} in e.lists
    assert Extent.of(e, "s.52") == nil
  end
end
