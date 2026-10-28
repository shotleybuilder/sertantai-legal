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

  test "a pointer's provisions as refs, as the feed names them (change vocabulary CV-04)" do
    assert Pointer.to_ref({:section, "108", []}) == "s.108"
    assert Pointer.to_ref({:regulation, "6", ["4"]}) == "reg.6(4)"
    assert Pointer.to_ref({:article, "2", []}) == "art.2"
    assert Pointer.to_ref({:schedule, "2", nil, "10", ["2", "a"]}) == "sch.2.para.10(2)(a)"
    assert Pointer.to_ref({:schedule, "6", "II", "33", ["c"]}) == "sch.6.para.33(c)"
    assert Pointer.to_ref({:schedule, "17", "2", nil, []}) == "sch.17.pt.2"
    assert Pointer.to_ref({:schedule, "7", nil, nil, []}) == "sch.7"
    assert Pointer.to_ref({:schedule, nil, nil, nil, []}) == nil
  end

  test "a run of same-kind brackets is a list of items, not a path; stray words are no bracket" do
    p =
      Pointer.parse(%{
        text:
          "Words substituted by Environment Act 1995 (c. 25), s. 106, Sch. 16 para. 9(b)(c)(d)",
        citation_law: "UK_ukpga_1995_25"
      })

    refs = p.provisions |> Enum.flat_map(&Pointer.to_refs/1)
    assert "sch.16.para.9(b)" in refs and "sch.16.para.9(d)" in refs

    p =
      Pointer.parse(%{
        text:
          "S. 336(10) inserted by Planning and Compensation Act 1991 (c. 34, SIF 123:1), s. 32, Sch. 7 para. 52(4)(with s. 84(5))",
        citation_law: "UK_ukpga_1991_34"
      })

    assert "sch.7.para.52(4)" in Enum.flat_map(p.provisions, &Pointer.to_refs/1)

    # a path stays a path: (4)(a) is sub-paragraph (4), item (a)
    assert Pointer.to_refs({:schedule, "22", nil, "4", ["4", "a"]}) == ["sch.22.para.4(4)(a)"]
  end

  test "the feed's amending provisions read as the notes' are (CV-07: one set of pointers)" do
    assert Pointer.refs_in("s. 29(4)") == [{:section, "29", ["4"]}]

    assert Pointer.refs_in("Sch. 7 para. 27(2) Sch. 17 Pt. 2") == [
             {:schedule, "7", nil, "27", ["2"]},
             {:schedule, "17", "2", nil, []}
           ]

    assert Pointer.refs_in("s. 111, Sch. 7") == [
             {:section, "111", []},
             {:schedule, "7", nil, nil, []}
           ]

    assert Pointer.refs_in("reg. 2(2)(a)") == [{:regulation, "2", ["2", "a"]}]
    assert Pointer.refs_in(nil) == []
  end

  describe "CV-S07 round 3: an unnumbered Schedule's paragraph, in braces" do
    test "\"{Sch. Pt. 1 para. 8(a)(i)}\" and \"Sch. para. 8(a)(ii)\" (HSWA s.28(3)(c)(ii) by SI 2004/1822)" do
      refs = fn t ->
        %{text: t, citation_law: "UK_uksi_2004_1822"}
        |> Pointer.parse()
        |> Map.get(:provisions)
        |> Enum.flat_map(&Pointer.to_refs/1)
      end

      assert refs.(
               "Words substituted (14.7.2004) by The X Order 2004 (S.I. 2004/1822), art. 2, {Sch. Pt. 1 para. 8(a)(i)}"
             ) ==
               ["art.2", "sch.para.8(a)(i)"]

      assert refs.(
               "Words substituted (14.7.2004) by The X Order 2004 (S.I. 2004/1822), art. 2, Sch. para. 8(a)(ii)"
             ) ==
               ["art.2", "sch.para.8(a)(ii)"]
    end
  end
end
