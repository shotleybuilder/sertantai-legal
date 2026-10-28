defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.TargetedTest do
  @moduledoc """
  Target-named extent statements (CV-S05f): an amending law stating the
  extent of the changes it makes to a named target of the amended law, each
  on its law's real wording (the CV-S05f measure, 2026-10-28).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Patterns, Targeted}

  defp t(kind, place, scope, law, refs),
    do: %{kind: kind, place: place, scope: scope, law: law, refs: refs}

  describe "statements/2: one sentence" do
    test "a provision of the paragraph's own law (SOCPA 2005 Sch.7 para 27(4))" do
      assert Targeted.statements(
               "The repeal of section 4(8) extends also to Scotland.",
               "sch.7.para.27"
             ) ==
               [t(:also, "S", "sch.7.para.27", nil, ["s.4(8)"])]
    end

    test "a law named, in a section: the whole law's changes (Arbitration Act 1996 s.108(4))" do
      assert Targeted.statements(
               "The repeal of the Arbitration Act 1975 extends only to England and Wales and Northern Ireland.",
               "s.108"
             ) == [t(:only, "E+W+NI", "*", "Arbitration Act 1975", ["*"])]
    end

    test "a repeals Schedule Part's note, several laws (EPA 1990 Sch.16 Pt III)" do
      assert Targeted.statements(
               "Note: The repeals in the Clean Air Act 1956, the Control of Pollution Act 1974 and the Control of Smoke Pollution Act 1989 do not extend to Scotland.",
               "sch.16.pt.III"
             ) == [
               t(:not, "S", "sch.16.pt.III", "Clean Air Act 1956", ["*"]),
               t(:not, "S", "sch.16.pt.III", "Control of Pollution Act 1974", ["*"]),
               t(:not, "S", "sch.16.pt.III", "Control of Smoke Pollution Act 1989", ["*"])
             ]
    end

    test "a law's punctuation kept (EPA 1990 Sch.16 Pt I)" do
      assert Targeted.statements(
               "Note: The repeal of the Alkali, &c. Works Regulation Act 1906 does not extend to Northern Ireland.",
               "sch.16.pt.I"
             ) == [t(:not, "NI", "sch.16.pt.I", "Alkali, &c. Works Regulation Act 1906", ["*"])]
    end

    test "a provision of a named law, its chapter dropped (SI 2008/948 Sch.2 para 2)" do
      assert Targeted.statements(
               "The repeal of section 15 of the Companies (Audit, Investigations and Community Enterprise) Act 2004 extends to Northern Ireland only.",
               "sch.2.para.2"
             ) == [
               t(
                 :only,
                 "NI",
                 "sch.2.para.2",
                 "Companies (Audit, Investigations and Community Enterprise) Act 2004",
                 ["s.15"]
               )
             ]
    end

    test "several subjects joined (Coroners and Justice Act 2009 Sch.23 Pt 2)" do
      assert Targeted.statements(
               "The repeal of section 4 of the Law of Libel Amendment Act 1888 (c. 64) and the repeal of section 20(2) of the Defamation Act 1996 do not extend to Northern Ireland.",
               "sch.23.pt.2"
             ) == [
               t(:not, "NI", "sch.23.pt.2", "Law of Libel Amendment Act 1888", ["s.4"]),
               t(:not, "NI", "sch.23.pt.2", "Defamation Act 1996", ["s.20(2)"])
             ]
    end

    test "an amendment or repeal of a law's provisions (Criminal Justice and Courts Act 2015 s.96(2))" do
      assert Targeted.statements(
               "An amendment or repeal of a provision of the Armed Forces Act 2006 extends to England and Wales, Scotland and Northern Ireland.",
               "s.96"
             ) == [t(:named, "E+W+S+NI", "*", "Armed Forces Act 2006", ["*"])]
    end

    test "a list of a law's provisions (ERRA 2013 s.102(6))" do
      assert Targeted.statements(
               "The repeals of the following provisions in Schedule 20 extend to England and Wales only— (a) section 67 of the Agriculture Act 1967, (b) paragraph 32 of Schedule 2 to the Social Security (Consequential Provisions) Act 1975, and (c) paragraph 4 of Schedule 2 to the Social Security (Consequential Provisions) Act 1992.",
               "s.102"
             ) == [
               t(:only, "E+W", "sch.20", "Agriculture Act 1967", ["s.67"]),
               t(:only, "E+W", "sch.20", "Social Security (Consequential Provisions) Act 1975", [
                 "sch.2.para.32"
               ]),
               t(:only, "E+W", "sch.20", "Social Security (Consequential Provisions) Act 1992", [
                 "sch.2.para.4"
               ])
             ]
    end

    test "the law's own Part, then the laws it changes (ukpga 2003/44 s.337)" do
      assert Targeted.statements(
               "The repeals in Part 4 of Schedule 37 relating to—a the Bankers' Books Evidence Act 1879 (c. 11),b the Explosive Substances Act 1883 (c. 3), andc the Contempt of Court Act 1981 (c. 49), do not extend to Northern Ireland.",
               "s.337"
             ) == [
               t(:not, "NI", "sch.37.pt.4", "Bankers' Books Evidence Act 1879", ["*"]),
               t(:not, "NI", "sch.37.pt.4", "Explosive Substances Act 1883", ["*"]),
               t(:not, "NI", "sch.37.pt.4", "Contempt of Court Act 1981", ["*"])
             ]
    end

    test "no law named outside a Schedule paragraph: the law's own provisions (SI 2012/2404 reg.4)" do
      assert Targeted.statements(
               "The amendment in Schedule 1 extends to England and Wales only.",
               "reg.4"
             ) ==
               nil
    end

    test "never: the law's own provisions, an exception, a lead-in, a relative clause, a mention" do
      for s <- [
            "The amendments made by section 12 extend to Scotland only.",
            "This Part, except this section and the repeals in the House of Commons Disqualification Act 1975, does not extend to Northern Ireland.",
            "Note: Except as provided in Part II of this Schedule, the repeal of the Radioactive Substances Act 1948 does not extend to Northern Ireland.",
            "Subsection (6) does not apply to the amendment of the Police Act 1997 (c. 50) made by paragraph 64 of Schedule 2, which extends to England and Wales only.",
            "An amendment or repeal of any other provision, so far as it is applied by the Armed Forces Act 2006, extends to England and Wales, Scotland and Northern Ireland.",
            "An amendment (other than an amendment of Part 1A of the Petroleum Act 1998) or repeal made by this Act has the same extent as the provision to which it relates.",
            "The amendment or repeal of any provision by this Act has the same extent as the provision being amended or repealed."
          ] do
        assert Targeted.statements(s, "s.1") == nil, s
      end
    end
  end

  # SOCPA 2005 Sch.7 para 27, as legislation.gov.uk holds it
  @socpa """
  <Legislation><Primary><Body>
  <P1 id="section-179"><P1para><Text>Subject to the following provisions of this section, this Act extends to England and Wales only.</Text></P1para></P1>
  </Body><Schedules><Schedule id="schedule-7"><ScheduleBody>
  <P1 id="schedule-7-paragraph-27"><Pnumber>27</Pnumber>
  <P2 id="schedule-7-paragraph-27-1"><Pnumber>1</Pnumber><P2para><Text>The Road Traffic Act 1988 is amended as follows.</Text></P2para></P2>
  <P2 id="schedule-7-paragraph-27-2"><Pnumber>2</Pnumber><P2para><Text>In section 4 (driving etc. under influence of drink or drugs), omit subsections (6) to (8).</Text></P2para></P2>
  <P2 id="schedule-7-paragraph-27-4"><Pnumber>4</Pnumber><P2para><Text>The repeal of section 4(8) extends also to Scotland.</Text></P2para></P2>
  </P1>
  </ScheduleBody></Schedule></Schedules></Primary></Legislation>
  """

  describe "read from a document" do
    setup do
      doc = Doc.new("UK_ukpga_2005_15", [@socpa])
      %{doc: doc, e: Extent.read(doc)}
    end

    test "the paragraph's statement is a target, and its sentence read", %{doc: doc, e: e} do
      assert e.targets == [t(:also, "S", "sch.7.para.27", nil, ["s.4(8)"])]

      assert {"sch.7.para.27", "The repeal of section 4(8) extends also to Scotland.",
              "target:also:S"} in Patterns.classes(
               doc,
               e
             )
    end

    test "each change by its target: s.4(6) England and Wales, s.4(8) also Scotland", %{e: e} do
      rta = &%{law: "UK_ukpga_1988_52", title: "Road Traffic Act 1988", target: &1}
      assert Extent.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(6)")) == "E+W"
      assert Extent.of_change(e, ["sch.7.para.27(2)"], rta.("s.4(8)")) == "E+W+S"
      # (no change named: the provision's bound, as before)
      assert Extent.of_change(e, ["sch.7.para.27(2)"]) == "E+W"
    end
  end
end
