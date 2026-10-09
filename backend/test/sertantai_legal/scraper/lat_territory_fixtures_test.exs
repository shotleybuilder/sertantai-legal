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

  defp parse(body, notes, extent \\ "E+W+S", effects \\ []) do
    """
    <Legislation RestrictExtent="#{extent}"><Primary><Body>#{body}</Body></Primary>
    <Commentaries>#{Enum.join(List.wrap(notes))}</Commentaries></Legislation>
    """
    |> LatParser.parse(%{law_name: @law, type_code: "ukpga", effects: effects})
    |> Map.new(&{String.replace_prefix(&1.section_id, @law <> ":", ""), &1})
  end

  defp note(id, text),
    do: ~s|<Commentary id="#{id}" Type="F"><Para><Text>#{text}</Text></Para></Commentary>|

  defp section(n, text_xml),
    do:
      ~s|<P1group><Title>T</Title><P1><Pnumber>#{n}</Pnumber><P1para><Text>#{text_xml}</Text></P1para></P1></P1group>|

  defp row(rows, id), do: Map.fetch!(rows, id)

  # An effect from legislation.gov.uk's changes feed (LR-03), fields as in the
  # real records named in each test; ids scrubbed (push protection).
  defp fx(fields) do
    struct!(
      SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect,
      Keyword.merge(
        [
          type: "words inserted",
          affecting: "UK_x",
          applied: true,
          affected_refs: [],
          affected_ranges: []
        ],
        fields
      )
    )
  end

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

    test "effect territory, no attribute: a repeal by a Scottish Act extends only to S" do
      rows =
        parse(
          section(
            1,
            ~s|A duty <Repeal ChangeId="key-rs-1" RetainText="true">to report</Repeal> applies.|
          ),
          [],
          "E+W+S",
          [
            fx(
              effect_id: "key-rs",
              type: "words repealed",
              effect_extent: "S",
              affected_extent: "E+W+S"
            )
          ]
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

    test "effect territorial application, no attribute (1990/8 s.150(1)(b) \"or 24ZA(c)\")" do
      rows =
        parse(
          section(
            1,
            ~s|land within paragraph 24(c) <Addition ChangeId="key-w-1">or 24ZA(c)</Addition> of that Schedule|
          ),
          [],
          "E+W",
          [fx(effect_id: "key-w", territorial_application: "W", effect_extent: "E+W")]
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

    test "effect territory, no attributes" do
      body =
        section(
          1,
          ~s|be dealt with by <Repeal ChangeId="key-sub-1" RetainText="true" SubstitutionRef="p1">the fire brigade</Repeal><Addition ChangeId="p1">the fire and rescue service</Addition> forthwith.|
        )

      rows =
        parse(body, [], "E+W+S", [
          fx(effect_id: "key-sub", type: "words substituted", territorial_application: "S")
        ])

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

    test "retained for some territories (effect extent)" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><Repeal ChangeId="key-r3-1" RetainText="true">3</Repeal></Pnumber><P1para><Text><Repeal ChangeId="key-r3-1" RetainText="true">The sludge shall be tested.</Repeal></Text></P1para></P1></P1group>|

      rows =
        parse(body, [], "E+W+S", [
          fx(effect_id: "key-r3", type: "repealed", effect_extent: "S", affected_extent: "E+W+S")
        ])

      assert %{text: "The sludge shall be tested.", excluded_extent: "S"} = row(rows, "s.3")
    end

    @tag pending: "LR-07"
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

    test "inserted \"(6.4.2012 for E.)\" is commencement, not territory: no exclusion (1990/8 s.202D; note typology §2.3)" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><Addition CommentaryRef="n-202">202D</Addition></Pnumber><P1para><P2><Pnumber><Addition CommentaryRef="n-202">1</Addition></Pnumber><P2para><Text><Addition CommentaryRef="n-202">This section applies if regulations so provide.</Addition></Text></P2para></P2></P1para></P1></P1group>|

      rows =
        parse(
          body,
          note("n-202", "Ss. 202A-202G inserted (6.4.2012 for E.) by Planning Act 2008 (c. 29)"),
          "E+W"
        )

      assert row(rows, "s.202D(1)").excluded_extent == nil
      assert row(rows, "s.202D(1)").text == "This section applies if regulations so provide."
    end

    test "a Part inserted for W (effect territorial application): 2010/2214 Pt. 2B" do
      body =
        ~s|<Part><Number>PART 2B</Number><Title>Wales</Title><P1group><Title>T</Title><P1><Pnumber><Addition ChangeId="key-2b-1">11U</Addition></Pnumber><P1para><Text><Addition ChangeId="key-2b-1">In this regulation, a duty.</Addition></Text></P1para></P1></P1group></Part>|

      rows =
        parse(body, [], "E+W", [
          fx(
            effect_id: "key-2b",
            type: "inserted",
            territorial_application: "W",
            effect_extent: "E+W",
            affected_refs: ["part-2B"]
          )
        ])

      assert row(rows, "s.11U").excluded_extent == "E"
    end

    test "retained for E+W with an inner E+W insertion: plain + excluded (Q3; 1974/40 s.30(5): repeal in force \"for S.\")" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber>30</Pnumber><P1para><P2><Pnumber><Repeal ChangeId="key-30-1" RetainText="true">5</Repeal></Pnumber><P2para><Text><Repeal ChangeId="key-30-1" RetainText="true">Nothing applies to waste within the meaning of </Repeal><Repeal ChangeId="key-30-1" RetainText="true"><Addition Extent="E+W">Schedule 23 to the 2016 Regulations</Addition></Repeal><Repeal ChangeId="key-30-1" RetainText="true">; but regulations may—</Repeal></Text></P2para></P2></P1para></P1></P1group>|

      rows =
        parse(body, [], "E+W+S", [
          fx(
            effect_id: "key-30",
            type: "repealed",
            effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D",
            affected_extent: "E+W+S",
            in_force_qualifications: ["for S."]
          )
        ])

      assert %{
               text:
                 "Nothing applies to waste within the meaning of Schedule 23 to the 2016 Regulations; but regulations may—",
               excluded_extent: "S"
             } = row(rows, "s.30(5)")
    end

    test "known gap: the Wales disapplication can't be joined to the change (1996/1527 reg.16(1)) — markup S only" do
      # the Repeal's ChangeId is not an effect id; the Wales effect ("disapplied
      # in relation to Wales") has no territorial application: effects can't
      # supply W, notes are never read
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><Repeal ChangeId="M_F_x" RetainText="true" Extent="S">3</Repeal></Pnumber><P1para><Text><Repeal ChangeId="M_F_x" RetainText="true" Extent="S">The sludge shall be tested.</Repeal></Text></P1para></P1></P1group>|

      rows =
        parse(body, [], "E+W+S+NI", [
          fx(
            effect_id: "key-w",
            type: "disapplied in relation to Wales",
            effect_extent: "E+W+S+N.I."
          )
        ])

      assert row(rows, "s.3").excluded_extent == "S"
    end

    test "a signature whose parts are retained-repealed for S (1989/1263 signed.72)" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber>1</Pnumber><P1para><Text>A duty.</Text></P1para></P1></P1group><SignedSection><Signatory><Signee><PersonName><Repeal ChangeId="key-rev-1" RetainText="true">Jane Smith</Repeal></PersonName><JobTitle><Repeal ChangeId="key-rev-1" RetainText="true">Minister of State</Repeal></JobTitle><DateSigned Date="1989-07-01"/></Signee></Signatory></SignedSection>|

      rows =
        parse(body, [], "E+W+S", [
          fx(effect_id: "key-rev", type: "revoked", effect_extent: "S", affected_extent: "E+W+S")
        ])

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
    test "rule 3: a whole section repealed for S, no change markup (1974/40 s.101)" do
      body =
        ~s|<P1group><Title>T</Title><P1 id="section-101"><Pnumber>101</Pnumber><P1para><Text>The Authority shall have power—</Text><P3 id="section-101-a"><Pnumber>a</Pnumber><P3para><Text>to engage in activities.</Text></P3para></P3></P1para></P1></P1group>|

      rows =
        parse(body, [], "E+W+S+NI", [
          fx(
            effect_id: "key-101",
            type: "repealed",
            effect_extent: "S",
            affected_extent: "E+W+S+N.I.",
            affected_refs: ["section-101"]
          )
        ])

      assert row(rows, "s.101").excluded_extent == "S"
      assert row(rows, "s.101(a)").excluded_extent == "S"
    end

    test "rule 3 doesn't apply where the provision carries markup (agreed): 1993/12 s.18 keeps E+W — the ss. 1-24 S repeal is a recorded gap" do
      body =
        ~s|<P1group><Title>T</Title><P1 id="section-18"><Pnumber><Repeal ChangeId="key-18-1" RetainText="true" Extent="E+W">18</Repeal></Pnumber><P1para><P2 id="section-18-2"><Pnumber><Repeal ChangeId="key-18-1" RetainText="true" Extent="E+W">2</Repeal></Pnumber><P2para><Text><Repeal ChangeId="key-18-1" RetainText="true" Extent="E+W">Where an authority take precautions, it may charge.</Repeal></Text></P2para></P2></P1para></P1></P1group>|

      rows =
        parse(body, [], "E+W+S+NI", [
          fx(
            effect_id: "key-1-24",
            type: "repealed",
            effect_extent: "S",
            affected_extent: "E+W+S+N.I.",
            affected_ranges: [{"section-1", "section-24"}]
          ),
          fx(effect_id: "key-18", type: "repealed", effect_extent: "E+W")
        ])

      assert row(rows, "s.18(2)").excluded_extent == "E+W"
    end

    test "a note about words only (\"Words in s. N repealed (S.)\") never excludes the row" do
      body =
        ~s|<P1group><Title>T</Title><P1><Pnumber><CommentaryRef Ref="n-rep-s"/>1</Pnumber><P1para><Text>A duty applies.</Text></P1para></P1></P1group>|

      rows = parse(body, rep_s())
      assert row(rows, "s.1").excluded_extent == nil
    end

    test "a Part repeal \"except in relation to ss. 13-15\" (Q2; 1984/22): s.13 untouched; s.20 no claim — the effect's qualifications are \"Other\" (gap)" do
      body =
        ~s|<Part id="part-II"><Number>Part II</Number><Title>T</Title><P1group><Title>T</Title><P1 id="section-13"><Pnumber><Repeal ChangeId="key-pt2-1" RetainText="true">13</Repeal></Pnumber><P1para><Text><Repeal ChangeId="key-pt2-1" RetainText="true">Regulations may provide for diseases.</Repeal></Text></P1para></P1></P1group><P1group><Title>T</Title><P1 id="section-20"><Pnumber><Repeal ChangeId="key-pt2-1" RetainText="true">20</Repeal></Pnumber><P1para><Text><Repeal ChangeId="key-pt2-1" RetainText="true">A duty to notify.</Repeal></Text></P1para></P1></P1group></Part>|

      rows =
        parse(body, [], "E+W", [
          fx(
            effect_id: "key-pt2",
            type: "repealed",
            effect_extent: "S+A+M+E+A+S+A+F+F+E+C+T+E+D",
            in_force_qualifications: ["Other", "Other"],
            affected_refs: ["part-II"]
          )
        ])

      assert %{excluded_extent: nil, status: "in_force"} = row(rows, "s.13")
      assert %{excluded_extent: nil} = row(rows, "s.20")
    end
  end
end
