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

    # EPA 1990 (Commencement No. 19) Order 2012; Circular Economy (Scotland)
    # Act 2024 (Commencement No. 1) Regulations 2025
    test "a commencement worded \"the day appointed\", the date first or last" do
      d =
        si([
          {"article-2",
           "The day appointed for the coming into force of section 162(2) of the Environmental Protection Act 1990 is 6th April 2012."},
          {"regulation-3",
           "4 February 2025 is the day appointed for the coming into force of section 21 of the Act."}
        ])

      assert MakingLaws.kind(d, "article-2") == :change
      assert MakingLaws.kind(d, "regulation-3") == :change
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

    # Food and Environment Protection Act 1985 (Guernsey) Order 1987,
    # Environmental Protection (Waste Recycling Payments) Regulations 1994,
    # SI 1994/1096 art. 3(3)
    test "standard wording: extent, a commencement read as no statement, evidence, an aside after shall" do
      d =
        si([
          {"article-3",
           "Part II of the Food and Environment Protection Act 1985 shall extend to the Bailiwick with the modifications specified in the Schedule to this Order."},
          {"article-4",
           "The provisions of the Act, modified as in Schedule 1, shall extend and apply to the Territories specified in Schedule 2."},
          {"article-11",
           "Where an activity falls within article 2(2)(d), the relevant provisions shall come into force for the purposes of their application to that activity on 1st May 1994."},
          {"article-12",
           "A licence granted before this Order shall remain in force for the rest of its period."},
          {"article-13",
           "A certificate given by the Governor shall be conclusive evidence of the matters stated in it, and a document purporting to be such a certificate shall, in any proceedings, be received in evidence."},
          {"regulation-1-3",
           "Any reference in these Regulations to a numbered regulation shall, unless the context otherwise requires, be construed as a reference to the regulation so numbered."}
        ])

      for id <- ~w(article-3 article-4 article-11 article-12 article-13 regulation-1-3),
          do: assert(MakingLaws.kind(d, id) == :standard, id)
    end

    # SSI 2006/475 art. 3, SI 1974/2013 reg. 6 (Fire and OH&S: Making laws)
    test "standard wording: a lead-in's items, an aside of two parts" do
      d =
        Doc.new("UK_ssi_2006_1", [
          ~s(<Legislation><Secondary><Body><P1 id="article-3"><P1para><Text>Notwithstanding the repeal by this Order of section 10 of the 1971 Act, a prohibition notice served under that section shall–</Text><P3 id="article-3-a"><Pnumber>a</Pnumber><P3para><Text>remain in effect, and</Text></P3para></P3><P3 id="article-3-b"><Pnumber>b</Pnumber><P3para><Text>be deemed to be a prohibition notice served under section 63 of the 2005 Act.</Text></P3para></P3></P1para></P1><P1 id="regulation-6"><P1para><Text>References in any enactment to the inspector for the district shall, except where the context otherwise requires, or where the reference is otherwise expressly amended, be construed as references to an inspector appointed under section 19 of the 1974 Act.</Text></P1para></P1></Body></Secondary></Legislation>)
        ])

      assert MakingLaws.kind(d, "article-3") == :standard
      assert MakingLaws.kind(d, "regulation-6") == :standard
    end

    test "a lead-in's item can state the requirement" do
      d =
        Doc.new("UK_uksi_2020_2", [
          ~s(<Legislation><Secondary><Body><P1 id="regulation-4"><P1para><Text>The operator shall–</Text><P3 id="regulation-4-a"><Pnumber>a</Pnumber><P3para><Text>remain in contact with the regulator, and</Text></P3para></P3><P3 id="regulation-4-b"><Pnumber>b</Pnumber><P3para><Text>send the return before 1st May.</Text></P3para></P3></P1para></P1></Body></Secondary></Legislation>)
        ])

      assert MakingLaws.kind(d, "regulation-4") == :requirement
    end

    # SI 2014/1253 art. 2 (Fire and OH&S: Making laws, Decision 1)
    test "a designation: an offshore safety zone established" do
      d =
        si([
          {"article-2",
           "A safety zone is established around each installation specified in column 1 of the Schedule having a radius of five hundred metres."},
          {"article-3",
           "A safety zone is hereby established around the installation specified in the Schedule."}
        ])

      assert MakingLaws.kind(d, "article-2") == :designation
      assert MakingLaws.kind(d, "article-3") == :designation

      assert %{verdict: :making, reason: "2 designations (first article-2)"} =
               MakingLaws.classify(d)
    end

    test "an aside after shall does not hide a requirement" do
      d =
        si([
          {"regulation-4",
           "The operator shall, before the first day of each year, send the return to the regulator."}
        ])

      assert MakingLaws.kind(d, "regulation-4") == :requirement
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

    # the Cremation Regulations 1952: legislation.gov.uk holds the law as a
    # scanned print only (NumberOfProvisions="0")
    test "no provisions upstream: no verdict, said so" do
      d =
        Doc.new("UK_uksi_1952_1568", [
          ~s(<Legislation NumberOfProvisions="0"><Secondary><Body/></Secondary></Legislation>)
        ])

      assert %{verdict: nil, reason: "no provisions upstream"} = MakingLaws.classify(d)
    end

    test "no text held: no verdict" do
      assert %{verdict: nil, reason: "no text"} = MakingLaws.classify(nil)
    end
  end
end
