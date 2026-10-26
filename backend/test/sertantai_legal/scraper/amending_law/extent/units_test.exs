defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.UnitsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Units

  test "a lead-in's lettered items are statements of their own, after the sentence" do
    s =
      "In Part 5— (a) sections 220 to 224 extend to England and Wales only; (b) section 225 extends to Scotland only"

    assert Units.statements(s) == [
             s,
             "sections 220 to 224 extend to England and Wales only",
             "section 225 extends to Scotland only"
           ]
  end

  test "a compound's second clause names \"that Schedule\"" do
    s =
      "Paragraphs 34 and 35 of Schedule 2 extend to England and Wales and Scotland, and paragraph 36 of that Schedule extends to Scotland only"

    assert Units.statements(s) == [
             s,
             "Paragraphs 34 and 35 of Schedule 2 extend to England and Wales and Scotland",
             "paragraph 36 of Schedule 2 extends to Scotland only"
           ]
  end

  test "repealed words' dots are no sentence's end" do
    assert Units.no_dots("section 1 . . . extends") == "section 1  extends"
  end

  test "a provision's units: its subsections, the leading number dropped" do
    doc =
      ExtentDoc.doc("UK_ukpga_1974_37", """
      <P1 id="section-84"><Pnumber>84</Pnumber><P1para>
      <P2 id="section-84-1"><P2para><Text>This Act extends to Great Britain.</Text></P2para></P2>
      <P2 id="section-84-2"><P2para><Text>Part III does not extend to Scotland.</Text></P2para></P2>
      </P1para></P1>
      """)

    assert Units.units(doc, "section-84") |> Enum.map(&String.trim/1) |> length() == 2
    assert Enum.any?(Units.units(doc, "section-84"), &(&1 =~ "Part III does not extend"))
  end

  describe "unlettered/1 (CV-S05 round 6)" do
    test "places lettered: one list (RTSA 2003 s.17)" do
      assert Units.unlettered(
               "This Part shall extend ... to—a England and Wales, andb Scotland, andc Northern Ireland."
             ) == "This Part shall extend to England and Wales, Scotland and Northern Ireland."
    end

    test "a verb lettered under its subject (SI 2020/1112 reg.1)" do
      assert Units.unlettered(
               "1 These Regulations—a may be cited as the X Regulations 2020;b come into force on IP completion day; andc extend to Northern Ireland only."
             ) =~ "; and. These Regulations extend to Northern Ireland only."
    end

    test "\"there\" after a place (ukpga 1975/71 s.129(6))" do
      assert Units.unlettered(
               "any provision of this Act which amends the X Act 1975 shall extend to Northern Ireland, but except as aforesaid this Act shall not extend there."
             ) =~ "this Act shall not extend to Northern Ireland."
    end

    test "paragraphs under \"In Schedule N—\" are that Schedule's (SI 2014/469 art.3(2))" do
      t =
        Units.unlettered(
          "In Schedule 1—a paragraph 3 extends to England and Wales and Scotland only;b paragraph 8(2)(b) to (d) extends to England and Wales and Scotland only."
        )

      assert tl(Units.statements(t)) == [
               "paragraph 3 of Schedule 1  extends to England and Wales and Scotland only",
               "paragraph 8(2)(b) to (d) of Schedule 1  extends to England and Wales and Scotland only."
             ]
    end

    test "no extent words: unchanged" do
      t = "In Schedule 1— (a) in paragraph 3, omit “x”;"
      assert Units.unlettered(t) == t
    end
  end

  test "lettered children are read whole with their lead-in; numbered ones are units" do
    doc =
      SertantaiLegal.ExtentDoc.doc(
        "UK_ukpga_2003_20",
        ~s(<P1 id="section-17"><P1para><Text>This Part shall extend to—</Text><P3 id="section-17-a"><P3para><Text>a England and Wales, and</Text></P3para></P3><P3 id="section-17-b"><P3para><Text>b Scotland.</Text></P3para></P3></P1para></P1>)
      )

    assert Units.numbered_children(doc, "section-17") == []
    assert [unit] = Units.units(doc, "section-17")
    assert unit =~ "extend to England and Wales and Scotland"
  end
end
