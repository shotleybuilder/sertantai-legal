defmodule SertantaiLegal.Scraper.Amendment.Reader.EuCitationTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Amendment.Reader
  alias SertantaiLegal.Scraper.Amendment.Reader.{EuCitation, LawNamed}

  defp refs(t), do: for(m <- Regex.scan(EuCitation.pattern(), t), r = EuCitation.ref(m), do: r)

  test "number/year, year/number, two-digit years" do
    assert refs("Regulation (EU) No 649/2012 is amended as follows.") ==
             [%{law: nil, eu: {"eur", "2012", "649"}}]

    assert refs("In Regulation (EU) 2016/425, for Article 3 substitute") ==
             [%{law: nil, eu: {"eur", "2016", "425"}}]

    assert refs("Council Directive 89/391/EEC and Decision 2000/532/EC") == [
             %{law: nil, eu: {"eudr", "1989", "391"}},
             %{law: nil, eu: {"eudn", "2000", "532"}}
           ]
  end

  test "only where it is what's amended: never a passing mention (SI 1996/1974, SI 2020/1369)" do
    assert EuCitation.naming?("Regulation (EU) No 649/2012 is amended as follows.")

    assert EuCitation.naming?(
             "In Commission Implementing Regulation (EU) 2016/799, in Article 2—"
           )

    assert EuCitation.naming?("Amendment of Regulation (EU) 2016/425")

    refute EuCitation.naming?(
             "as are necessary for the purpose of complying with Council Directive 91/439/ EEC and for ancillary purposes,"
           )

    refute EuCitation.naming?("Directive 2003/87/EC")
    refute EuCitation.naming?("References to Regulation (EU) No 649/2012")
    assert EuCitation.scan("Directive 2003/87/EC") == []
  end

  test "an EU citation is the nearest text naming a law: never an earlier Part's UK law (SI 2019/720 Sch. 2 para 168)" do
    pic = Reader.law_ref("UK_eur_2012_649", "Regulation (EU) No 649/2012", "art")

    coshh =
      Reader.law_ref(
        "UK_uksi_2002_2677",
        "Control of Substances Hazardous to Health Regulations",
        "reg"
      )

    named =
      LawNamed.named(
        [
          "After Article 23, insert—",
          "Regulation (EU) No 649/2012 is amended as follows.",
          "The Control of Substances Hazardous to Health Regulations 2002 are amended as follows."
        ],
        %{}
      )

    assert Enum.any?(named, &LawNamed.law_named?(&1, pic))
    refute Enum.any?(named, &LawNamed.law_named?(&1, coshh))
  end
end
