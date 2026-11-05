defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.DefaultTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Default
  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp part(n, ids, kind \\ "section"), do: ~s(<Part id="part-#{n}">#{words(ids, kind)}</Part>)

  test "what one sentence states: a default, a list heading, a Part not extending, nothing" do
    assert Default.statement(
             "Subject to the following provisions, this Act extends to England and Wales only."
           ) ==
             {:default, "E+W"}

    assert Default.statement("The following extend also to Scotland— sections 1 to 54;") ==
             {:list, :also, "S"}

    assert Default.statement(
             "Part III, except section 75 and Schedule 7, does not extend to Scotland."
           ) ==
             {:part_not, "S"}

    assert Default.statement(
             "Before exercising the power in relation to an enactment which extends to Scotland, the Secretary of State must consult."
           ) == nil
  end

  test "an Act of the UK Parliament extending to Northern Ireland extends to Great Britain too" do
    assert Default.statement("This Act extends to Northern Ireland.", "ukpga") ==
             {:default, "E+W+S+NI"}

    assert Default.statement("This Act extends to Northern Ireland only.", "ukpga") ==
             {:default, "NI"}

    assert Default.statement("This Order extends to Northern Ireland.", "nisr") ==
             {:default, "NI"}

    # "only" in another subsection's list is not the default's (ukpga 2005/4 s.147)
    clause =
      "(1) Sections 7, 8 and 9 extend to England and Wales only. (2) Section 6 and Part 5 extend to Northern Ireland only. (4) Subject to subsections (1) to (3), this Act extends to Northern Ireland."

    assert Default.westminster("NI", clause, "ukpga") == "E+W+S+NI"
  end

  test "a clause's default: \"does not extend\" is the rest of the UK" do
    assert Default.default("This Act does not extend to Northern Ireland.") == "E+W+S"
    assert Default.default("Words.") == nil
  end

  test "the clause is the first section stating a default, not a list before it (ukpga 1981/45 ss.31, 32)" do
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

  describe "a whole-law default" do
    test "\"This Act extends to Scotland (subject to subsection (6)) and Northern Ireland\" (ukpga 1999/28 s.43)" do
      e =
        read(
          "UK_ukpga_1999_28",
          p1(
            "section-43",
            "This Act extends to Scotland (subject to subsection (6)) and Northern Ireland."
          )
        )

      assert e.default == "S+NI"
    end

    test "\"This Act extends only to England and Wales, except that— (a) section 46(1) extends to Scotland only, …\" (ukpga 2010/29 s.49)" do
      e =
        read(
          "UK_ukpga_2010_29",
          words([1, 46]) <>
            p1(
              "section-49",
              "This Act extends only to England and Wales, except that—a section 46(1) extends to Scotland only,b paragraph 43 of Schedule 4 extends to England and Wales and Scotland."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.46(1)") == "S"
    end

    test "\"This Act, except section 4, extends to Northern Ireland\": the exception before the verb (ukpga 1997/28 s.30, 1998/17 s.53)" do
      e =
        read(
          "UK_ukpga_1997_28",
          words([1, 4, 9]) <>
            p1("section-30", "This Act, except section 4, extends to Northern Ireland.")
        )

      assert e.default == "E+W+S+NI"
      assert Extent.of(e, "s.4") == "E+W+S"
      assert Extent.of(e, "s.9") == "E+W+S+NI"

      assert Default.statement(
               "This Act, except for sections 7 and 8, extends to Northern Ireland.",
               "ukpga"
             ) ==
               {:default, "E+W+S+NI"}

      # a qualified exception is left as it stands, unread (ukpga 1975/30 s.39)
      qualified =
        "This Act, except paragraph 5 of Schedule 3 and except in so far as it relates to the House of Commons Disqualification Act 1975, extends to Scotland only."

      assert Default.except_first(qualified) == qualified
    end

    test "a later section's \"this Act shall not extend to Northern Ireland\" narrows the default (ukpga 1983/20 ss.146, 147)" do
      e =
        read(
          "UK_ukpga_1983_20",
          words([1, 81, 144]) <>
            p1(
              "section-146",
              "Sections 80 and 144 above shall extend to Scotland together with any amendment or repeal by this Act of any enactment which so extends; but, except as aforesaid, this Act shall not extend to Scotland."
            ) <>
            p1(
              "section-147",
              "Sections 81 and 144 above shall extend to Northern Ireland; but except as aforesaid and except so far as it relates to the interpretation or commencement of the said provisions, this Act shall not extend to Northern Ireland."
            )
        )

      assert e.default == "E+W"
      assert Extent.of(e, "s.1") == "E+W"
    end
  end
end
