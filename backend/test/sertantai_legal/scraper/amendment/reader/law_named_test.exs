defmodule SertantaiLegal.Scraper.Amendment.Reader.LawNamedTest do
  @moduledoc "The reader's law-naming helpers (decomposed from Amendment.Reader, run time 2026-10-25)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed

  @rta Reader.law_ref("UK_ukpga_1988_52", "Road Traffic Act", "s")
  @ppva Reader.law_ref("UK_ukpga_1981_14", "Public Passenger Vehicles Act", "s")
  @hswa Reader.law_ref("UK_ukpga_1974_37", "Health and Safety at Work etc. Act", "s")

  test "named/2: the laws the nearest text naming any law names (titles, chapters, defined terms)" do
    # a title is captured from its first capital; law_named?/2 compares its end
    assert [%{title: t} = ref] =
             LawNamed.named(
               ["omit “x”", "In section 2 of the Health and Safety at Work etc. Act 1974"],
               %{}
             )

    assert String.ends_with?(t, "Health and Safety at Work etc. Act 1974")
    assert LawNamed.law_named?(ref, @hswa)

    assert [%{chapter: {"1988", "52"}}] = LawNamed.named(["In the Act of 1988 c. 52"], %{})

    terms = %{"the 1988 act" => %{law: "UK_ukpga_1988_52", title: nil}}
    assert [%{law: "UK_ukpga_1988_52"}] = LawNamed.named(["In section 4 of the 1988 Act"], terms)
    assert LawNamed.named(["nothing named"], %{}) == []
  end

  test "law_named?/2: by name, chapter or title and year" do
    assert LawNamed.law_named?(%{title: "Health and Safety at Work etc. Act 1974"}, @hswa)
    assert LawNamed.law_named?(%{chapter: {"1988", "52"}}, @rta)
    assert LawNamed.law_named?(%{law: "UK_ukpga_1988_52"}, @rta)
    refute LawNamed.law_named?(%{title: "Road Traffic Act 1991"}, @rta)
  end

  test "norm/1" do
    assert LawNamed.norm("The Health and Safety at Work etc. Act 1974") ==
             "health and safety at work etc act 1974"
  end

  test "law_spans/2: a name inside another is part of it (\"land\" in \"Land Compensation Act 1973\")" do
    terms = %{"land" => %{law: "UK_x", title: nil}}

    assert [{_, _, %{title: t}}] = LawNamed.law_spans("In the Land Compensation Act 1973", terms)
    assert String.ends_with?(t, "Land Compensation Act 1973")
  end

  test "own_part/3: a clause naming two laws, each law's part" do
    t =
      "Section 7 of the Public Passenger Vehicles Act 1981 and section 68(1) and (2) of the Road Traffic Act 1988 shall cease to have effect"

    assert LawNamed.own_part(t, @ppva, %{}) =~ "Section 7"
    refute LawNamed.own_part(t, @ppva, %{}) =~ "68(1)"
    assert LawNamed.own_part(t, @rta, %{}) =~ "68(1)"
    assert LawNamed.own_part("omit subsection (2)", @rta, %{}) == "omit subsection (2)"
  end

  test "scoped/4: each clause with its brackets and numbers, a clause naming another law dropped" do
    c1 = %Text{id: "x", instruction: "In section 7(1), paragraph (b) is omitted"}
    c2 = %Text{id: "x", instruction: "and in paragraph (c), omit “y”"}

    assert [a, b] = LawNamed.scoped([c1, c2], [c1.instruction], @rta, %{})
    assert a.numbers == ["7"] and b.numbers == ["7"]
    assert "1" in b.named and "c" in b.named
  end
end
