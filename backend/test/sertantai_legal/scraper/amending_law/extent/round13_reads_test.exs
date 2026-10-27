defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Round13ReadsTest do
  @moduledoc """
  The extent reader's misreads found by the CV-S05d whole-reader census
  (run-03, `backend/data/experiments/cv-s05d-whole-reader-census/run-03/out/triage.md`),
  one or more per wording S1–S17, each on its law's real words (CV-S05
  round 13).
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  defp read(law, body), do: Extent.read(ExtentDoc.doc(law, body))
  defp p1(id, text), do: ExtentDoc.p1(id, text)
  defp words(ns, kind \\ "section"), do: Enum.map_join(ns, &p1("#{kind}-#{&1}", "Words."))

  defp rows(e, kind), do: for({^kind, place, refs} <- e.lists ++ e.applies, do: {place, refs})

  describe "S2: sub-letter runs" do
    test "\"Subsection (2)(aa) applies only in relation to Wales\" (TCPA 1990 s.70)" do
      e =
        read(
          "UK_ukpga_1990_8",
          p1("section-70", "Subsection (2)(aa) applies only in relation to Wales.") <>
            p1(
              "section-71",
              "Subsections (1A), (2)(b) and (2ZZA) to (2ZZC) of section 70 do not apply in relation to Wales."
            )
        )

      assert {"W", ["s.70(2)(aa)"]} in rows(e, :applies)
    end

    test "\"Subsection (3)(a) above does not apply in Wales\" (ukpga 1980/66 s.264)" do
      e =
        read(
          "UK_ukpga_1980_66",
          p1("section-264", "Subsection (3)(a) above does not apply in Wales.")
        )

      assert {"W", ["s.264(3)(a)"]} in rows(e, :applies_not)
    end

    test "\"Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f) … shall extend to Northern Ireland\" (SI 2013/1506 reg.3(2))" do
      e =
        read(
          "UK_uksi_2013_1506",
          words([1, 2, 7, 33, 34], "regulation") <>
            p1(
              "regulation-3",
              "These Regulations shall not extend to Northern Ireland except as provided by paragraphs (2) and (3). Regulations 1, 2(1), (4) and (5), 7, 33(2) and 34 (f) of these Regulations shall extend to Northern Ireland."
            )
        )

      refs = e.lists |> Enum.filter(&match?({_, "NI", _}, &1)) |> Enum.flat_map(&elem(&1, 2))
      assert "reg.34(f)" in refs
      refute "reg.34" in refs
      assert "reg.2(4)" in refs
    end

    test "\"Article 2(1)(a) and (b) of this Order extends to England and Wales\" (SI 2005/457 art.1)" do
      e =
        read(
          "UK_uksi_2005_457",
          words([2], "article") <>
            p1("article-1", "Article 2(1)(a) and (b) of this Order extends to England and Wales.")
        )

      refs = e.lists |> Enum.flat_map(&elem(&1, 2))
      assert "reg.2(1)(b)" in refs
      refute "reg.2(b)" in refs
    end
  end

  describe "S11: a locator" do
    test "\"in regulation 16, paragraphs (4) and (5)\" is those paragraphs (SI 2020/818 reg.1A)" do
      e =
        read(
          "UK_uksi_2020_818",
          words([16, 17, 18], "regulation") <>
            p1(
              "regulation-1A",
              "The following provisions of these Regulations do not apply in England and Wales or Scotland—a in regulation 16, paragraphs (4) and (5);b regulation 17;c in regulation 18, paragraphs (8)(b) and (9)."
            )
        )

      assert [{"E+W+S", refs}] = rows(e, :applies_not)
      assert Enum.sort(refs) == ~w[reg.16(4) reg.16(5) reg.17 reg.18(8)(b) reg.18(9)]
    end
  end
end
