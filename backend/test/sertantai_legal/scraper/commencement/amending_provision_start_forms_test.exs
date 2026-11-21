defmodule SertantaiLegal.Scraper.Commencement.AmendingProvisionStartFormsTest do
  @moduledoc """
  When an amending provision came into force, the forms parked from the
  Waste, Water and Climate round (LAT Change Pipeline, step Commencement
  reader): an Act whose other provisions come in "in accordance with
  regulations made by the Secretary of State" is left to those
  regulations, never dated at Royal Assent; and a repeal the feed points
  to by its paragraph and by the repeals Schedule is dated by the
  paragraph.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{AmendingCommencement, NoteDate}
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, Rule}
  alias SertantaiLegal.Scraper.LawStart.Clause

  describe "the Employment Rights Act 2025 (2025 c.36) s.159" do
    @other "The other provisions of this Act come into force in accordance with regulations made by the Secretary of State."

    defp era_2025 do
      OwnClause.rules("UK_x", %{
        type_code: "ukpga",
        rows: [
          %{
            section_id: "UK_x:s.159(1)",
            text:
              "The following provisions of this Act come into force on the day on which this Act is passed— (a) section 19 (review of extent of right to time off for public duties); (b) section 37 (guidance about the employment of children on heritage railways)."
          },
          %{section_id: "UK_x:s.159(3)", text: @other}
        ],
        made: ~D[2025-12-18],
        clml_head: nil,
        lrt_date: ~D[2025-12-18]
      })
    end

    test "\"in accordance with regulations made by\" leaves the day to regulations" do
      assert Clause.by_order?("in accordance with regulations made by the Secretary of State.")
    end

    test "the other provisions are appointed, with no Royal Assent rule for the Act" do
      rules = era_2025()

      assert Enum.any?(rules, &match?(%Rule{scope: :rest, when: {:appointed, _}}, &1))
      refute Enum.any?(rules, &(&1.treatment == :act_enactment))
    end

    test "a provision no regulations name has no date, never Royal Assent (Schedule 10)" do
      rules = era_2025()

      assert AmendingCommencement.commenced_on(rules, "sch.10.para.4") == nil
    end
  end

  describe "the Environment Act 1995 (1995 c.25) Sch.22 para.25 and Sch.24" do
    defp order(scope, date, opts) do
      Rule.new(
        commences: "UK_ukpga_1995_25",
        scope: scope,
        when: {:date, date},
        territory: opts[:territory],
        purposes: opts[:purposes],
        source: %{law: opts[:law], ref: "art.3", text: nil},
        treatment: :order_date
      )
    end

    # SI 1996/186 art.3 brings Sch.22 para.25 in on 1st April 1996; only
    # SSI 2015/73 names Schedule 24 itself, for Scotland and some repeals
    defp ea_1995 do
      %{
        "UK_ukpga_1995_25" => [
          order(["sch.22.para.25"], ~D[1996-04-01], law: "UK_uksi_1996_186"),
          order(["s.120(3)", "sch.24"], ~D[2015-04-01],
            law: "UK_ssi_2015_73",
            territory: "S",
            purposes: :in_relation_to
          )
        ]
      }
    end

    defp repeal(affecting) do
      key = "key-" <> String.duplicate("0", 32)

      claims =
        for {a, v} <- [operation: :repealed, by: "UK_ukpga_1995_25", affecting: affecting],
            do: %Claim{source: :feed, attribute: a, value: v, ref: key}

      %Change{key: key, target: "s.11(1)", claims: claims}
    end

    test "the repeal of COPA 1974 s.11(1) is dated by the paragraph, the repeals Schedule beside it" do
      assert NoteDate.why(repeal(["sch.22.para.25", "sch.24"]), ea_1995()) ==
               {:dated, ~D[1996-04-01], :feed}
    end

    # the Local Government (Wales) Act 1994 (1994 c.19): "s. 22(3), Sch. 9
    # para. 12", the subsection giving the Schedule effect in force only
    # so far as it relates to the paragraphs SI 1996/396 names
    test "a subsection introducing the Schedule beside its paragraph: the paragraph decides" do
      rules = %{
        "UK_ukpga_1995_25" => [
          order(["sch.9.para.12"], ~D[1996-04-01], law: "UK_uksi_1996_396"),
          order(["s.22(3)"], ~D[1996-04-01], law: "UK_uksi_1996_396", purposes: :in_relation_to)
        ]
      }

      assert NoteDate.why(repeal(["s.22(3)", "sch.9.para.12"]), rules) ==
               {:dated, ~D[1996-04-01], :feed}
    end

    test "the repeals Schedule alone states no day for one entry" do
      assert {:undated, _} = NoteDate.why(repeal(["sch.24"]), ea_1995())
    end
  end
end
