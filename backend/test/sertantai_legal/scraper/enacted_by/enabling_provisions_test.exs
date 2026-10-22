defmodule SertantaiLegal.Scraper.EnactedBy.EnablingProvisionsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.EnactedBy.EnablingProvisions

  test "sections of one Act (Surface Waters (River Ecosystem) Regs 1994)" do
    text =
      "The Secretary of State for the Environment and the Secretary of State for Wales, acting jointly in exercise of the powers conferred on them by sections 82 and 219(2) of the Water Resources Act 1991 f00001 and of all other powers enabling them in that behalf, hereby make the following Regulations:—"

    urls = %{"f00001" => ["http://www.legislation.gov.uk/id/ukpga/1991/57"]}

    assert EnablingProvisions.parse(text, urls) == [
             %{law: "UK_ukpga_1991_57", sections: ["82", "219"], schedules: []}
           ]
  end

  test "subsection lists, schedule paragraphs, and a footnote naming several Acts (PUWER 1992)" do
    text =
      "The Secretary of State, in the exercise of the powers conferred on her by sections 15(1), (2), (3)(a), (5)(b) and (9), and 82(3)(a) of, and paragraphs 1(1), (2) and (3), 13(1) and 14 of Schedule 3 to, the Health and Safety at Work etc. Act 1974 f00001 (“the 1974 Act”) and of all other powers enabling her in that behalf and for the purpose of giving effect without modifications to proposals submitted to her by the Health and Safety Commission under section 11(2)(d) of the 1974 Act, hereby makes the following Regulations:"

    urls = %{
      "f00001" => [
        "http://www.legislation.gov.uk/id/ukpga/1974/37",
        "http://www.legislation.gov.uk/id/ukpga/1975/71",
        "http://www.legislation.gov.uk/id/ukpga/1992/15"
      ]
    }

    assert EnablingProvisions.parse(text, urls) == [
             %{law: "UK_ukpga_1974_37", sections: ["15", "82"], schedules: ["3"]}
           ]
  end

  test "a long section list (T&CP (Trees) Regs 1999)" do
    text =
      "in exercise of the powers conferred by sections 199(2) and (3), 212, 316(1), 323, and 333(1) of the Town and Country Planning Act 1990 f00001 , and of all other powers enabling them in that behalf, hereby make the following Regulations:"

    urls = %{
      "f00001" => [
        "http://www.legislation.gov.uk/id/ukpga/1990/8",
        "http://www.legislation.gov.uk/id/ukpga/1991/34"
      ]
    }

    assert EnablingProvisions.parse(text, urls) == [
             %{
               law: "UK_ukpga_1990_8",
               sections: ["199", "212", "316", "323", "333"],
               schedules: []
             }
           ]
  end

  test "two Acts in one clause" do
    text =
      "in exercise of the powers conferred by section 2(2) of the European Communities Act 1972 f00001 and sections 15 and 43 of the Health and Safety at Work etc. Act 1974 f00002 and of all other powers enabling him, hereby makes:"

    urls = %{
      "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"],
      "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1974/37"]
    }

    assert EnablingProvisions.parse(text, urls) == [
             %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []},
             %{law: "UK_ukpga_1974_37", sections: ["15", "43"], schedules: []}
           ]
  end

  test "no powers clause or no section list: nothing" do
    assert EnablingProvisions.parse(
             "Her Majesty, by and with the advice of Her Privy Council, orders:",
             %{}
           ) == []

    assert EnablingProvisions.parse(
             "in exercise of the powers conferred by the Water Resources Act 1991 f00001 hereby makes:",
             %{"f00001" => ["http://www.legislation.gov.uk/id/ukpga/1991/57"]}
           ) == []
  end

  test "an Act named in plain words, no citation marker: resolved by its title (SI 2016/1105; CV-07)" do
    text =
      "The Secretary of State makes these Regulations in exercise of the powers conferred by section 2(2) of, and paragraph 1A of Schedule 2 to, the European Communities Act 1972."

    titles = %{"european communities act 1972" => "UK_ukpga_1972_68"}

    assert EnablingProvisions.parse(text, %{}, titles) == [
             %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: ["2"]}
           ]

    # unknown title: nothing
    assert EnablingProvisions.parse(text, %{}, %{}) == []
  end

  test "the titles a powers clause names, to look up" do
    text =
      "in exercise of the powers conferred by section 2(2) of the European Communities Act 1972 and section 15 of the Health and Safety at Work etc. Act 1974."

    t = EnablingProvisions.titles(text)
    assert "european communities act 1972" in t
    assert "health and safety at work etc. act 1974" in t
  end

  test "the powers clause ends at its sentence (no 'all other powers', no 'hereby': SI 2019/758)" do
    text =
      "The Secretary of State makes these Regulations in exercise of the powers conferred by section 8(1) of, and paragraph 1 of Schedule 4 and paragraph 21 of Schedule 7 to, the European Union (Withdrawal) Act 2018 . In accordance with paragraph 3(1) of Schedule 4 to that Act, these Regulations are made with the consent of the Treasury."

    titles = %{"european union (withdrawal) act 2018" => "UK_ukpga_2018_16"}

    assert EnablingProvisions.parse(text, %{}, titles) == [
             %{law: "UK_ukpga_2018_16", sections: ["8"], schedules: ["4", "7"]}
           ]
  end

  describe "forms the parser missed (CV-07: 66 OH&S amending SIs sampled; real clauses)" do
    @titles %{
      "health and safety at work etc. act 1974" => "UK_ukpga_1974_37",
      "european communities act 1972" => "UK_ukpga_1972_68",
      "european union (withdrawal) act 2018" => "UK_ukpga_2018_16",
      "civil partnership act 2004" => "UK_ukpga_2004_33"
    }

    test "a defined-term bracket after the title, no marker (SI 2013/1471)" do
      text =
        "The Secretary of State makes these Regulations in exercise of the powers conferred by sections 15(1), (2), (3)(a), (4)(a), (5)(a) and (b), (6)(b), (9) and 52(2) of, and paragraphs 15(1), 16 and 20 of Schedule 3 to, the Health and Safety at Work etc. Act 1974 (“ the 1974 Act ”). The Regulations give effect without modification to proposals."

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1974_37", sections: ["15", "52"], schedules: ["3"]}
             ]
    end

    test "a defined-term bracket between the title and its marker (SI 2025/82)" do
      text =
        "The Secretary of State makes these Regulations in exercise of the powers conferred by section 19(1) of the Retained EU Law (Revocation and Reform) Act 2023 (“ the Act ”) f00001 . The Secretary of State is a relevant national authority."

      urls = %{"f00001" => ["http://www.legislation.gov.uk/id/ukpga/2023/28"]}

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_2023_28", sections: ["19"], schedules: []}
             ]
    end

    test "the clause ends at 'and for the purpose' (SI 2005/735)" do
      text =
        "The Secretary of State, in the exercise of the powers conferred on him by sections 15(1), (2), (3)(a), (5)(b), (6)(a) and 82(3)(a) of, and paragraphs 1(1), (2) and (3), 9, 11, 14, 15(1) and 16 of Schedule 3 to, the Health and Safety at Work etc. Act 1974 (“ the 1974 Act ”) and for the purpose of giving effect without modifications to proposals submitted to him by the Health and Safety Commission under section 11(2)(d) of the 1974 Act, hereby makes the following Regulations:"

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1974_37", sections: ["15", "82"], schedules: ["3"]}
             ]
    end

    test "a trailing comma before 'hereby' (SI 2005/2114)" do
      text =
        "The Secretary of State, in exercise of the powers conferred upon him by section 259 of the Civil Partnership Act 2004 , hereby makes the following Order:"

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_2004_33", sections: ["259"], schedules: []}
             ]
    end

    test "two Acts in one unmarked clause (SI 2019/1246)" do
      text =
        "The Secretary of State makes the following Regulations in exercise of the powers conferred by section 2(2) of the European Communities Act 1972 and section 8(1) of, and paragraph 21 of Schedule 7 to, the European Union (Withdrawal) Act 2018 . The Secretary of State is of the opinion that, by reason of urgency, it is necessary."

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []},
               %{law: "UK_ukpga_2018_16", sections: ["8"], schedules: ["7"]}
             ]
    end

    test "'that Act': the Act named before the clause (SI 2016/1092)" do
      text =
        "The Secretary of State is a Minister designated for the purposes of section 2(2) of the European Communities Act 1972 in relation to product safety. The Secretary of State makes these Regulations in exercise of the powers conferred by section 2(2) of, and paragraph 1A of Schedule 2 to, that Act."

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: ["2"]}
             ]
    end

    test "'that section': the section named before the clause (SI 2008/2852)" do
      text =
        "The Secretary of State, being a Minister designated for the purposes of section 2(2) of the European Communities Act 1972 f00002 in relation to measures relating to persistent organic pollutants, makes the following Regulations in exercise of the powers conferred by that section:"

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []}
             ]
    end

    test "'the power conferred' (SI 2012/2404) and 'his powers under' (SI 1976/1246)" do
      text =
        "The Secretary of State makes the following Order in exercise of the power conferred by section 145(1) and (2)(b) of the Tribunals, Courts and Enforcement Act 2007 f00001 . In accordance with section 145(7) of that Act, a draft has been laid."

      urls = %{"f00001" => ["http://www.legislation.gov.uk/id/ukpga/2007/15"]}

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_2007_15", sections: ["145"], schedules: []}
             ]

      text =
        "The Secretary of State in exercise of his powers under section 14(3) of the Health and Safety at Work etc. Act 1974 and of all other powers enabling him in that behalf hereby makes the following Order:"

      assert EnablingProvisions.parse(text, %{}, @titles) == [
               %{law: "UK_ukpga_1974_37", sections: ["14"], schedules: []}
             ]
    end

    test "titles: every 'the … Act YYYY' the text names, shortest included (lookup keeps the known)" do
      t =
        EnablingProvisions.titles(
          "in exercise of the powers conferred by the Pyrotechnic Articles (Safety) Regulations 2010, section 2(2) of the European Communities Act 1972."
        )

      assert "european communities act 1972" in t
    end
  end
end
