defmodule SertantaiLegal.Scraper.MakingLawsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.MakingLaws

  # an SI of regulations, each `{id, text}` its own P1
  defp si(regs, schedules \\ "") do
    body =
      Enum.map_join(regs, fn {id, text} ->
        ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)
      end)

    Doc.new("UK_uksi_2020_1", [
      ~s(<Legislation><Secondary><Body>#{body}</Body>#{schedules}</Secondary></Legislation>)
    ])
  end

  @citation {"regulation-1",
             "These Regulations may be cited as the Merchant Shipping (Test) Regulations 2020 and come into force on 1st April 2020."}
  @interpretation {"regulation-2",
                   "In these Regulations “ship” means a ship to which regulation 3 applies, and “owner” shall be construed accordingly."}

  describe "provision kinds" do
    test "an amending instruction, with its quoted words set aside" do
      d =
        si([
          {"regulation-3",
           "In regulation 5 of the 1998 Regulations, for “may” substitute “must”."}
        ])

      assert MakingLaws.kind(d, "regulation-3") == :change
    end

    test "inserted text stating a duty is the amended law's, not this law's" do
      d =
        Doc.new("UK_uksi_2020_1", [
          ~s(<Legislation><Secondary><Body><P1 id="regulation-3"><P1para><Text>After regulation 5 of the 1998 Regulations insert—</Text><BlockAmendment><P1 id="regulation-5A"><P1para><Text>The owner shall ensure that the ship carries a lifeboat.</Text></P1para></P1></BlockAmendment></P1para></P1></Body></Secondary></Legislation>)
        ])

      assert MakingLaws.kind(d, "regulation-3") == :change
      assert MakingLaws.provisions(d) == ["regulation-3"]
    end

    test "a revocation and an amendment by reference are changes" do
      d =
        si([
          {"regulation-3", "The Merchant Shipping (Old) Regulations 1998 are revoked."},
          {"regulation-4", "The 1995 Regulations are amended as follows."}
        ])

      assert MakingLaws.kind(d, "regulation-3") == :change
      assert MakingLaws.kind(d, "regulation-4") == :change
    end

    test "a modification is a change, not an own requirement" do
      d =
        si([
          {"regulation-3",
           "The 1995 Act shall have effect as if in section 85 the owner shall keep a log."}
        ])

      assert MakingLaws.kind(d, "regulation-3") == :change
    end

    test "a modification by reference is a change" do
      d =
        si([
          {"regulation-10-1",
           "Regulation 9 (rectification and detention) shall be modified as follows."}
        ])

      assert MakingLaws.kind(d, "regulation-10-1") == :change
    end

    test "a commencement of the Act's provisions, \"this Order\" mid-sentence" do
      d =
        si([
          {"article-2",
           "The provisions of the Act specified in the Schedule to this Order shall come into force on 23rd March 1997."}
        ])

      assert MakingLaws.kind(d, "article-2") == :change
    end

    test "a commencement" do
      d =
        si([
          {"article-2",
           "The appointed day for the coming into force of section 3 is 1st May 2020."}
        ])

      assert MakingLaws.kind(d, "article-2") == :change
    end

    test "an own requirement: shall or must on someone, the negative forms too" do
      d =
        si([
          {"regulation-3", "The owner of a ship shall ensure that it carries a lifeboat."},
          {"regulation-4", "A ship must not proceed to sea unless surveyed."}
        ])

      assert MakingLaws.kind(d, "regulation-3") == :requirement
      assert MakingLaws.kind(d, "regulation-4") == :requirement
    end

    test "a power" do
      d = si([{"regulation-3", "The Secretary of State may exempt any ship from regulation 4."}])
      assert MakingLaws.kind(d, "regulation-3") == :power
    end

    test "standard wording: citation, interpretation, application, offences" do
      d =
        si([
          @citation,
          @interpretation,
          {"regulation-3",
           "These Regulations shall apply to United Kingdom ships wherever they may be."},
          {"regulation-4",
           "A person who contravenes regulation 3 shall be guilty of an offence."},
          {"regulation-5",
           "The employer and the master shall each be liable on summary conviction to a fine."},
          {"regulation-6",
           "The repeal of section 145 shall not affect any order issued before it."}
        ])

      for id <- ~w(regulation-1 regulation-2 regulation-3 regulation-4 regulation-5 regulation-6),
          do: assert(MakingLaws.kind(d, id) == :standard, id)
    end
  end

  describe "a law's verdict" do
    test "amending only: not making" do
      d =
        si([
          @citation,
          {"regulation-2",
           "In regulation 5 of the 1998 Regulations, for “may” substitute “must”."},
          {"regulation-3", "The Merchant Shipping (Old) Regulations 1998 are revoked."}
        ])

      assert %{verdict: :not_making, reason: "changes only"} = MakingLaws.classify(d)
    end

    test "a commencement order: not making" do
      d =
        si([
          {"article-1",
           "This Order may be cited as the Merchant Shipping Act 1995 (Commencement) Order."},
          {"article-2", "Section 3 of the Act comes into force on 1st May 2020."}
        ])

      assert %{verdict: :not_making} = MakingLaws.classify(d)
    end

    test "mixed: one own requirement makes the law making" do
      d =
        si([
          @citation,
          {"regulation-2", "The owner shall ensure that the ship is surveyed annually."},
          {"regulation-3", "The 1995 Regulations are amended as follows."}
        ])

      assert %{verdict: :making, reason: "1 own requirement (first regulation-2)"} =
               MakingLaws.classify(d)
    end

    test "requirements in a Schedule count" do
      d =
        si(
          [@citation],
          ~s(<Schedules><Schedule id="schedule-1"><ScheduleBody><P1 id="schedule-1-paragraph-1"><P1para><Text>The master shall keep a record.</Text></P1para></P1></ScheduleBody></Schedule></Schedules>)
        )

      assert %{verdict: :making, counts: %{requirement: 1}} = MakingLaws.classify(d)
    end

    test "powers only: no verdict, for Jason" do
      d = si([@citation, {"regulation-2", "The Secretary of State may exempt any ship."}])
      assert %{verdict: nil, reason: "powers only"} = MakingLaws.classify(d)
    end

    test "standard wording only: no verdict" do
      assert %{verdict: nil, reason: "no operative provision"} =
               MakingLaws.classify(si([@citation, @interpretation]))
    end

    test "no text held: no verdict" do
      assert %{verdict: nil, reason: "no text"} = MakingLaws.classify(nil)
    end
  end
end
