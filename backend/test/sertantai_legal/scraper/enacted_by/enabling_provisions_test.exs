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

  describe "forms the parser missed (Maritime Safety: Extent reader, 2026-11-05; real clauses)" do
    @msa %{"merchant shipping act 1995" => "UK_ukpga_1995_21"}

    test "a footnote marker inside the clause, the Act named before it as 'that Act' (SI 2018/155)" do
      text =
        "The Secretary of State, after consulting the persons referred to in section 86(4) of the Merchant Shipping Act 1995 f00001 , and in exercise of the powers conferred by section 85(1) to (1B), (3) and (5) to (7), section 86(1), section 302(1) and section 306A of that Act, and with the consent of the Treasury f00002 , makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"],
        "f00002" => ["http://www.legislation.gov.uk/id/uksi/1995/269"]
      }

      assert EnablingProvisions.parse(text, urls, @msa) == [
               %{law: "UK_ukpga_1995_21", sections: ["85", "86", "302", "306A"], schedules: []}
             ]
    end

    test "'of that Act' followed by an amendment footnote (SI 2000/2687, 2001/1638)" do
      text =
        "The Secretary of State for the Environment, Transport and the Regions, after consulting the persons referred to in section 86(4) of the Merchant Shipping Act 1995 f00001 , in exercise of the powers conferred by section 85(1)(a) and (b), (3) and (5) to (7) and section 86(1) of that Act f00002 and of all other powers enabling him in that behalf, hereby makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1997/28"]
      }

      assert EnablingProvisions.parse(text, urls, @msa) == [
               %{law: "UK_ukpga_1995_21", sections: ["85", "86"], schedules: []}
             ]

      text =
        "The Secretary of State, after such consultation as is required by section 86(4) of the Merchant Shipping Act 1995 f00001 , in exercise of the powers conferred upon him by sections 85(1)(a) and (b), (3) and (7) and 86(1) of that Act f00002 hereby makes the following Regulations:"

      assert EnablingProvisions.parse(text, urls, @msa) == [
               %{law: "UK_ukpga_1995_21", sections: ["85", "86"], schedules: []}
             ]
    end

    test "the Act before the clause named by its marker, not its register title (SI 2022/241)" do
      text =
        "The Secretary of State f00001 , considering that the requirements of section 45(2) of the Sanctions and Money-Laundering Act 2018 f00002 are met, makes the following Regulations in exercise of the powers conferred by sections 1, 5, 6(1) to (6), 45 and 62(6) of, and paragraphs 2(b) and 27 of Schedule 1 to, that Act:"

      urls = %{"f00002" => ["http://www.legislation.gov.uk/id/ukpga/2018/13"]}

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_2018_13", sections: ["1", "5", "6", "45", "62"], schedules: ["1"]}
             ]
    end

    test "'(hereinafter called “the Act”)' and 'of the Act' (SI 1995/1900)" do
      text =
        "The Secretary of State for Transport, after consulting with the organisations referred to in section 99(2) of the Merchant Shipping Act 1970 f00001 (hereinafter called “the Act”), in exercise of powers conferred by section 71 of the Act and now vested in him f00002 , and of all other powers enabling him in that behalf, hereby makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1970/36"],
        "f00002" => ["http://www.legislation.gov.uk/id/uksi/1970/1537"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1970_36", sections: ["71"], schedules: []}
             ]
    end

    test "'the said section 2(2)' after the designation (SI 1999/1704)" do
      text =
        "Whereas the Secretary of State is a Minister designated f00001 for the purpose of section 2(2) of the European Communities Act 1972 f00002 in relation to measures relating to the safety of ships; Now, therefore, the Secretary of State for the Environment, Transport and the Regions, in exercise of the powers conferred by the said section 2(2) and of all other powers enabling him in that behalf, hereby makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/uksi/1993/595"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []}
             ]
    end

    test "an Act in plain words, then sections whose list carries footnote markers (SI 2016/1061)" do
      text =
        "The Secretary of State is a Minister designated f00001 in relation to measures relating to maritime transport for the purpose of section 2(2) of the European Communities Act 1972 f00002 . The Secretary of State in exercise of the powers conferred by section 2(2) of the European Communities Act 1972 and by sections 185(2C) f00003 and 306A f00004 of the Merchant Shipping Act 1995 f00005 , makes the following Order."

      urls = %{
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"],
        "f00003" => ["http://www.legislation.gov.uk/id/uksi/2014/1614"],
        "f00004" => ["http://www.legislation.gov.uk/id/ukpga/1997/28"],
        "f00005" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"]
      }

      titles = Map.put(@msa, "european communities act 1972", "UK_ukpga_1972_68")

      assert EnablingProvisions.parse(text, urls, titles) == [
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []},
               %{law: "UK_ukpga_1995_21", sections: ["185", "306A"], schedules: []}
             ]
    end

    test "'the said section 2(2)' of the Act it was named in, after 'that Act' (SI 2004/1266)" do
      text =
        "The Secretary of State, after consulting the persons referred to in section 86(4) of the Merchant Shipping Act 1995 f00001 , in exercise of the powers conferred upon him by sections 85, 86 and 267 of that Act, and being a Minister designated f00002 for the purposes of section 2(2) of the European Communities Act 1972 f00003 in relation to measures relating to the safety of ships, in exercise of the powers conferred upon him by the said section 2(2), hereby makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"],
        "f00002" => ["http://www.legislation.gov.uk/id/uksi/1993/595"],
        "f00003" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"]
      }

      assert [
               %{law: "UK_ukpga_1995_21", sections: ["85", "86", "267"]},
               %{law: "UK_ukpga_1972_68", sections: ["2"]} | _
             ] = EnablingProvisions.parse(text, urls, @msa)
    end

    test "a marker after an Order cites it: its Schedule is never the next Act's (SR 2010/160)" do
      text =
        "The Department makes the following Regulations in exercise of the powers conferred by Articles 17(1) to (6), 40(2) to (4), 55(2) of, and paragraphs 1, 2 and 19 of Schedule 3 to, the Health and Safety at Work (Northern Ireland) Order 1978 f00003 as read with paragraph 1A of Schedule 2 to the European Communities Act 1972 f00004 ."

      urls = %{
        "f00003" => ["http://www.legislation.gov.uk/id/nisi/1978/1039"],
        "f00004" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1972_68", sections: [], schedules: ["2"]}
             ]
    end

    test "after the recitals: 'Now, therefore …' holds the powers clause (SI 2004/3363, 2002/794)" do
      text =
        "Whereas a draft of this Order has been approved by resolution of each House of Parliament in pursuance of section 82(2) of the Freedom of Information Act 2000 f00001 ; Now, therefore, the Secretary of State, in exercise of the powers conferred f00002 by section 75 of the Freedom of Information Act 2000, hereby makes the following Order:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/2000/36"],
        "f00002" => ["http://www.legislation.gov.uk/id/uksi/2003/1887"]
      }

      titles = %{"freedom of information act 2000" => "UK_ukpga_2000_36"}

      assert EnablingProvisions.parse(text, urls, titles) == [
               %{law: "UK_ukpga_2000_36", sections: ["75"], schedules: []}
             ]
    end

    test "a purpose after the clause is no power: '— for the purpose of giving effect …' (SI 2014/1637)" do
      text =
        "The Secretary of State makes these Regulations in exercise of the powers conferred upon him by sections 15(1), (2) and 82(3)(a) of, and paragraphs 1(1) and 15(1) of Schedule 3 to, the Health and Safety at Work etc. Act 1974 f00001 (“the 1974 Act”)— for the purpose of giving effect without modifications to proposals submitted to him by the Health and Safety Executive under section 11(3) f00002 of the 1974 Act, the Executive having consulted in accordance with section 50(3) f00003 of that Act."

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1974/37"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/2013/32"],
        "f00003" => ["http://www.legislation.gov.uk/id/ukpga/2013/32"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1974_37", sections: ["15", "82"], schedules: ["3"]}
             ]
    end

    test "'of the 1995 Act' defined after its title, and 'every other power' (SI 2002/2201, SR 2003/454)" do
      text =
        "Whereas the Secretary of State is a Minister designated f00001 for the purpose of section 2(2) of the European Communities Act 1972 (“the 1972 Act ”) f00002 ; And whereas the Regulations are made in the exercise of powers conferred by section 43 of the Merchant Shipping Act 1995 (“the 1995 Act ”) f00003 ; Now, therefore, the Secretary of State, in exercise of the powers conferred by sections 85(1)(a) and 86(1) of the 1995 Act and section 2(2) of the 1972 Act and of every other power enabling him in that behalf, hereby makes the following Regulations:"

      urls = %{
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1972/68"],
        "f00003" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1995_21", sections: ["85", "86"], schedules: []},
               %{law: "UK_ukpga_1972_68", sections: ["2"], schedules: []}
             ]
    end

    test "'of the said Act of 1995' (SI 1999/3281)" do
      text =
        "The Secretary of State, after consulting with the organisations referred to in section 306(4) of the Merchant Shipping Act 1995 f00001 , in exercise of the powers conferred by section 80(1), (2) and (3) of the said Act of 1995 f00002 , and of all other powers enabling him in that behalf, hereby makes the following Regulations:"

      urls = %{
        "f00001" => ["http://www.legislation.gov.uk/id/ukpga/1995/21"],
        "f00002" => ["http://www.legislation.gov.uk/id/ukpga/1997/28"]
      }

      assert EnablingProvisions.parse(text, urls, %{}) == [
               %{law: "UK_ukpga_1995_21", sections: ["80"], schedules: []}
             ]
    end
  end
end
