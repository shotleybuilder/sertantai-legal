defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.AppliesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Applies, Excepted, Lookup, Rows, Same, Units}
  alias SertantaiLegal.Scraper.ApplicationClause

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp words(ns, kind), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))
  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  defp refs(e, kind, place),
    do: for({^kind, ^place, refs} <- e.lists ++ e.applies, r <- refs, do: r)

  defp p2s(id, subs),
    do:
      ~s(<P1 id="#{id}">) <>
        Enum.map_join(subs, fn {n, text} ->
          ~s(<P2 id="#{id}-#{n}"><Pnumber>#{n}</Pnumber><P2para><Text>#{text}</Text></P2para></P2>)
        end) <> "</P1>"

  defp doc(law, body), do: ExtentDoc.doc(law, body)
  defp p1(id, text), do: ExtentDoc.p1(id, text)

  describe "Applies (a provision's own application, CV-S05 round 7)" do
    test "named provisions, this paragraph, subsections; not / only" do
      d =
        doc(
          "UK_uksi_2025_102",
          p1("regulation-1", "Regulation 44 applies to Scotland only.") <>
            p1("regulation-2", "Regulations 8 and 10 do not apply to Wales.") <>
            p1("regulation-3", "Subsections (4) to (6) shall not apply to Scotland.") <>
            ~s|<Schedule id="schedule-2"><ScheduleBody><P1 id="schedule-2-paragraph-3"><P1para><Text>This paragraph applies in relation to England only.</Text></P1para></P1></ScheduleBody></Schedule>|
        )

      assert Applies.applies(d) == [
               {:applies, "S", ["reg.44"]},
               {:applies_not, "W", ["reg.8", "reg.10"]},
               {:applies_not, "S", ["reg.3(4)", "reg.3(5)", "reg.3(6)"]},
               {:applies, "E", ["sch.2.para.3"]}
             ]
    end

    test "respectively; a following list; extends and applies" do
      d =
        doc(
          "UK_uksi_2017_571",
          p1(
            "regulation-1",
            "Regulations 60, 61 and 62 apply in relation to Scotland, Wales and Northern Ireland respectively."
          ) <>
            p1(
              "regulation-2",
              "The following regulations do not apply in relation to Wales— a regulation 19; b regulation 30."
            ) <>
            p1("regulation-6", "Regulation 7 extends and applies to England and Wales only.")
        )

      assert Applies.applies(d) == [
               {:applies, "S", ["reg.60"]},
               {:applies, "W", ["reg.61"]},
               {:applies, "NI", ["reg.62"]},
               {:applies_not, "W", ["reg.19", "reg.30"]},
               {:applies, "E+W", ["reg.7"]},
               {:only, "E+W", ["reg.7"]}
             ]
    end

    test "never on a condition, a modification, or the law's own application" do
      for text <- [
            "This paragraph applies in Northern Ireland where a medicinal product has undergone the controls.",
            "Subsection (4) above has effect in relation to Wales as if the words were omitted.",
            "These Regulations apply in relation to Wales."
          ] do
        assert Applies.applies(doc("UK_uksi_2012_1", p1("regulation-9", text))) == [], text
      end
    end

    test "statement/1: the kind and place, for the catalogue" do
      assert Applies.statement("Regulation 44 applies to Scotland only.") == {:applies, "S"}

      assert Applies.statement("This paragraph does not apply to Scotland.") ==
               {:applies_not, "S"}

      assert Applies.statement("These Regulations apply in relation to Wales.") == nil
    end
  end

  describe "Lookup.application_at/2" do
    test "a provision's own, else the law's; not: where it otherwise applies or extends, less the place" do
      e = %Extent{
        default: "E+W+S",
        application: nil,
        applies: [{:applies, "S", ["reg.44"]}, {:applies_not, "W", ["reg.8"]}]
      }

      assert Lookup.application_at(e, ["reg.44"]) == "S"
      assert Lookup.application_at(e, ["reg.8(2)"]) == "E+S"
      assert Lookup.application_at(e, ["reg.9"]) == nil
      assert Lookup.application_at(%{e | application: "E"}, ["reg.9"]) == "E"
      assert Lookup.application_at(e, []) == nil
    end

    test "kept in extent_rules and read back" do
      e = %Extent{
        default: "E+W",
        applies: [{:applies, "S", ["reg.44"]}, {:applies_not, "W", ["reg.8"]}]
      }

      assert Rows.from_rows(Enum.map(Rows.to_rows(e, "UK_uksi_2025_102"), &Map.new/1)).applies ==
               e.applies
    end
  end

  describe "Excepted (round 6 D1, D3)" do
    test "provisions excepted from an extent subsection: their bound withheld" do
      d =
        doc(
          "UK_ukpga_2003_39",
          ~s|<P1 id="section-111"><P1para><P2 id="section-111-1"><P2para><Text>This Act extends to England and Wales only.</Text></P2para></P2><P2 id="section-111-2"><P2para><Text>Subsection (1) does not apply to section 59(3), 90 or 102.</Text></P2para></P2></P1para></P1>|
        )

      assert Excepted.excepted(Units.unit_sentences(d), d) == [
               {:unread, nil, ["s.59(3)", "s.90", "s.102"]}
             ]
    end

    test "never where the subsection named isn't an extent statement" do
      d =
        doc(
          "UK_ukpga_1990_18",
          ~s|<P1 id="section-13"><P1para><P2 id="section-13-1"><P2para><Text>A person commits an offence.</Text></P2para></P2><P2 id="section-13-2"><P2para><Text>Subsection (1) does not apply to section 4.</Text></P2para></P2></P1para></P1>|
        )

      assert Excepted.excepted(Units.unit_sentences(d), d) == []
    end
  end

  describe "same-extent wordings (round 7)" do
    test "the extent of any amendment … is the same as; a provision that amends; also extends there" do
      for {text, want} <- [
            {"The extent of any amendment or repeal made by this Act is the same as that of the enactment amended or repealed.",
             [{:same, nil, ["*"]}]},
            {"The extent of any amendment, repeal or revocation made by section 60 or by Schedule 1 is the same as that of the provision amended.",
             [{:same, nil, ["s.60", "sch.1"]}]},
            {"Subject to paragraphs (4) to (6), a provision that amends an enactment has the same extent and application as the enactment that it amends.",
             [{:same, nil, ["*"]}]},
            {"An amendment, repeal or revocation made by this Act has the same extent in the United Kingdom as the enactment amended.",
             [{:same, nil, ["*"]}]},
            {"The amendment by this Act of any enactment extending to Northern Ireland also extends there.",
             [{:same, nil, ["*"]}]}
          ] do
        d =
          doc(
            "UK_ukpga_2000_6",
            p1("section-1", "Words.") <> p1("section-60", "Words.") <> p1("section-167", text)
          )

        assert Same.amendments_same(Units.unit_sentences(d), d) == want, text
      end
    end
  end

  describe "a provision's own application read whole" do
    test "\"Subsection (2)(aa) applies only in relation to Wales\" (TCPA 1990 s.70)" do
      e =
        read(
          "UK_ukpga_1990_8",
          p1("section-70", "Subsection (2)(aa) applies only in relation to Wales.") <>
            p1(
              "section-71",
              "Subsections (1A), (2)(b) and (2ZZA) to (2ZZC) of section 70 do not apply in relation to Wales."
            )
        )

      assert {"W", ["s.70(2)(aa)"]} in rows(e, :applies)
    end

    test "\"Subsection (3)(a) above does not apply in Wales\" (ukpga 1980/66 s.264)" do
      e =
        read(
          "UK_ukpga_1980_66",
          p1("section-264", "Subsection (3)(a) above does not apply in Wales.")
        )

      assert {"W", ["s.264(3)(a)"]} in rows(e, :applies_not)
    end

    test "\"This subsection does not apply to Scotland\" is the subsection's (ukpga 1974/39 s.189(3))" do
      e =
        read(
          "UK_ukpga_1974_39",
          p2s("section-189", [
            {"1", "In this Act, unless the context otherwise requires— words."},
            {"3",
             "Any provision of this Act requiring a document to be signed is complied with by a body corporate if the document is sealed by that body. This subsection does not apply to Scotland."}
          ])
        )

      assert {"S", ["s.189(3)"]} in rows(e, :applies_not)
    end

    test "\"…, but this paragraph does not apply in Scotland\" (uksi 2026/194 reg.22(3))" do
      e =
        read(
          "UK_uksi_2026_194",
          p2s("regulation-22", [
            {"3",
             "In default of an agreement, the arbitrator is such person as may be appointed following a request by— a a party; or b the parties jointly, but this paragraph does not apply in Scotland."}
          ])
        )

      assert {"S", ["reg.22(3)"]} in rows(e, :applies_not)
    end
  end

  describe "a Schedule's Part that only owns the paragraphs listed" do
    @sentence "Paragraphs 3, 11(a) and (c), 17 of Part 1 of Schedule 1 to this Order apply in relation to England only."

    test "only the paragraphs listed apply to England (uksi 2006/1407 reg.1)" do
      e =
        read(
          "UK_uksi_2006_1407",
          p1("article-1", @sentence) <>
            ~s(<Schedule id="schedule-1"><Part id="schedule-1-part-1">#{p1("schedule-1-part-1-paragraph-3", "Words.")}#{p1("schedule-1-part-1-paragraph-4", "Words.")}#{p1("schedule-1-part-1-paragraph-17", "Words.")}</Part></Schedule>)
        )

      applies = refs(e, :applies, "E")
      assert "sch.1.pt.1.para.3" in applies
      assert "sch.1.pt.1.para.17" in applies
      refute "sch.1.pt.1.para.4" in applies
    end

    test "\"Schedule 1 to this Order apply …\" is never the whole SI's application" do
      assert ApplicationClause.parse(@sentence) == nil
      assert ApplicationClause.parse_bound(@sentence) == nil

      assert ApplicationClause.parse("This Order applies in relation to England only.") ==
               {:apply, ["E"]}
    end
  end

  describe "\"extend to England and Wales but apply in relation to England only\" (uksi 2010/708 art.1)" do
    test "the extent half is read, and \"but Part 5 applies\" is Part 5's alone" do
      e =
        read(
          "UK_uksi_2010_708",
          p1(
            "article-1",
            "Parts 1, 5 and 6 extend to England and Wales, but Part 5 applies in relation to England only."
          ) <>
            ~s(<Part id="part-1">#{words([2], "article")}</Part><Part id="part-5">#{words([11], "article")}</Part><Part id="part-6">#{words([13], "article")}</Part>)
        )

      assert {"E+W", ["reg.2", "reg.11", "reg.13"]} in rows(e, :named)
      assert {"E", ["reg.11"]} in rows(e, :applies)
    end

    test "\"article 9, together with Schedule 2, extend to E+W but apply in relation to England only\"" do
      e =
        read(
          "UK_uksi_2010_708",
          words([9], "article") <>
            p1(
              "article-2",
              "Article 9, together with Schedule 2, extend to England and Wales but apply in relation to England only."
            )
        )

      assert {"E+W", ["reg.9", "sch.2"]} in rows(e, :named)
      assert {"E", ["reg.9", "sch.2"]} in rows(e, :applies)
    end
  end

  describe "\"cease to apply\"" do
    test "\"Section 61B(1) to (7) (…) cease to apply in relation to England\" is not applying there (ukpga 2013/27 s.5)" do
      e =
        read(
          "UK_ukpga_2013_27",
          p1(
            "section-5",
            "Section 61B(1) to (7) (Secretary of State or Welsh Ministers may call in unadopted local development order for approval) cease to apply in relation to England."
          )
        )

      refute Enum.any?(rows(e, :applies), fn {_, refs} -> "s.61B(1)" in refs end)

      assert {"E", ~w[s.61B(1) s.61B(2) s.61B(3) s.61B(4) s.61B(5) s.61B(6) s.61B(7)]} in rows(
               e,
               :applies_not
             )
    end
  end

  describe "territorial application" do
    test "\"They apply in relation to— (a) England …, and (b) Wales\" (uksi 2016/1154 reg.1(3))" do
      e =
        read(
          "UK_uksi_2016_1154",
          p1(
            "regulation-1",
            "These Regulations may be cited as the Environmental Damage (Prevention and Remediation) (England) Regulations 2016. These Regulations extend to England and Wales only. They apply in relation to—a England and the sea adjacent to England out as far as the seaward boundary of the territorial sea, andb Wales, within the meaning given by section 158 of the Government of Wales Act 2006."
          )
        )

      assert e.application == "E+W"
    end

    test "\"Regulation 17 applies in relation to live fish and live eggs of fish in Wales\" (wsi 2014/3303)" do
      e =
        read(
          "UK_wsi_2014_3303",
          words([17], "regulation") <>
            p1(
              "regulation-2",
              "Regulation 17 applies in relation to live fish and live eggs of fish in Wales."
            )
        )

      assert {"W", ["reg.17"]} in rows(e, :applies)
    end

    test "never a disapplication of things in a place (uksi 2012/3119)" do
      e =
        read(
          "UK_uksi_2012_3119",
          words([14], "regulation") <>
            p1(
              "regulation-1",
              "These Regulations do not apply in relation to any building in Wales, other than an excepted energy building."
            )
        )

      assert e.application == nil
    end
  end

  describe "never an application" do
    test "things that are cases, not a place's, set no application" do
      e =
        read(
          "UK_ukpga_1982_27",
          p1(
            "section-18",
            "This section applies to a freezing order made under section 40D of the Immigration Act 2014 by a magistrates' court in England and Wales or a court of summary jurisdiction in Northern Ireland."
          ) <>
            p1(
              "section-19",
              "Subsections (5) to (8) of this section apply to a corporate joint committee as they apply to a local authority in Wales."
            ) <>
            p1(
              "section-20",
              "Subsection (3C) applies to an agent who advertises letting agency work in relation to dwelling houses in England."
            )
        )

      assert rows(e, :applies) == []
    end

    test "never another law's section, nor an \"as if\" modification, as an application (2003/20 s.24, 1990/8 s.319ZZA)" do
      e =
        read(
          "UK_ukpga_2003_20",
          p1(
            "section-24",
            "Section 10 of the Police and Fire Reform (Scotland) Act 2012 (declaration) shall apply to a constable of the Police Force appointed in Scotland."
          ) <>
            p1(
              "section-25",
              "This section applies in relation to a relevant planning function conferred on a mineral planning authority as if references to a local planning authority were to a mineral planning authority in England."
            )
        )

      assert rows(e, :applies) == []
    end
  end
end
