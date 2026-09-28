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
end
