defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.WasteWaterClimateFormsTest do
  @moduledoc """
  Extent wordings read for Waste, Water and Climate: Extent reader
  (2026-11-26), each on its law's real wording.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{ReadCache, Units}

  defp read(law, body), do: ReadCache.read(ExtentDoc.doc(law, body))

  defp p2s(id, subs) do
    inner =
      Enum.map_join(subs, fn {k, t} ->
        ~s|<P2 id="#{id}-#{k}"><P2para><Text>#{t}</Text></P2para></P2>|
      end)

    ~s|<P1 id="#{id}"><P1para>#{inner}</P1para></P1>|
  end

  defp same(e), do: for({:same, nil, refs} <- e.lists, do: refs)
  defp unread(e), do: for({:unread, nil, refs} <- e.lists, r <- refs, do: r)
  defp only(e, place), do: for({:only, ^place, refs} <- e.lists, r <- refs, do: r)

  describe "a default apart from the provisions listed below (Climate Change Act 2008 s.99)" do
    setup do
      e =
        read(
          "UK_ukpga_2008_27",
          ExtentDoc.p1("section-71", "Words.") <>
            p2s("section-99", [
              {1,
               "This Act, apart from the provisions listed below, extends to the whole of the United Kingdom."},
              {2,
               "The following provisions of this Act extend to England and Wales only— (a) sections 71 to 75 and Schedule 5 (waste reduction schemes); (b) section 76 (collection of household waste)."}
            ])
        )

      %{e: e}
    end

    test "the default is the whole UK; the listed provisions their own", %{e: e} do
      assert e.default == "E+W+S+NI"
      assert "s.76" in only(e, "E+W")
      assert unread(e) == []
    end
  end

  describe "same-extent wordings" do
    test "\"the Act or instrument amended, repealed or revoked\" (SI 2018/374 reg.2)" do
      e =
        read(
          "UK_uksi_2018_374",
          ExtentDoc.p1(
            "regulation-2",
            "An amendment, repeal or revocation made by these Regulations has the same extent as the Act or instrument amended, repealed or revoked."
          )
        )

      assert same(e) == [["*"]]
      assert unread(e) == []
    end

    test "\"Any provision of these Regulations amending a provision\" (SI 2019/74 reg.2)" do
      e =
        read(
          "UK_uksi_2019_74",
          ExtentDoc.p1(
            "regulation-2",
            "Any provision of these Regulations amending a provision in an enactment has the same extent as the provision being amended."
          )
        )

      assert same(e) == [["*"]]
      assert unread(e) == []
    end

    test "\"Unless otherwise stated, each amendment …\" (SI 2025/412 reg.1)" do
      e =
        read(
          "UK_uksi_2025_412",
          ExtentDoc.p1(
            "regulation-1",
            "Unless otherwise stated, each amendment made by these Regulations has the same extent as the provision amended."
          )
        )

      assert same(e) == [["*"]]
      assert unread(e) == []
    end
  end

  describe "an extension to a place only so far as stated (SI 2018/98 reg.1(3))" do
    test "never a default of that place alone; the law withheld" do
      e =
        read(
          "UK_uksi_2018_98",
          p2s("regulation-1", [
            {1,
             "These Regulations may be cited as the Fluorinated Greenhouse Gases (Amendment) Regulations 2018."},
            {3,
             "These Regulations extend to Northern Ireland only insofar as they deal with import and export controls and trade with any place outside the United Kingdom, within the meaning of paragraph 20 of Schedule 3 to the Northern Ireland Act 1998."}
          ])
        )

      assert e.default == nil
      assert "*" in unread(e)
    end
  end

  describe "\"They extend …\" after the citation, with the numbers the text carries (SI 2021/513 reg.1)" do
    test "the law itself" do
      e =
        read(
          "UK_uksi_2021_513",
          ~s|<P1 id="regulation-1"><Pnumber>1</Pnumber><P1para><P2 id="regulation-1-1"><Pnumber>1</Pnumber><P2para><Text>These Regulations may be cited as the Recognised Auction Platforms and Greenhouse Gas Emissions Trading Scheme Auctioning (Amendment) Regulations 2021.</Text></P2para></P2><P2 id="regulation-1-2"><Pnumber>2</Pnumber><P2para><Text>They come into force on 19th May 2021.</Text></P2para></P2><P2 id="regulation-1-3"><Pnumber>3</Pnumber><P2para><Text>They extend to the whole of the United Kingdom.</Text></P2para></P2></P1para></P1>| <>
            ExtentDoc.p1("regulation-2", "Words.")
        )

      assert e.default == "E+W+S+NI"
      assert unread(e) == []
    end

    test "the provision's words as held: its number and its first paragraph's" do
      text =
        "1 1 These Regulations may be cited as the Recognised Auction Platforms and Greenhouse Gas Emissions Trading Scheme Auctioning (Amendment) Regulations 2021. 2 They come into force on 19th May 2021. 3 They extend to the whole of the United Kingdom."

      assert Units.unlettered(text) =~
               "3 These Regulations extend to the whole of the United Kingdom."
    end
  end

  # Decision 2 (Jason 2026-11-26): the round's one-law wordings over the triage size
  describe "Decision 2: one-law wordings" do
    defp sections(ns), do: Enum.map_join(ns, &ExtentDoc.p1("section-#{&1}", "Words."))
    defp lists(e, kind), do: for({^kind, place, refs} <- e.lists, do: {place, refs})

    test "an extension \"but only so far as required for …\" reads as the place, an upper bound (2014 c.21 s.93(2))" do
      e =
        read(
          "UK_ukpga_2014_21",
          sections([61, 62]) <>
            ExtentDoc.p1("schedule-8-paragraph-1", "Words.") <>
            p2s("section-93", [
              {1, "This Act extends to England and Wales only, subject as follows."},
              {2,
               "Sections 61 and 62 and Schedule 8 extend also to Scotland, but only so far as required for the purposes of regulations applying as mentioned in section 61(11)(b)."},
              {4,
               "An amendment or repeal made by this Act has the same extent as the enactment to which it relates."}
            ])
        )

      assert e.default == "E+W"
      assert {"S", ["s.61", "s.62", "sch.8"]} in lists(e, :also)
      assert unread(e) == []
    end

    test "an item \"so far as it amends any enactment which extends to\" the list's place follows the enactment (1992 c.43 s.56(4), (5))" do
      e =
        read(
          "UK_ukpga_1992_43",
          sections([1, 26, 49, 53, 54]) <>
            ExtentDoc.p1("schedule-1-paragraph-1", "Words.") <>
            ExtentDoc.p1("schedule-2-paragraph-1", "Words.") <>
            p2s("section-56", [
              {4,
               "The following provisions of this Act do not extend to Scotland— (a) sections 26 to 36; (b) sections 39 to 47; (c) sections 50 to 52; (d) section 53(2) to (4); and (e) Schedules 1 and 2, so far as they affect any enactment which does not extend to Scotland."},
              {5,
               "The following provisions of this Act extend to Northern Ireland— (a) sections 1 to 10, 49 and 54; (b) subsections (1) to (4), this subsection and, so far as is necessary to give effect to paragraph (c), subsection (6); and (c) Schedule 1, so far as it amends any enactment which extends to Northern Ireland."}
            ])
        )

      refute Enum.any?(unread(e), &(&1 in ["sch.1", "sch.2"]))
      assert ["sch.1", "sch.2"] in same(e)
      refute Enum.any?(lists(e, :named) ++ lists(e, :not), fn {_, refs} -> "sch.1" in refs end)
      assert Extent.of_change(e, ["sch.1.para.3"], nil) == :same
      assert Extent.of_change(e, ["sch.2"], nil) == :same
      assert Extent.of_change(e, ["s.27"], nil) != :same
    end

    test "\"This Act, so far as it gives effect to amendments of [Act], extends to …\": targets by the law amended (1991 c.60 s.4(5)-(7))" do
      e =
        read(
          "UK_ukpga_1991_60",
          ExtentDoc.p1("schedule-1-paragraph-1", "Words.") <>
            p2s("section-4", [
              {3,
               "Subject to subsections (4) to (7) below, this Act extends to England and Wales only."},
              {5,
               "This Act, so far as it gives effect to amendments of the following enactments, that is to say— (a) the Parliamentary Commissioner Act 1967; (b) the House of Commons Disqualification Act 1975; and (c) the Northern Ireland Assembly Disqualification Act 1975, extends to the whole United Kingdom."},
              {6,
               "This Act so far as it gives effect to amendments of the Environmental Protection Act 1990 extends to Great Britain."},
              {7,
               "This Act, so far as it gives effect to the amendments in Schedule 1 to this Act of the following enactments, that is to say— (a) sections 30D(1) and 31(2)(b)(iv) of the Control of Pollution Act 1974; and (b) the Water (Fluoridation) Act 1985, extends to Scotland only."}
            ])
        )

      assert e.default == "E+W"
      assert unread(e) == []

      t = &Enum.find(e.targets, fn x -> x.law == &1 end)

      assert %{kind: :named, place: "E+W+S", scope: "*", refs: ["*"]} =
               t.("Environmental Protection Act 1990")

      assert %{kind: :named, place: "E+W+S+NI", refs: ["*"]} =
               t.("Parliamentary Commissioner Act 1967")

      assert %{kind: :named, place: "E+W+S+NI"} =
               t.("Northern Ireland Assembly Disqualification Act 1975")

      assert %{kind: :only, place: "S", scope: "sch.1", refs: ["s.30D(1)", "s.31(2)(b)(iv)"]} =
               t.("Control of Pollution Act 1974")

      assert %{kind: :only, place: "S", scope: "sch.1", refs: ["*"]} =
               t.("Water (Fluoridation) Act 1985")
    end

    test "\"In this Part of this Act sections … do not extend to Scotland\": those sections (1980 c.65 s.195(3))" do
      e =
        read(
          "UK_ukpga_1980_65",
          sections([1, 8, 180, 181, 182, 183, 185, 186, 190]) <>
            p2s("section-195", [
              {3,
               "In this Part of this Act sections 180, 181, 183, 185, 186 and 190 do not extend to Scotland."}
            ])
        )

      assert unread(e) == []
      assert {"S", ["s.180", "s.181", "s.183", "s.185", "s.186", "s.190"]} in lists(e, :not)
    end

    test "\"so much of … as relates to enactments extending to England and Wales shall extend also to England and Wales\" (1991 c.28 s.28(5))" do
      e =
        read(
          "UK_ukpga_1991_28",
          sections([4, 27]) <>
            ExtentDoc.p1("schedule-2-paragraph-1", "Words.") <>
            ExtentDoc.p1("schedule-10-paragraph-1", "Words.") <>
            ExtentDoc.p1("schedule-11-paragraph-1", "Words.") <>
            p2s("section-28", [
              {4, "Subject to subsection (5) below, this Act extends to Scotland only."},
              {5,
               "Section 4(2) and (4) of this Act and so much of sections 4(10) and 27 of and Schedules 2, 10 and 11 to this Act as relates to enactments extending to England and Wales shall extend also to England and Wales."}
            ])
        )

      assert e.default == "S"
      assert unread(e) == []
      [{"E+W", refs}] = lists(e, :also)
      assert Enum.all?(~w(s.27 sch.2 sch.10 sch.11), &(&1 in refs))
    end
  end

  # Decision 3 (Jason 2026-11-26): the catalogue's three held examples the reader lost
  describe "Decision 3: held examples" do
    test "\"extends to England and Wales and (apart from section 212A(6)) to Scotland\" (1992 c.52 s.301(1))" do
      e =
        read(
          "UK_ukpga_1992_52",
          ExtentDoc.p1("section-212A", "Words.") <>
            p2s("section-301", [
              {1,
               "This Act extends to England and Wales and (apart from section 212A(6)) to Scotland."}
            ])
        )

      assert e.default == "E+W+S"
      assert Extent.of_change(e, ["s.212A(6)"], nil) == "E+W"
      assert Extent.of_change(e, ["s.212A(5)"], nil) == "E+W+S"
    end

    test "\"Sections 93 and 95(6) above apply to Northern Ireland, and Schedule 6 …, so far as it repeals …, but apart from those provisions this Act does not extend to Northern Ireland\" (1981 c.22 s.97(2))" do
      e =
        read(
          "UK_ukpga_1981_22",
          ExtentDoc.p1("section-93", "Words.") <>
            ExtentDoc.p1("section-95", "Words.") <>
            ExtentDoc.p1("schedule-6-paragraph-1", "Words.") <>
            p2s("section-97", [
              {2,
               "Sections 93 and 95(6) above apply to Northern Ireland, and Schedule 6 to this Act, so far as it repeals provisions of the Diseases of Animals Act 1950 which applied to Northern Ireland, but apart from those provisions this Act does not extend to Northern Ireland."}
            ])
        )

      assert e.default == "E+W+S"
      assert Extent.of_change(e, ["s.93"], nil) == "E+W+S+NI"
      assert Extent.of_change(e, ["s.95(6)"], nil) == "E+W+S+NI"
      assert Extent.of_change(e, ["sch.6"], nil) == :same
      assert Extent.of_change(e, ["s.94"], nil) == "E+W+S"
    end

    test "\"Except for the repeals and amendments contained in paragraphs 3 and 4 of Schedule 1, …, which have the same extent as the Acts there repealed and amended, this Act extends to Scotland only\" (1996 c.44 s.14(4))" do
      e =
        read(
          "UK_ukpga_1996_44",
          ExtentDoc.p1("schedule-1-paragraph-3", "Words.") <>
            ExtentDoc.p1("schedule-1-paragraph-4", "Words.") <>
            ExtentDoc.p1("schedule-1-paragraph-5", "Words.") <>
            ExtentDoc.p1("schedule-2-paragraph-1", "Words.") <>
            p2s("section-14", [
              {4,
               "Except for the repeals and amendments contained in paragraphs 3 and 4 of Schedule 1, and the related entries in Schedule 2, to this Act, which have the same extent as the Acts there repealed and amended, this Act extends to Scotland only."}
            ])
        )

      assert e.default == "S"
      assert Extent.of_change(e, ["sch.1.para.3"], nil) == :same
      assert Extent.of_change(e, ["sch.1.para.4(2)"], nil) == :same
      assert Extent.of_change(e, ["sch.1.para.5"], nil) == "S"
      assert Extent.of_change(e, ["sch.2"], nil) == nil
    end
  end
end
