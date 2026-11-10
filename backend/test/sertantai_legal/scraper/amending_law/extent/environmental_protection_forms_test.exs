defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.EnvironmentalProtectionFormsTest do
  @moduledoc """
  Extent wordings read for Environmental Protection: Extent reader
  (2026-11-09), each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp sections(ns), do: Enum.map_join(ns, &ExtentDoc.p1("section-#{&1}", "Words."))

  defp p2s(n, subs) do
    inner =
      Enum.map_join(subs, fn {k, t} ->
        ~s|<P2 id="section-#{n}-#{k}"><P2para><Text>#{t}</Text></P2para></P2>|
      end)

    ~s|<P1 id="section-#{n}"><P1para>#{inner}</P1para></P1>|
  end

  defp part(n, ids),
    do:
      ~s(<Part id="part-#{n}">#{Enum.map_join(ids, &ExtentDoc.p1("section-#{&1}", "Words."))}</Part>)

  test "\"(e) an amendment or repeal has the same extent as …, except where contained in a provision for which a different extent is provided by this subsection\" (Environment Act 2021 s.146(3))" do
    e =
      read(
        "UK_ukpga_2021_30",
        part(3, [50, 54, 57, 60, 63, 66, 71]) <>
          ~s(<Part id="part-9">) <>
          ExtentDoc.p1(
            "section-146",
            "In Part 3 of this Act (waste and resource efficiency)— a the following provisions extend to England and Wales, Scotland and Northern Ireland— i section 50 and Schedule 4 (producer responsibility obligations); ii section 63 (procedure for regulations under the Environmental Protection Act 1990); b the following provisions extend to England and Wales and Northern Ireland— i section 54 and Schedule 8 (deposit schemes); c the following provisions extend to England and Wales— i section 60 (hazardous waste); ii section 66 and Schedule 10 (enforcement powers); d section 71 (waste regulation: amendment of Northern Ireland Order) extends to Northern Ireland; e an amendment or repeal has the same extent as the provision amended or repealed, except where contained in a provision for which a different extent is provided by this subsection."
          ) <> "</Part>"
      )

    assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
    assert "s.57" in refs
    refute Enum.any?(e.lists, &match?({:unread, _, _}, &1))
    # (c)'s roman items end at (d): s.71 is Northern Ireland's only
    assert {:named, "E+W", ["s.60", "s.66", "sch.10"]} in e.lists
    assert {:named, "NI", ["s.71"]} in e.lists
  end

  describe "NERC Act 2006 s.108" do
    defp nerc(subs) do
      read(
        "UK_ukpga_2006_16",
        part(9, [101]) <>
          ~s(<Part id="part-10">) <>
          sections([105, 106, 107]) <>
          p2s(108, [
            {1, "Except as provided by this section, this Act extends to England and Wales only."}
            | subs
          ]) <>
          sections([109]) <>
          "</Part>" <>
          ~s(<Schedules><Schedule id="schedule-11"></Schedule><Schedule id="schedule-12"></Schedule></Schedules>)
      )
    end

    test "\"In Part 9 (miscellaneous), section 101 (…) extends also to …\": the section, the locator dropped" do
      e =
        nerc([
          {6,
           "In Part 9 (miscellaneous), section 101 (abolition of certain agricultural etc. committees) extends also to Scotland and Northern Ireland."}
        ])

      assert {:also, "S+NI", ["s.101"]} in e.lists
    end

    test "\"… have the same extent as the provisions to which they relate (except where otherwise provided)\"" do
      e =
        nerc([
          {7,
           "In this Part— a sections 105, 107 and 109 and this section extend also to Scotland and Northern Ireland so far as necessary, and b the amendments, repeals and revocations in Schedules 11 and 12 have the same extent as the provisions to which they relate (except where otherwise provided)."}
        ])

      assert {:same, nil, ["sch.11", "sch.12"]} in e.lists
      refute {:unread, nil, ["sch.11", "sch.12"]} in e.lists
      # (a)'s "so far as necessary" stays withheld
      assert Enum.any?(e.lists, &match?({:unread, nil, ["s.105" | _]}, &1))
    end
  end

  test "\"… made by Schedule 11 has the same extent as the relevant part of the Act or instrument amended …\" (Anti-social Behaviour, Crime and Policing Act 2014 s.184(8))" do
    e =
      read(
        "UK_ukpga_2014_12",
        sections(1..183) <>
          p2s(184, [
            {8,
             "An amendment, repeal or revocation made by Schedule 11 has the same extent as the relevant part of the Act or instrument amended, repealed or revoked."}
          ]) <>
          ~s(<Schedules><Schedule id="schedule-11"></Schedule></Schedules>)
      )

    assert {:same, nil, ["sch.11"]} in e.lists
  end

  test "\"extend to England and Wales and Scotland (but not Northern Ireland)— …\": the places, the bracket a restatement (2014 c.12 s.184(2))" do
    e =
      read(
        "UK_ukpga_2014_12",
        sections(1..183) <>
          p2s(184, [
            {2,
             "The following provisions extend to England and Wales and Scotland (but not Northern Ireland)— a sections 106(2)(a)(ii) and (6) and 107; b sections 108 to 110 and 112; c section 133(3); d section 178."}
          ])
      )

    assert {:named, "E+W+S", refs} = Enum.find(e.lists, &match?({:named, _, _}, &1))
    assert "s.107" in refs and "s.178" in refs
    refute Enum.any?(e.lists, &match?({:unread, _, _}, &1))
  end

  test "\"section 153 except subsection (1)(k) and (m)\": the section read, its excepted paragraphs keep the default (EPA 1990 s.164(4), Decision 3)" do
    e =
      read(
        "UK_ukpga_1990_43",
        sections(150..163) <>
          p2s(164, [
            {4,
             "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— section 141; section 153 except subsection (1)(k) and (m); section 156 in so far as it relates to Part VI."},
            {6, "This Act extends to England and Wales and Scotland."}
          ])
      )

    alias SertantaiLegal.Scraper.AmendingLaw.Extent.Lookup

    assert Lookup.of(e, "s.153") == "E+W+S+NI"
    assert Lookup.of(e, "s.153(4)") == "E+W+S+NI"
    assert Lookup.of(e, "s.153(1)(k)") == "E+W+S"
    assert Lookup.of(e, "s.141") == "E+W+S+NI"
  end

  test "\"… the amendments made by Parts 2 and 3 have the same extent as the Regulations being amended\" (SI 2019/188 reg.1A)" do
    e =
      read(
        "UK_uksi_2019_188",
        ~s(<Part id="part-2">) <>
          ExtentDoc.p1("regulation-2", "Words.") <>
          "</Part>" <>
          ~s(<Part id="part-3">) <>
          ExtentDoc.p1("regulation-3", "Words.") <>
          "</Part>" <>
          ExtentDoc.p1(
            "regulation-1A",
            "Subject to paragraph (2), the amendments made by Parts 2 and 3 have the same extent as the Regulations being amended."
          )
      )

    assert {:same, nil, refs} = Enum.find(e.lists, &match?({:same, nil, _}, &1))
    assert "reg.2" in refs and "reg.3" in refs
  end

  test "\"This Order may be cited as …, shall come into force on … and shall extend to Scotland only\" (SIs 1991/146, 1991/1179)" do
    e =
      read(
        "UK_uksi_1991_146",
        ExtentDoc.p1(
          "article-1",
          "This Order may be cited as the Financial Assistance (Sewerage Improvements) (Scotland) Order 1991, shall come into force on 1st March 1991 and shall extend to Scotland only."
        ) <> ExtentDoc.p1("article-2", "Words.")
      )

    assert e.default == "S"

    # never across an exception (SI 1996/973)
    e =
      read(
        "UK_uksi_1996_973",
        ExtentDoc.p1(
          "regulation-1",
          "These Regulations may be cited as the Environment Act 1995 (Consequential and Transitional Provisions) (Scotland) Regulations 1996, shall come into force on 1st April 1996 and, other than paragraph 11 of the Schedule, shall extend to Scotland only."
        )
      )

    refute e.default == "S"
  end

  test "\"They extend to England and Wales\" after the citation: the law itself (SI 2018/575 reg.1)" do
    e =
      read(
        "UK_uksi_2018_575",
        ~s|<P1 id="regulation-1"><P1para><P2 id="regulation-1-1"><P2para><Text>These Regulations may be cited as the Waste (Miscellaneous Amendments) Regulations 2018 and come into force on 1st June 2018.</Text></P2para></P2><P2 id="regulation-1-2"><P2para><Text>They extend to England and Wales.</Text></P2para></P2></P1para></P1>| <>
          ExtentDoc.p1("regulation-2", "Words.")
      )

    assert e.default == "E+W"
  end

  test "\"No provision of this Act extends to Northern Ireland\" = the rest of the UK (Noise and Statutory Nuisance Act 1993 s.12(4))" do
    e =
      read(
        "UK_ukpga_1993_40",
        sections(1..11) <>
          p2s(12, [{4, "No provision of this Act extends to Northern Ireland."}])
      )

    assert e.default == "E+W+S"
    refute Enum.any?(e.lists, &match?({:unread, _, _}, &1))
  end

  test "\"This section and sections 3 and 5 extend to NI but, subject to subsections (6) to (8), the other provisions … do not extend there\" (PPC Act 1999 s.7(5))" do
    e =
      read(
        "UK_ukpga_1999_24",
        sections(1..6) <>
          p2s(7, [
            {5,
             "This section and sections 3 and 5 extend to Northern Ireland but, subject to subsections (6) to (8), the other provisions of this Act do not extend there."}
          ])
      )

    assert e.default == "E+W+S"
    assert [{:also, "NI", refs}] = e.lists
    assert Enum.sort(refs) == ["s.3", "s.5", "s.7"]
  end
end
