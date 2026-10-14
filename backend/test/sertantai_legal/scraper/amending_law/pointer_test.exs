defmodule SertantaiLegal.Scraper.AmendingLaw.PointerTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Pointer

  defp note(text, law), do: %{code: "F1", text: text, citation_law: law}

  test "the amending provisions after the citation, and the commencing instrument after ';'" do
    p =
      Pointer.parse(
        note(
          "S. 25(5A) inserted (1.10.2001) by 2000 c. 27, s. 60(5)(7); S.I. 2001/3266, art. 2, Sch.",
          "UK_ukpga_2000_27"
        )
      )

    assert %Pointer{affecting_law: "UK_ukpga_2000_27", note_code: "F1"} = p
    assert p.provisions == [{:section, "60", ["5", "7"]}]

    assert p.commencing == [
             {"UK_uksi_2001_3266", [{:article, "2", []}, {:schedule, nil, nil, nil, []}]}
           ]
  end

  test "a Schedule paragraph with its Part, and several provisions" do
    p =
      Pointer.parse(
        note(
          "Words in s. 40(2) substituted (1.10.2001) by 2000 c. 27, s. 108, Sch. 6 Pt. II para. 33(c); S.I. 2001/3266",
          "UK_ukpga_2000_27"
        )
      )

    assert p.provisions == [{:section, "108", []}, {:schedule, "6", "II", "33", ["c"]}]
    assert p.commencing == [{"UK_uksi_2001_3266", []}]
  end

  test "a long-form citation, ss. lists and a bare Sch. (a repeal table)" do
    p =
      Pointer.parse(
        note(
          "S. 36 repealed (15.7.1994) by Railways Act 1993 (c. 43, SIF 102), ss. 140(8), 152(3), Sch. 14",
          "UK_ukpga_1993_43"
        )
      )

    assert p.provisions == [
             {:section, "140", ["8"]},
             {:section, "152", ["3"]},
             {:schedule, "14", nil, nil, []}
           ]
  end

  test "an SI: regulations and articles" do
    p =
      Pointer.parse(
        note("Reg. 4 substituted (6.4.2010) by S.I. 2010/675, reg. 107(2)", "UK_uksi_2010_675")
      )

    assert p.provisions == [{:regulation, "107", ["2"]}]
  end

  test "no law named, or the law not found in the text: no provisions" do
    assert %Pointer{provisions: []} = Pointer.parse(note("S. 3 repealed", nil))

    assert %Pointer{provisions: []} =
             Pointer.parse(note("S. 3 repealed by 1999 c. 1, s. 2", "UK_ukpga_2000_27"))
  end
end
