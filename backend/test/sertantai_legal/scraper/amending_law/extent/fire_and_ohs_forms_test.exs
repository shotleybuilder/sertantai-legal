defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.FireAndOhsFormsTest do
  @moduledoc """
  Extent wordings read for Fire and OH&S: Extent reader (2026-11-14), each
  on its law's real wording: a same-extent statement with its exceptions.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Patterns, ReadCache, Rows}

  # the whole reading: the statements read, and the bounds the unread withhold
  defp read(law, body), do: ReadCache.read(ExtentDoc.doc(law, body))

  defp p2s(id, subs) do
    inner =
      Enum.map_join(subs, fn {k, t} ->
        ~s|<P2 id="#{id}-#{k}"><P2para><Text>#{t}</Text></P2para></P2>|
      end)

    ~s|<P1 id="#{id}"><P1para>#{inner}</P1para></P1>|
  end

  defp paragraphs(sch, ns),
    do: Enum.map_join(ns, &ExtentDoc.p1("schedule-#{sch}-paragraph-#{&1}", "Words."))

  defp same(e), do: for({:same, nil, refs} <- e.lists, do: refs)
  defp unread(e), do: for({:unread, nil, refs} <- e.lists, r <- refs, do: r)

  describe "an exception naming the provisions amended (Energy Act 2016 s.85; Decision 1, 2026-11-14)" do
    setup do
      e =
        read(
          "UK_ukpga_2016_20",
          ExtentDoc.p1("section-73", "Words.") <>
            ExtentDoc.p1(
              "section-74",
              "Part 1A of the Petroleum Act 1998 (maximising economic recovery of UK petroleum), as amended by this Act, extends to Northern Ireland (as well as to England and Wales and Scotland)."
            ) <>
            p2s("section-85", [
              {1, "This Act may be cited as the Energy Act 2016."},
              {2,
               "An amendment (other than an amendment of Part 1A of the Petroleum Act 1998) or repeal made by this Act has the same extent as the provision to which it relates."},
              {3,
               "Subject to subsection (2), this Act extends to the whole of the United Kingdom."}
            ])
        )

      %{e: e}
    end

    test "every amendment the same extent; the excepted target the default", %{e: e} do
      assert e.default == "E+W+S+NI"
      assert same(e) == [["*"]]
      assert unread(e) == []

      assert e.targets == [
               %{
                 kind: :only,
                 place: "E+W+S+NI",
                 scope: "*",
                 law: "Petroleum Act 1998",
                 refs: ["pt.1A"]
               }
             ]
    end

    test "a change by its own target: in Part 1A the default, elsewhere the same", %{e: e} do
      pa = &Map.merge(%{law: "UK_ukpga_1998_17", title: "Petroleum Act 1998"}, &1)

      assert Extent.of_change(e, ["s.73"], pa.(%{target: "pt.1A"})) == "E+W+S+NI"

      assert Extent.of_change(e, ["s.73"], pa.(%{target: "s.9A(2)", within: ["pt.1A"]})) ==
               "E+W+S+NI"

      assert Extent.of_change(e, ["s.73"], pa.(%{target: "s.15(2)", within: ["pt.2"]})) == :same
      assert Extent.of_change(e, ["s.73"], pa.(%{target: "s.15(2)", within: []})) == :same

      # another law's Part 1A is none of it
      assert Extent.of_change(e, ["s.73"], %{
               law: "UK_ukpga_2008_32",
               title: "Energy Act 2008",
               target: "s.9A",
               within: ["pt.1A"]
             }) == :same

      # no change named: the amending provision's own bound
      assert Extent.of_change(e, ["s.73"]) == :same
    end

    test "a target whose Part isn't known is unknown, never the same", %{e: e} do
      change = %{law: "UK_ukpga_1998_17", title: "Petroleum Act 1998", target: "s.9A(2)"}
      assert Extent.of_change(e, ["s.73"], change) == nil
    end

    test "kept through the rules store", %{e: e} do
      back = e |> Extent.to_rows("UK_ukpga_2016_20") |> Rows.from_rows()
      assert back.targets == e.targets
      assert {:same, nil, ["*"]} in back.lists
    end

    test "any other naming of another Act's provisions, or no default, stays unread" do
      # an exception that is no amendment of the Act named
      other =
        read(
          "UK_ukpga_2016_20",
          p2s("section-85", [
            {2,
             "An amendment (other than one made under section 5 of the Energy Act 2008) or repeal made by this Act has the same extent as the provision to which it relates."},
            {3, "Subject to subsection (2), this Act extends to the whole of the United Kingdom."}
          ])
        )

      # no default for the excepted to take (Justice (Northern Ireland) Act 2002 s.91(3))
      no_default =
        read(
          "UK_ukpga_2002_26",
          p2s("section-91", [
            {3,
             "Any amendment made by this Act, apart from the repeal of sections 4 and 6 of the Promissory Oaths Act 1868 (c. 72), has the same extent as the provision to which it relates."}
          ])
        )

      for e <- [other, no_default] do
        assert same(e) == []
        assert e.targets == []
        assert "*" in unread(e)
      end
    end
  end

  describe "lettered exceptions to the same extent" do
    test "one qualified item is withheld alone (SI 2014/469 art.3(5))" do
      e =
        read(
          "UK_uksi_2014_469",
          p2s("article-3", [
            {1,
             "Subject to paragraphs (2) to (5), this Order extends to England and Wales, Scotland and Northern Ireland."},
            {5,
             "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that—a the amendments made by paragraphs 164 to 176 of that Schedule, in so far as they make provision for ONR inquiries, extend to England and Wales, Scotland and Northern Ireland;b the amendments made by paragraph 178 of that Schedule, extend to Scotland only;c the amendments made by paragraphs 182(2) and (4) and 187 to 189 of that Schedule apply in relation to England only;d the amendments made by paragraph 182(3) and (5) apply in relation to Wales only."}
          ]) <> paragraphs(3, [1, 164, 170, 176, 178, 182, 187, 189])
        )

      assert same(e) == [["sch.3"]]
      assert unread(e) == ["sch.3.para.164..sch.3.para.176"]
      assert [{:only, "S", ["sch.3.para.178"]}] == for({:only, _, _} = l <- e.lists, do: l)

      assert Extent.of(e, "sch.3.para.1") == :same
      assert Extent.of(e, "sch.3.para.170") == nil
      assert Extent.of(e, "sch.3.para.178") == "S"
      assert Extent.of(e, "sch.3.para.182(2)") == :same
      assert Extent.application_at(e, ["sch.3.para.182(2)"]) == "E"
      assert Extent.application_at(e, ["sch.3.para.182(3)"]) == "W"
    end

    test "every item plain; a bracket naming another Act is a description (SI 2019/742 reg.2)" do
      doc =
        ExtentDoc.doc(
          "UK_uksi_2019_742",
          p2s("regulation-2", [
            {1,
             "Subject to paragraphs (2) and (3), these Regulations extend to England and Wales, Scotland and Northern Ireland."},
            {2,
             "Any amendment, repeal or revocation made by these Regulations has the same extent within the United Kingdom as the provision to which it relates, except that—a regulation 107(5) (amendment of the Proceeds of Crime Act 2002) extends to England and Wales and Scotland only;b regulation 107(8) extends to England and Wales only, andc regulation 109(1) to (3) (amendment of the Criminal Finances Act 2017) extends to Northern Ireland only."},
            {3,
             "Any saving or transitional provision in these Regulations has the same extent within the United Kingdom as the provision to which it relates, except that regulation 72 (saving provision – investigation teams operating in the UK after commencement day) extends to England and Wales, Scotland and Northern Ireland."}
          ]) <>
            Enum.map_join([5, 72, 107, 109], &ExtentDoc.p1("regulation-#{&1}", "Words."))
        )

      e = ReadCache.read(doc)

      assert same(e) == [["*"]]
      # (the savings' statement speaks of no amendment: it withholds none)
      assert unread(e) == []

      assert Enum.sort(for({:only, _, _} = l <- e.lists, do: l)) == [
               {:only, "E+W", ["reg.107(8)"]},
               {:only, "E+W+S", ["reg.107(5)"]},
               {:only, "NI", ["reg.109(1)", "reg.109(2)", "reg.109(3)"]}
             ]

      assert Extent.of(e, "reg.5") == :same
      assert Extent.of(e, "reg.107(5)") == "E+W+S"
      assert Extent.of(e, "reg.107(8)") == "E+W"
      assert Extent.of(e, "reg.109(2)") == "NI"

      assert Enum.any?(
               Patterns.classes(doc, e),
               &match?({"reg.2", "Any amendment, repeal" <> _, "list:same:same"}, &1)
             )
    end

    test "an item not read leaves the whole subject unread" do
      e =
        read(
          "UK_uksi_2014_469",
          p2s("article-3", [
            {1, "This Order extends to England and Wales, Scotland and Northern Ireland."},
            {5,
             "The amendments made by Schedule 3 have the same extent as the provisions which they amend, except that—a nothing in that Schedule affects the law of Scotland;b the amendments made by paragraph 178 of that Schedule extend to Scotland only."}
          ]) <> paragraphs(3, [1, 178])
        )

      assert same(e) == []
      assert "sch.3" in unread(e)
    end
  end

  test "\"The extent of the amendments and repeals in Schedule 43 is the same as the provision amended or repealed\" (Finance Act 2008 s.129)" do
    doc =
      ExtentDoc.doc(
        "UK_ukpga_2008_9",
        ExtentDoc.p1("section-127", "This section extends to England and Wales only.") <>
          ExtentDoc.p1(
            "section-129",
            "The extent of the amendments and repeals in Schedule 43 is the same as the provision amended or repealed."
          ) <> paragraphs(43, [1])
      )

    e = ReadCache.read(doc)
    assert same(e) == [["sch.43"]]
    assert Extent.of(e, "sch.43.para.1") == :same

    assert {"s.129",
            "The extent of the amendments and repeals in Schedule 43 is the same as the provision amended or repealed.",
            "list:same:same"} in Patterns.classes(doc, e)
  end

  describe "a Schedule's other paragraphs (Policing and Crime Act 2017 s.182)" do
    defp policing(extra \\ "") do
      read(
        "UK_ukpga_2017_3",
        ExtentDoc.p1("section-6", "Schedule 1 (provision about collaboration) has effect.") <>
          ExtentDoc.p1("section-45", "Schedule 12 (minor amendments) has effect.") <>
          p2s("section-182", [
            {1,
             "Except as provided by subsections (2) to (6), this Act extends only to England and Wales."},
            {2,
             "The following provisions extend to England and Wales, Scotland and Northern Ireland—a section 6, so far as relating to paragraphs 81, 95 and 96 of Schedule 1, and those paragraphs;b section 8(11);c section 45, so far as relating to paragraphs 6, 13 and 14 of Schedule 12, and those paragraphs#{extra}."},
            {3,
             "The following provisions extend to England and Wales and Scotland—a section 6, so far as relating to paragraphs 11 and 14 of Schedule 1, and those paragraphs;b section 7(8)."}
          ]) <>
          paragraphs(1, [2, 5, 11, 14, 81, 95, 96]) <> paragraphs(12, [1, 6, 13, 14])
      )
    end

    test "a paragraph named in no list takes the law's default; the section stays withheld" do
      e = policing()
      assert e.default == "E+W"
      assert Extent.of(e, "s.6") == nil
      assert Extent.of(e, "sch.1.para.2") == "E+W"
      assert Extent.of(e, "sch.1.para.5(3)") == "E+W"
      assert Extent.of(e, "sch.12.para.1") == "E+W"
      # the paragraphs named keep their lists
      assert Extent.of(e, "sch.1.para.81") == "E+W+S+NI"
      assert Extent.of(e, "sch.1.para.11") == "E+W+S"
      assert Extent.of(e, "sch.12.para.6") == "E+W+S+NI"
      # the Schedule whole is of mixed extent: no bound
      assert Extent.of(e, "sch.1") == nil
      assert {:only, "E+W", ["sch.1.para.2", "sch.1.para.5"]} in e.lists
      assert {:only, "E+W", ["sch.12.para.1"]} in e.lists
    end

    test "survives the stored rows" do
      e = policing()
      back = e |> Rows.to_rows("UK_ukpga_2017_3") |> Rows.from_rows()
      assert Extent.of(back, "sch.1.para.2") == "E+W"
      assert Extent.of(back, "s.6") == nil
    end

    test "a section qualified any other way keeps its Schedule withheld" do
      e =
        policing(
          ";d section 45, so far as relating to the inserted section 50A of the Police Act 1996"
        )

      assert Extent.of(e, "sch.12.para.1") == nil
      assert Extent.of(e, "sch.1.para.2") == "E+W"
    end
  end

  describe "a provision partly excepted in a list that narrows (Energy Act 2004 s.198; Decision 3's reading)" do
    setup do
      e =
        read(
          "UK_ukpga_2004_20",
          ~s(<Part id="part-3">) <>
            ExtentDoc.p1("section-150", "Words.") <>
            p2s("section-151", for(n <- 1..6, do: {n, "Words."})) <>
            ExtentDoc.p1("section-152", "Words.") <>
            "</Part>" <>
            ~s(<Part id="part-4">) <>
            p2s("section-198", [
              {3,
               "Subject to subsection (4) of this section, this Act extends to Northern Ireland."},
              {4,
               "The following provisions of this Act do not extend to Northern Ireland—a sections 82, 90, 91 and 100; andb Part 3 (with the exception of section 151(5))."}
            ]) <> "</Part>"
        )

      %{e: e}
    end

    test "its other subsections are in the list; the excepted keeps the default", %{e: e} do
      assert e.default == "E+W+S+NI"
      # the provision cited whole is of mixed extent: no bound
      assert unread(e) == ["s.151"]
      assert Extent.of(e, "s.151") == nil
      assert Extent.of(e, "s.151(5)(a)") == "E+W+S+NI"

      assert {:not, "NI",
              [
                "s.82",
                "s.90",
                "s.91",
                "s.100",
                "s.150",
                "s.152",
                "s.151(1)",
                "s.151(2)",
                "s.151(3)",
                "s.151(4)",
                "s.151(6)"
              ]} in e.lists

      assert Extent.of(e, "s.151(2)") == "E+W+S"
      assert Extent.of(e, "s.151(3)(a)") == "E+W+S"
      assert Extent.of(e, "s.151(5)") == "E+W+S+NI"
      assert Extent.of(e, "s.150") == "E+W+S"
    end
  end
end
