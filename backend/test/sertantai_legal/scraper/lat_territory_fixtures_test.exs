defmodule SertantaiLegal.Scraper.LatTerritoryFixturesTest do
  @moduledoc """
  Territory fixture suite (LAT Parser Refactor, LR-01): one case per
  territory path × source, asserting what the parse gives a reader — row
  `text` (brackets) and `excluded_extent`. Design:
  `docs/LAT-PARSER-REFACTOR-DESIGN.md`; decisions: lat-refactor meta Q1–Q6.

  The rule under test: a change's territory is its `Extent` attribute, else
  its commentary note's territory, else none; both are kept when both exist
  (Q1, union). Cases the parser gets wrong today are tagged
  `pending: "LR-0n"` (excluded by default; `mix test --only pending`), and go
  green in that session. Fixtures are trimmed real CLML where a QA run found
  the case (law and provision in the test name).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatParser

  @law "UK_ukpga_2024_1"

  defp parse(body, notes, extent \\ "E+W+S") do
    """
    <Legislation RestrictExtent="#{extent}"><Primary><Body>#{body}</Body></Primary>
    <Commentaries>#{Enum.join(List.wrap(notes))}</Commentaries></Legislation>
    """
    |> LatParser.parse(%{law_name: @law, type_code: "ukpga"})
    |> Map.new(&{String.replace_prefix(&1.section_id, @law <> ":", ""), &1})
  end

  defp note(id, text),
    do: ~s|<Commentary id="#{id}" Type="F"><Para><Text>#{text}</Text></Para></Commentary>|

  defp section(n, text_xml),
    do:
      ~s|<P1group><Title>T</Title><P1><Pnumber>#{n}</Pnumber><P1para><Text>#{text_xml}</Text></P1para></P1></P1group>|

  defp row(rows, id), do: Map.fetch!(rows, id)

  defp rep_s,
    do:
      note(
        "n-rep-s",
        "Words in s. 1 repealed (S.) (2.8.2005) by Fire (Scotland) Act 2005 (asp 5)"
      )

  defp rep_none,
    do: note("n-rep", "Words in s. 1 repealed (1.4.2010) by Some Act 2010 (c. 1) (with savings)")

  defp ins_ew, do: note("n-ins-ew", "Words in s. 1 inserted (E.W.) (6.4.2010) by S.I. 2010/675")

  defp ins_w,
    do:
      note(
        "n-ins-w",
        "Words in s. 1 inserted (W.) (15.12.2025) by Infrastructure (Wales) Act 2024 (asc 3)"
      )

  defp sub_s, do: note("n-sub-s", "Words in s. 1 substituted (S.) (1.4.2013) by S.S.I. 2013/51")

  defp sub_w,
    do:
      note(
        "n-sub-w",
        "Words in s. 1 substituted (W.) (15.12.2025) by Infrastructure (Wales) Act 2024 (asc 3)"
      )

  defp sub_none, do: note("n-sub", "Words in s. 1 substituted (1.1.2017) by S.I. 2016/1154")

  # ── Words: retained repeal (Repeal RetainText, no SubstitutionRef) ──────

  describe "words repealed but retained" do
    test "attribute territory: bracketed with where they still apply" do
      rows =
        parse(
          section(
            1,
            ~s|A duty <Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S">to report</Repeal> applies.|
          ),
          rep_s()
        )

      assert row(rows, "s.1").text == "A duty [E+W: to report] applies."
    end

    test "note territory (no attribute)" do
      rows =
        parse(
          section(
            1,
            ~s|A duty <Repeal CommentaryRef="n-rep-s" RetainText="true">to report</Repeal> applies.|
          ),
          rep_s()
        )

      assert row(rows, "s.1").text == "A duty [E+W: to report] applies."
    end

    test "no territory: plain (repealed for purposes / with savings)" do
      rows =
        parse(
          section(
            1,
            ~s|A duty <Repeal CommentaryRef="n-rep" RetainText="true">to report</Repeal> applies.|
          ),
          rep_none()
        )

      assert row(rows, "s.1").text == "A duty to report applies."
      assert row(rows, "s.1").excluded_extent == nil
    end
  end

  # ── Words: insertion / substitution for a territory ────────────────────

  describe "words inserted for a territory" do
    test "attribute narrower than the row: bracketed" do
      rows =
        parse(
          section(
            1,
            ~s|The <Addition CommentaryRef="n-ins-ew" Extent="E+W">regulator or the </Addition>council may act.|
          ),
          ins_ew()
        )

      assert row(rows, "s.1").text == "The [E+W: regulator or the] council may act."
    end

    @tag pending: "LR-02"
    test "note territory, no attribute (1990/8 s.150(1)(b) \"or 24ZA(c)\")" do
      rows =
        parse(
          section(
            1,
            ~s|land within paragraph 24(c) <Addition CommentaryRef="n-ins-w">or 24ZA(c)</Addition> of that Schedule|
          ),
          ins_w(),
          "E+W"
        )

      assert row(rows, "s.1").text ==
               "land within paragraph 24(c) [W: or 24ZA(c)] of that Schedule"
    end

    test "attribute covering the row's extent: plain" do
      rows =
        parse(
          section(
            1,
            ~s|The <Addition CommentaryRef="n-ins-ew" Extent="E+W">regulator </Addition>may act.|
          ),
          ins_ew(),
          "E+W"
        )

      assert row(rows, "s.1").text == "The regulator may act."
    end

    test "attribute outside the row's extent: plain" do
      rows =
        parse(
          section(
            1,
            ~s|The <Addition CommentaryRef="n-ins-ew" Extent="E+W">regulator </Addition>may act.|
          ),
          ins_ew(),
          "S"
        )

      assert row(rows, "s.1").text == "The regulator may act."
    end

    test "no territory: plain" do
      rows =
        parse(
          section(1, ~s|The <Addition CommentaryRef="n-sub">regulator </Addition>may act.|),
          sub_none()
        )

      assert row(rows, "s.1").text == "The regulator may act."
    end

    test "one insertion split over two Text blocks reads as one bracket per block" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber>1</Pnumber><P1para><Text><Addition CommentaryRef="n-ins-ew" Extent="E+W">First words.</Addition></Text><Text><Addition CommentaryRef="n-ins-ew" Extent="E+W">Second words.</Addition></Text><Text>Plain.</Text></P1para></P1></P1group>|

      rows = parse(body, ins_ew())
      assert row(rows, "s.1").text == "[E+W: First words. Second words.] Plain."
    end
  end

  # ── Substitution pairs (Repeal SubstitutionRef + partner) ──────────────

  describe "territorial substitution pairs" do
    defp pair(attr_rep, attr_add, ref) do
      section(
        1,
        ~s|be dealt with by <Repeal CommentaryRef="#{ref}" RetainText="true" SubstitutionRef="p1"#{attr_rep}>the fire brigade</Repeal><Addition ChangeId="p1" CommentaryRef="#{ref}"#{attr_add}>the fire and rescue service</Addition> forthwith.|
      )
    end

    test "attribute: both versions, new first" do
      rows = parse(pair(~s| Extent="S"|, ~s| Extent="S"|, "n-sub-s"), sub_s())

      assert row(rows, "s.1").text ==
               "be dealt with by [S: the fire and rescue service] [E+W: the fire brigade] forthwith."
    end

    @tag pending: "LR-02"
    test "note territory, no attributes" do
      rows = parse(pair("", "", "n-sub-s"), sub_s())

      assert row(rows, "s.1").text ==
               "be dealt with by [S: the fire and rescue service] [E+W: the fire brigade] forthwith."
    end

    test "no territory: both versions, apart and unbracketed" do
      rows = parse(pair("", "", "n-sub"), sub_none())

      assert row(rows, "s.1").text ==
               "be dealt with by the fire brigade the fire and rescue service forthwith."
    end

    test "covering the row's extent: only the new words" do
      rows = parse(pair(~s| Extent="E+W+S"|, ~s| Extent="E+W+S"|, "n-sub-s"), sub_s())
      assert row(rows, "s.1").text == "be dealt with by the fire and rescue service forthwith."
    end

    @tag pending: "LR-02"
    test "halves not siblings (each wrapped in an earlier insertion): 1990/8 s.150(1)(b)" do
      body =
        section(
          1,
          ~s|within paragraph 22 <Addition CommentaryRef="n-old"><Repeal CommentaryRef="n-sub-w" RetainText="true" SubstitutionRef="p2" Extent="W">or paragraph 24</Repeal></Addition> <Addition CommentaryRef="n-old"><Addition ChangeId="p2" CommentaryRef="n-sub-w" Extent="W">, paragraph 24 or paragraph 24ZA</Addition></Addition> of Schedule 13|
        )

      rows =
        parse(
          body,
          [
            sub_w(),
            note(
              "n-old",
              "Words in s. 1 inserted (25.9.1991) by Planning and Compensation Act 1991 (c. 34)"
            )
          ],
          "E+W"
        )

      assert row(rows, "s.1").text ==
               "within paragraph 22 [W: , paragraph 24 or paragraph 24ZA] [E: or paragraph 24] of Schedule 13"
    end
  end

  # ── Nested changes ─────────────────────────────────────────────────────

  describe "nested changes" do
    @tag pending: "LR-02"
    test "a repeal for S around a substitution for E+W: the old words are live nowhere (1968/73 s.102(4))" do
      body =
        section(
          1,
          ~s|used for police <Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S">or </Repeal><Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S"><Repeal CommentaryRef="n-sub-ew" RetainText="true" SubstitutionRef="p3" Extent="E+W">fire brigade</Repeal></Repeal> <Addition ChangeId="p3" CommentaryRef="n-sub-ew" Extent="E+W">fire and rescue authority</Addition> purposes|
        )

      rows =
        parse(body, [
          rep_s(),
          note(
            "n-sub-ew",
            "Words in s. 1 substituted (E.W.) (1.10.2004) by Fire and Rescue Services Act 2004 (c. 21)"
          )
        ])

      assert row(rows, "s.1").text ==
               "used for police [E+W: or fire and rescue authority] purposes"
    end

    test "an insertion inside words retained for E+W: one bracket (the insertion is within the live territory)" do
      body =
        section(
          1,
          ~s|A <Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S">duty <Addition CommentaryRef="n-ins-ew" Extent="E+W">to report </Addition>promptly</Repeal> applies.|
        )

      rows = parse(body, [rep_s(), ins_ew()])
      assert row(rows, "s.1").text == "A [E+W: duty to report promptly] applies."
    end

    @tag pending: "LR-02"
    test "a narrower insertion inside a wider one keeps its own bracket" do
      body =
        section(
          1,
          ~s|The <Addition CommentaryRef="n-ins-ew" Extent="E+W">regulator <Addition CommentaryRef="n-ins-e" Extent="E">or the Agency </Addition>or the </Addition>council may act.|
        )

      rows =
        parse(body, [
          ins_ew(),
          note("n-ins-e", "Words in s. 1 inserted (E.) (1.4.2013) by S.I. 2013/755")
        ])

      assert row(rows, "s.1").text ==
               "The [E+W: regulator [E: or the Agency] or the] council may act."
    end
  end

  # ── Whole row: plain text + excluded_extent ────────────────────────────

  describe "whole-row territorial changes" do
    defp whole_retained(attr, ref) do
      ~s|<P1group><Title>T</Title><P1><Pnumber><Repeal CommentaryRef="#{ref}" RetainText="true"#{attr}>3</Repeal></Pnumber><P1para><Text><Repeal CommentaryRef="#{ref}" RetainText="true"#{attr}>The sludge shall be tested.</Repeal></Text></P1para></P1></P1group>|
    end

    test "retained for some territories (attribute)" do
      rows = parse(whole_retained(~s| Extent="S"|, "n-rep-s"), rep_s())

      assert %{text: "The sludge shall be tested.", excluded_extent: "S", status: "in_force"} =
               row(rows, "s.3")
    end

    test "retained for some territories (note)" do
      rows = parse(whole_retained("", "n-rep-s"), rep_s())
      assert %{text: "The sludge shall be tested.", excluded_extent: "S"} = row(rows, "s.3")
    end

    test "retained for no territory: the whole extent, repealed_saved" do
      rows = parse(whole_retained("", "n-rep"), rep_none())
      assert %{excluded_extent: "E+W+S", status: "repealed_saved"} = row(rows, "s.3")
    end

    test "inserted for a narrower territory (attribute): 1990/43 s.88B" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><Addition CommentaryRef="n-ins-e" Extent="E">88B</Addition></Pnumber><P1para><Text><Addition CommentaryRef="n-ins-e" Extent="E">A new duty.</Addition></Text></P1para></P1></P1group>|

      rows =
        parse(body, note("n-ins-e", "S. 88B inserted (E.) (1.4.2013) by S.I. 2013/755"), "E+W")

      assert %{text: "A new duty.", excluded_extent: "W"} = row(rows, "s.88B")
    end

    @tag pending: "LR-02"
    test "inserted for a narrower territory (note only): 1990/8 s.202D, the section and its subsections" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><Addition CommentaryRef="n-202">202D</Addition></Pnumber><P1para><P2><Pnumber><Addition CommentaryRef="n-202">1</Addition></Pnumber><P2para><Text><Addition CommentaryRef="n-202">This section applies if regulations so provide.</Addition></Text></P2para></P2></P1para></P1></P1group>|

      rows =
        parse(
          body,
          note("n-202", "Ss. 202A-202G inserted (6.4.2012 for E.) by Planning Act 2008 (c. 29)"),
          "E+W"
        )

      assert row(rows, "s.202D(1)").excluded_extent == "W"
      assert row(rows, "s.202D(1)").text == "This section applies if regulations so provide."
    end

    @tag pending: "LR-02"
    test "a Part inserted for W (note only): 2010/2214 Pt. 2B" do
      body =
        ~s|<Part><Number>PART 2B</Number><Title>Wales</Title><P1group><Title>T</Title><P1><Pnumber><Addition CommentaryRef="n-2b">11U</Addition></Pnumber><P1para><Text><Addition CommentaryRef="n-2b">In this regulation, a duty.</Addition></Text></P1para></P1></P1group></Part>|

      rows = parse(body, note("n-2b", "Pt. 2B inserted (W.) (1.7.2026) by S.I. 2025/1320"), "E+W")
      assert row(rows, "s.11U").excluded_extent == "E"
    end

    @tag pending: "LR-02"
    test "retained for E+W with an inner E+W insertion: plain + excluded (Q3; 1974/40 s.30(5))" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber>30</Pnumber><P1para><P2><Pnumber><Repeal CommentaryRef="n-30" RetainText="true">5</Repeal></Pnumber><P2para><Text><Repeal CommentaryRef="n-30" RetainText="true">Nothing applies to waste within the meaning of </Repeal><Repeal CommentaryRef="n-30" RetainText="true"><Addition CommentaryRef="n-ins-ew" Extent="E+W">Schedule 23 to the 2016 Regulations</Addition></Repeal><Repeal CommentaryRef="n-30" RetainText="true">; but regulations may—</Repeal></Text></P2para></P2></P1para></P1></P1group>|

      rows =
        parse(body, [
          note(
            "n-30",
            "S. 30 repealed (1.4.2015 for S.) by Environmental Protection Act 1990 (c. 43)"
          ),
          ins_ew()
        ])

      assert %{
               text:
                 "Nothing applies to waste within the meaning of Schedule 23 to the 2016 Regulations; but regulations may—",
               excluded_extent: "S"
             } = row(rows, "s.30(5)")
    end

    @tag pending: "LR-02"
    test "attribute and note both name territories: union (Q1; 1996/1527 reg.16(1))" do
      body = whole_retained(~s| Extent="S"|, "n-disapp")

      notes =
        note(
          "n-disapp",
          "Regulations disapplied in relation to Scotland (with effect from 1.4.2015) by virtue of Scotland Act 2012 (c. 11); S.I. 2015/638 Regulations disapplied in relation to Wales (with effect from 1.4.2018) by virtue of Wales Act 2014 (c. 29); S.I. 2018/214"
        )

      rows = parse(body, notes, "E+W+S+NI")
      assert row(rows, "s.3").excluded_extent == "W+S"
    end

    test "a signature whose parts are retained-repealed for S (1989/1263 signed.72)" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber>1</Pnumber><P1para><Text>A duty.</Text></P1para></P1></P1group><SignedSection><Signatory><Signee><PersonName><Repeal CommentaryRef="n-rev-s" RetainText="true">Jane Smith</Repeal></PersonName><JobTitle><Repeal CommentaryRef="n-rev-s" RetainText="true">Minister of State</Repeal></JobTitle><DateSigned Date="1989-07-01"/></Signee></Signatory></SignedSection>|

      rows =
        parse(body, note("n-rev-s", "Regulations revoked (S.) (1.11.2025) by S.S.I. 2025/165"))

      signed = rows |> Enum.find(fn {id, _} -> String.starts_with?(id, "signed") end) |> elem(1)
      assert signed.excluded_extent == "S"
      assert signed.text =~ "Jane Smith, Minister of State"
    end

    test "a prospective row repealed for S keeps prospective" do
      body =
        ~s|<P1group><Title>T</Title><P1 Status="Prospective"><Pnumber><Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S">3</Repeal></Pnumber><P1para><Text><Repeal CommentaryRef="n-rep-s" RetainText="true" Extent="S">The sludge shall be tested.</Repeal></Text></P1para></P1></P1group>|

      rows = parse(body, rep_s())
      assert %{excluded_extent: "S", status: "prospective"} = row(rows, "s.3")
    end
  end

  # ── Note-only changes (no element carries the change) ──────────────────

  describe "note-only whole-provision changes" do
    @tag pending: "LR-03"
    test "a section repealed for S by a note in its number only: 1974/40 s.101" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><CommentaryRef Ref="n-101"/>101</Pnumber><P1para><Text>The Authority shall have power—</Text><P3><Pnumber>a</Pnumber><P3para><Text>to engage in activities.</Text></P3para></P3></P1para></P1></P1group>|

      rows =
        parse(
          body,
          note(
            "n-101",
            "S. 101 repealed (S.) (30.6.2014) by Regulatory Reform (Scotland) Act 2014 (asp 3)"
          )
        )

      assert row(rows, "s.101").excluded_extent == "S"
      assert row(rows, "s.101(a)").excluded_extent == "S"
    end

    @tag pending: "LR-03"
    test "a note-only repeal adds to an element repeal for other territories: 1993/12 s.18" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><CommentaryRef Ref="n-1-24"/><Repeal CommentaryRef="n-18" RetainText="true" Extent="E+W">18</Repeal></Pnumber><P1para><P2><Pnumber><Repeal CommentaryRef="n-18" RetainText="true" Extent="E+W">2</Repeal></Pnumber><P2para><Text><Repeal CommentaryRef="n-18" RetainText="true" Extent="E+W">Where an authority take precautions, it may charge.</Repeal></Text></P2para></P2></P1para></P1></P1group>|

      notes = [
        note(
          "n-1-24",
          "Ss. 1-24 repealed (S.) (1.9.2018) by The Environmental Authorisations (Scotland) Regulations 2018 (S.S.I. 2018/219)"
        ),
        note("n-18", "S. 18 repealed (E.W.) (6.4.2010) by S.I. 2010/675")
      ]

      rows = parse(body, notes, "E+W+S+NI")
      assert row(rows, "s.18(2)").excluded_extent == "E+W+S"
    end

    test "a note about words only (\"Words in s. N repealed (S.)\") never excludes the row" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><CommentaryRef Ref="n-rep-s"/>1</Pnumber><P1para><Text>A duty applies.</Text></P1para></P1></P1group>|

      rows = parse(body, rep_s())
      assert row(rows, "s.1").excluded_extent == nil
    end

    @tag pending: "LR-03"
    test "a Part repeal \"except in relation to ss. 13-15\" doesn't touch s.13 (Q2; 1984/22)" do
      n =
        "Pt. II repealed (6.4.2010 for E. except in relation to ss. 13-15, 26.7.2010 for W. except in relation to ss. 13-15) by Health and Social Care Act 2008 (c. 14)"

      body =
        ~s|<Part><Number>Part II</Number><Title>T</Title><P1group><Title>T</Title><P1><Pnumber><Repeal CommentaryRef="n-pt2" RetainText="true">13</Repeal></Pnumber><P1para><Text><Repeal CommentaryRef="n-pt2" RetainText="true">Regulations may provide for diseases.</Repeal></Text></P1para></P1></P1group><P1group><Title>T</Title><P1><Pnumber><Repeal CommentaryRef="n-pt2" RetainText="true">20</Repeal></Pnumber><P1para><Text><Repeal CommentaryRef="n-pt2" RetainText="true">A duty to notify.</Repeal></Text></P1para></P1></P1group></Part>|

      rows = parse(body, note("n-pt2", n), "E+W")
      assert %{excluded_extent: nil, status: "in_force"} = row(rows, "s.13")
      assert %{excluded_extent: "E+W", status: "repealed_saved"} = row(rows, "s.20")
    end
  end
end
