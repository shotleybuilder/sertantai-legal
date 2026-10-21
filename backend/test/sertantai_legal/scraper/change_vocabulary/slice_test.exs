defmodule SertantaiLegal.Scraper.ChangeVocabulary.SliceTest do
  @moduledoc """
  The change-vocabulary thin slice (CV-02): two golden-set cases read end to
  end — markup and feed read into claims, merged by identity, chosen by one
  evidence table, folded into label periods. Expected periods are the golden
  set's (`data/reports/change-vocabulary/golden/`, signed off by Gemini
  2026-10-21), with `in_force_from` / `changed_by` as D1 defines them (when
  the current text took effect, and the laws that made it). CLML is trimmed
  real markup; effects are the real feed records, ids scrubbed (push
  protection).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  defp effect(fields) do
    struct!(
      Effect,
      Keyword.merge(
        [applied: true, prospective: false, savings: [], in_force_qualifications: []],
        fields
      )
    )
  end

  defp period(from, to, status, in_force_from, changed_by, territory),
    do: %{
      valid_from: from,
      valid_to: to,
      status: status,
      in_force_from: in_force_from,
      changed_by: changed_by,
      territory: territory
    }

  describe "SI 2010/404 reg.14: an \"(England)\" SI's retained repeal; Welsh changes after" do
    # markup: every node of reg.14 wrapped in one legacy-id RetainText Repeal
    # (note: SI 2023/911); the heading substituted by wsi 2025/1320; reg.14(1)'s
    # words substituted by wsi 2025/1320 and again by wsi 2026/112
    @omit "M_F_omit"
    @xml """
    <Legislation RestrictExtent="E+W"><Secondary><Body>
    <P1group RestrictExtent="E+W"><Title><Substitution ChangeId="key-head-1" CommentaryRef="key-head">Fees for determinations of questions by the Welsh Ministers</Substitution></Title>
    <P1 id="regulation-14"><Pnumber><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true">14</Repeal></Pnumber><P1para>
    <P2 id="regulation-14-1"><Pnumber><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true">1</Repeal></Pnumber><P2para><Text><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true">The fee which shall accompany an application for </Repeal><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true"><Substitution ChangeId="key-w25-1" CommentaryRef="key-w25">an appeal under regulation 14E of the </Substitution></Repeal><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true"><Substitution ChangeId="key-w25-1" CommentaryRef="key-w25"><Substitution ChangeId="key-w26-1" CommentaryRef="key-w26">Principal Regulations</Substitution></Substitution></Repeal><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true"> is—</Repeal></Text></P2para></P2>
    <P2 id="regulation-14-3"><Pnumber><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true">3</Repeal></Pnumber><P2para><Text><Repeal ChangeId="#{@omit}-1" CommentaryRef="#{@omit}" RetainText="true">No fee shall be payable in respect of the determination of any question relating to building work of the description in regulation 4.</Repeal></Text></P2para></P2>
    </P1para></P1></P1group>
    </Body></Secondary>
    <Commentaries><Commentary id="#{@omit}" Type="F"><Para><Text>Reg. 14 omitted (E.) (1.10.2023) by <Citation URI="http://www.legislation.gov.uk/id/uksi/2023/911">S.I. 2023/911</Citation></Text></Para></Commentary></Commentaries></Legislation>
    """

    defp effects_404,
      do: [
        effect(
          effect_id: "key-omit",
          type: "omitted",
          affecting: "UK_uksi_2023_911",
          affecting_territory: "E",
          affected_provisions: "reg. 14",
          affected_refs: ["regulation-14"],
          effect_extent: "E+W",
          in_force_date: ~D[2023-10-01],
          in_force_qualifications: ["wholly in force"]
        ),
        effect(
          effect_id: "key-head",
          type: "words substituted",
          affecting: "UK_wsi_2025_1320",
          affecting_territory: "W",
          affected_provisions: "reg. 14 heading",
          affected_refs: ["regulation-14"],
          effect_extent: "E+W",
          territorial_application: "W",
          in_force_date: ~D[2026-07-01]
        ),
        effect(
          effect_id: "key-w25",
          type: "words substituted",
          affecting: "UK_wsi_2025_1320",
          affecting_territory: "W",
          affected_provisions: "reg. 14(1)",
          affected_refs: ["regulation-14-1"],
          effect_extent: "E+W",
          territorial_application: "W",
          in_force_date: ~D[2026-07-01]
        ),
        effect(
          effect_id: "key-w26",
          type: "words substituted",
          affecting: "UK_wsi_2026_112",
          affecting_territory: "W",
          affected_provisions: "reg. 14(1)",
          affected_refs: ["regulation-14-1"],
          effect_extent: "E+W",
          territorial_application: "W",
          in_force_date: ~D[2026-07-20]
        )
      ]

    @provisions %{
      "reg.14" => %{extent: "E+W", start: ~D[2010-04-01]},
      "reg.14(1)" => %{extent: "E+W", start: ~D[2010-04-01]},
      "reg.14(3)" => %{extent: "E+W", start: ~D[2010-04-01]}
    }

    setup do
      %{labels: ChangeVocabulary.labels("UK_uksi_2010_404", @xml, effects_404(), @provisions)}
    end

    test "reg.14: in force in Wales from the England-only omission; the Welsh heading change versions it",
         %{labels: labels} do
      assert labels["reg.14"] == [
               period(~D[2010-04-01], ~D[2023-10-01], :in_force, ~D[2010-04-01], [], "E+W"),
               period(~D[2023-10-01], ~D[2026-07-01], :in_force, ~D[2010-04-01], [], "W"),
               period(~D[2026-07-01], nil, :in_force, ~D[2026-07-01], ["UK_wsi_2025_1320"], "W")
             ]
    end

    test "reg.14(1): the omission reaches it (provision level); its own Welsh word changes version it (C9: never reg.14's)",
         %{labels: labels} do
      assert labels["reg.14(1)"] == [
               period(~D[2010-04-01], ~D[2023-10-01], :in_force, ~D[2010-04-01], [], "E+W"),
               period(~D[2023-10-01], ~D[2026-07-01], :in_force, ~D[2010-04-01], [], "W"),
               period(
                 ~D[2026-07-01],
                 ~D[2026-07-20],
                 :in_force,
                 ~D[2026-07-01],
                 ["UK_wsi_2025_1320"],
                 "W"
               ),
               period(~D[2026-07-20], nil, :in_force, ~D[2026-07-20], ["UK_wsi_2026_112"], "W")
             ]
    end

    test "why: the legacy RetainText Repeal joins the feed's omission (by the cited law); retained text lets the affecting law's territory win" do
      alias SertantaiLegal.Scraper.ChangeVocabulary.{Evidence, Merge}
      alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{Feed, Markup}

      [omit] =
        (Feed.read(effects_404()) ++ Markup.read(@xml))
        |> Merge.merge()
        |> Enum.filter(&(&1.key == "key-omit"))
        |> Enum.map(&Evidence.resolve(&1, "E+W"))

      assert omit.target == "reg.14"
      assert "M_F_omit-1" in omit.aliases
      assert omit.resolved.operation == :repealed
      assert omit.resolved.level == :provision
      assert omit.resolved.retained
      assert omit.resolved.territory == "E"
      assert omit.resolved.sources.territory == :law
    end

    test "reg.14(3): only the omission", %{labels: labels} do
      assert labels["reg.14(3)"] == [
               period(~D[2010-04-01], ~D[2023-10-01], :in_force, ~D[2010-04-01], [], "E+W"),
               period(~D[2023-10-01], nil, :in_force, ~D[2010-04-01], [], "W")
             ]
    end
  end

  describe "SI 2000/1043 reg.11(3): substituted the same day for E (marked up) and for W (feed only)" do
    @xml_pcb """
    <Legislation RestrictExtent="E+W"><Secondary><Body>
    <P2 id="regulation-11-3"><Pnumber><Substitution ChangeId="key-eng-1" CommentaryRef="key-eng">3</Substitution></Pnumber><P2para><Text><Substitution ChangeId="key-eng-1" CommentaryRef="key-eng">Subject to paragraphs (5) and (7), the Agency shall keep a register specifying the quantity, origin, nature and PCB content of used PCBs in respect of which—</Substitution></Text>
    <P3 id="regulation-11-3-b"><Pnumber><Substitution ChangeId="key-eng-1" CommentaryRef="key-eng">b</Substitution></Pnumber><P3para><Text><Substitution ChangeId="key-eng-1" CommentaryRef="key-eng">quarterly returns specifying that information are furnished to it under regulation 53 of the </Substitution><Substitution ChangeId="key-eng-1" CommentaryRef="key-eng"><Repeal ChangeId="key-eng-2" CommentaryRef="key-eng" RetainText="true" SubstitutionRef="key-eng-3" Extent="W">Hazardous Waste (England and Wales) Regulations 2005</Repeal></Substitution> <Substitution ChangeId="key-eng-1" CommentaryRef="key-eng"><Addition ChangeId="key-eng-3" CommentaryRef="key-eng" Extent="W">Hazardous Waste (Wales) Regulations 2005</Addition></Substitution></Text></P3para></P3>
    </P2para></P2>
    </Body></Secondary><Commentaries/></Legislation>
    """

    defp effects_pcb,
      do: [
        effect(
          effect_id: "key-wal",
          type: "substituted",
          affecting: "UK_wsi_2005_1806",
          affecting_territory: "W",
          affected_provisions: "reg. 11(3)",
          affected_refs: ["regulation-11-3"],
          affected_extent: "E+W",
          effect_extent: "E+W",
          territorial_application: "W",
          in_force_date: ~D[2005-07-16],
          in_force_qualifications: ["wholly in force"]
        ),
        effect(
          effect_id: "key-eng",
          type: "substituted",
          affecting: "UK_uksi_2005_894",
          affecting_territory: nil,
          affected_provisions: "reg. 11(3)",
          affected_refs: ["regulation-11-3"],
          affected_extent: "E+W",
          effect_extent: "E+W",
          territorial_application: "E",
          savings: ["regulation-75"],
          in_force_date: ~D[2005-07-16],
          in_force_qualifications: ["wholly in force"]
        )
      ]

    test "one version for E+W on 2005-07-16, made by both laws (C5)" do
      labels =
        ChangeVocabulary.labels("UK_uksi_2000_1043", @xml_pcb, effects_pcb(), %{
          "reg.11(3)" => %{extent: "E+W", start: ~D[2000-05-04]}
        })

      assert labels["reg.11(3)"] == [
               period(~D[2000-05-04], ~D[2005-07-16], :in_force, ~D[2000-05-04], [], "E+W"),
               period(
                 ~D[2005-07-16],
                 nil,
                 :in_force,
                 ~D[2005-07-16],
                 ["UK_uksi_2005_894", "UK_wsi_2005_1806"],
                 "E+W"
               )
             ]
    end
  end
end
