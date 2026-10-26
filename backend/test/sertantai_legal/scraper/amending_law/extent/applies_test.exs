defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.AppliesTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Applies, Excepted, Lookup, Rows, Same, Units}

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
end
